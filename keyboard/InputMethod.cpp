#include "InputMethod.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QFile>
#include <QHash>
#include <QTemporaryFile>
#include <QVariantMap>
#include <QTextBoundaryFinder>
#include <cstring>
#include <cerrno>
#include <linux/input-event-codes.h>

InputMethod::InputMethod(QObject *parent) : QObject(parent) { clock.start(); }
InputMethod::~InputMethod() {
    delete reader; delete writer;
    if (keyboard) zwp_virtual_keyboard_v1_destroy(keyboard);
    if (method) zwp_input_method_v2_destroy(method);
    if (keyboardManager) zwp_virtual_keyboard_manager_v1_destroy(keyboardManager);
    if (manager) zwp_input_method_manager_v2_destroy(manager);
    if (seat) wl_seat_destroy(seat);
    if (registry) wl_registry_destroy(registry);
    if (display) { wl_display_flush(display); wl_display_disconnect(display); }
}
bool InputMethod::connectDisplay() {
    display = wl_display_connect(nullptr);
    if (!display) { fail("Cannot connect to the Wayland display"); return false; }
    registry = wl_display_get_registry(display);
    static const wl_registry_listener listener{global, removed};
    wl_registry_add_listener(registry, &listener, this);
    if (wl_display_roundtrip(display) < 0) { fail("Wayland registry failed"); return false; }
    if (!seat || !manager || !keyboardManager) { fail("Compositor needs input-method-v2 and virtual-keyboard-v1"); return false; }
    method = zwp_input_method_manager_v2_get_input_method(manager, seat);
    static const zwp_input_method_v2_listener events{activate, deactivate, surrounding, cause, content, done, unavailable};
    zwp_input_method_v2_add_listener(method, &events, this);
    keyboard = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(keyboardManager, seat);
    if (!sendMap()) return false;
    if (wl_display_roundtrip(display) < 0) { fail("Wayland input setup failed"); return false; }
    if (broken) return false;
    reader = new QSocketNotifier(wl_display_get_fd(display), QSocketNotifier::Read, this);
    writer = new QSocketNotifier(wl_display_get_fd(display), QSocketNotifier::Write, this);
    writer->setEnabled(false);
    connect(reader, &QSocketNotifier::activated, this, [this] {
        if (wl_display_dispatch(display) < 0) fail("Wayland connection was lost");
        else flush();
    });
    connect(writer, &QSocketNotifier::activated, this, [this] { flush(); });
    publish(); return true;
}
void InputMethod::global(void *data, wl_registry *registry, uint32_t id, const char *name, uint32_t) {
    auto *self = static_cast<InputMethod *>(data);
    if (!strcmp(name, "wl_seat") && !self->seat) { self->seat = static_cast<wl_seat *>(wl_registry_bind(registry, id, &wl_seat_interface, 1)); self->seatName = id; }
    else if (!strcmp(name, "zwp_input_method_manager_v2")) self->manager = static_cast<zwp_input_method_manager_v2 *>(wl_registry_bind(registry, id, &zwp_input_method_manager_v2_interface, 1));
    else if (!strcmp(name, "zwp_virtual_keyboard_manager_v1")) self->keyboardManager = static_cast<zwp_virtual_keyboard_manager_v1 *>(wl_registry_bind(registry, id, &zwp_virtual_keyboard_manager_v1_interface, 1));
}
void InputMethod::removed(void *data, wl_registry *, uint32_t id) {
    auto *self = static_cast<InputMethod *>(data);
    if (id == self->seatName) self->fail("Input seat was removed; restart the keyboard");
}
void InputMethod::activate(void *data, zwp_input_method_v2 *) {
    auto *s = static_cast<InputMethod *>(data);
    s->pendingActive = true; s->pendingPurpose = 0; s->pendingHints = 0; s->pendingCause = 0;
    s->pendingSurrounding.clear(); s->pendingCursor = 0; s->pendingAnchor = 0; s->pendingSurroundingSupported = false; s->contextPending = true;
}
void InputMethod::deactivate(void *data, zwp_input_method_v2 *) {
    auto *s = static_cast<InputMethod *>(data);
    s->pendingActive = false; s->pendingPurpose = 0; s->pendingHints = 0; s->contextPending = true;
}
void InputMethod::surrounding(void *data, zwp_input_method_v2 *, const char *text, uint32_t cursor, uint32_t anchor) {
    auto *s = static_cast<InputMethod *>(data);
    s->pendingSurrounding = QString::fromUtf8(text); s->pendingCursor = cursor; s->pendingAnchor = anchor; s->pendingSurroundingSupported = true;
}
void InputMethod::cause(void *data, zwp_input_method_v2 *, uint32_t cause) { static_cast<InputMethod *>(data)->pendingCause = cause; }
void InputMethod::content(void *data, zwp_input_method_v2 *, uint32_t hints, uint32_t purpose) {
    auto *s = static_cast<InputMethod *>(data); s->pendingHints = hints; s->pendingPurpose = purpose;
}
void InputMethod::done(void *data, zwp_input_method_v2 *) {
    auto *s = static_cast<InputMethod *>(data);
    ++s->serial;
    s->currentActive = s->pendingActive; s->currentPurpose = s->pendingPurpose; s->currentHints = s->pendingHints; s->currentCause = s->pendingCause;
    s->currentSurrounding = s->pendingSurrounding; s->currentCursor = s->pendingCursor; s->currentAnchor = s->pendingAnchor; s->currentSurroundingSupported = s->pendingSurroundingSupported;
    if (s->contextPending) {
        ++s->epoch; s->dismissed = false; s->manual = false;
        s->contextPending = false; emit s->contextChanged();
    }
    s->shown = !s->broken && (s->manual || (s->autoShow && s->currentActive && !s->dismissed)); s->publish();
}
void InputMethod::unavailable(void *data, zwp_input_method_v2 *) {
    static_cast<InputMethod *>(data)->fail("Another input method owns the seat, or the seat is unavailable");
}
QString InputMethod::status() const {
    if (!error.isEmpty()) return error;
    if (demo) return "Preview";
    return currentActive ? (sensitive() ? "Private input" : "Text input") : "App keyboard";
}
void InputMethod::preview() { demo = true; shown = true; publish(); }
void InputMethod::SetVisible(bool value) {
    if (broken || (!keyboard && !demo)) return;
    manual = value; dismissed = !value; shown = value;
    ++epoch; emit contextChanged(); publish();
}
void InputMethod::publish() {
    emit changed();
    if (demo) return;
    auto message = QDBusMessage::createSignal("/sm/puri/OSK0", "org.freedesktop.DBus.Properties", "PropertiesChanged");
    message << QString("sm.puri.OSK0") << QVariantMap{{"Visible", shown}} << QStringList{};
    QDBusConnection::sessionBus().send(message);
}
void InputMethod::fail(const QString &reason) {
    error = reason; broken = true; shown = false; currentActive = false;
    if (reader) reader->setEnabled(false);
    if (writer) writer->setEnabled(false);
    ++epoch; emit contextChanged(); publish();
}
void InputMethod::flush() {
    if (!display || broken) return;
    const int result = wl_display_flush(display);
    if (writer) writer->setEnabled(result < 0 && errno == EAGAIN);
    if (result < 0 && errno != EAGAIN) fail("Wayland write failed");
}
bool InputMethod::sendMap() {
    const auto bytes = keymap.bytes();
    QTemporaryFile file;
    if (bytes.isEmpty() || !file.open() || file.write(bytes) != bytes.size() || !file.flush()) { fail("Could not prepare keyboard mapping"); return false; }
    zwp_virtual_keyboard_v1_keymap(keyboard, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, file.handle(), uint32_t(bytes.size()));
    return true;
}
void InputMethod::stroke(uint32_t code, uint32_t modifiers) {
    if (!keyboard || broken) return;
    const auto time = uint32_t(clock.elapsed());
    zwp_virtual_keyboard_v1_modifiers(keyboard, modifiers, 0, 0, 0);
    zwp_virtual_keyboard_v1_key(keyboard, time, code, WL_KEYBOARD_KEY_STATE_PRESSED);
    zwp_virtual_keyboard_v1_key(keyboard, time, code, WL_KEYBOARD_KEY_STATE_RELEASED);
    zwp_virtual_keyboard_v1_modifiers(keyboard, 0, 0, 0, 0);
}
void InputMethod::text(const QString &value, int generation, bool control, bool alt) {
    if (!shown || broken || generation != epoch || value.isEmpty() || value.toUtf8().size() > 4000 || value.contains(QChar(0))) return;
    if (demo) { emit previewText(value, control, alt); return; }
    if (currentActive && !control && !alt) {
        const auto bytes = value.toUtf8();
        zwp_input_method_v2_commit_string(method, bytes.constData());
        zwp_input_method_v2_commit(method, serial);
    } else {
        for (auto cp : value.toUcs4()) {
            auto event = keymap.character(cp);
            if (!event) {
                if (!keymap.reset(cp) || !sendMap()) return;
                event = keymap.character(cp);
            }
            if (!event) { fail("Character is not available in the keyboard mapping"); return; }
            stroke(event->code, event->modifiers | keymap.modifiers(control, alt, false));
        }
    }
    flush();
}
void InputMethod::backspace(int generation) {
    if (!shown || broken || generation != epoch) return;
    if (demo) { emit previewKey("Backspace", false, false, false); return; }
    if (currentActive && currentSurroundingSupported) {
        const auto bytes = currentSurrounding.toUtf8();
        const auto cursor = qMin<uint32_t>(currentCursor, bytes.size());
        const auto anchor = qMin<uint32_t>(currentAnchor, bytes.size());
        if (cursor != anchor) {
            zwp_input_method_v2_delete_surrounding_text(method, cursor - qMin(cursor, anchor), qMax(cursor, anchor) - cursor);
            zwp_input_method_v2_commit(method, serial); flush(); return;
        }
        if (cursor > 0) {
            const auto prefix = QString::fromUtf8(bytes.left(cursor));
            QTextBoundaryFinder finder(QTextBoundaryFinder::Grapheme, prefix);
            finder.toEnd();
            const int start = finder.toPreviousBoundary();
            if (start >= 0) {
                const auto count = prefix.mid(start).toUtf8().size();
                if (count > 0) {
                    zwp_input_method_v2_delete_surrounding_text(method, uint32_t(count), 0);
                    zwp_input_method_v2_commit(method, serial); flush(); return;
                }
            }
        }
    }
    stroke(KEY_BACKSPACE, 0); flush();
}
void InputMethod::replaceCurrentWord(const QString &value, int generation, int prefixBytes) {
    if (!shown || broken || generation != epoch || value.isEmpty() || value.toUtf8().size() > 4000) return;
    if (demo) {
        for (int i = 0; i < prefixBytes; ++i) emit previewKey("Backspace", false, false, false);
        emit previewText(value, false, false); return;
    }
    if (currentActive && prefixBytes >= 0 && currentSurroundingSupported) {
        zwp_input_method_v2_delete_surrounding_text(method, uint32_t(prefixBytes), 0);
        const auto bytes = value.toUtf8();
        zwp_input_method_v2_commit_string(method, bytes.constData());
        zwp_input_method_v2_commit(method, serial); flush(); return;
    }
    text(value, generation, false, false);
}
void InputMethod::preedit(const QString &value, int generation) {
    if (!shown || broken || generation != epoch || !currentActive || value.toUtf8().size() > 4000) return;
    const auto bytes = value.toUtf8();
    zwp_input_method_v2_set_preedit_string(method, bytes.constData(), bytes.size(), bytes.size());
    zwp_input_method_v2_commit(method, serial); flush();
}
void InputMethod::key(const QString &name, int generation, bool control, bool alt, bool shift) {
    if (!shown || broken || generation != epoch) return;
    static const QHash<QString, uint32_t> keys{{"Backspace", KEY_BACKSPACE}, {"Delete", KEY_DELETE}, {"Insert", KEY_INSERT}, {"Return", KEY_ENTER}, {"Tab", KEY_TAB}, {"Escape", KEY_ESC}, {"Left", KEY_LEFT}, {"Right", KEY_RIGHT}, {"Up", KEY_UP}, {"Down", KEY_DOWN}, {"Home", KEY_HOME}, {"End", KEY_END}, {"PageUp", KEY_PAGEUP}, {"PageDown", KEY_PAGEDOWN}};
    const auto i = keys.constFind(name);
    if (i == keys.cend()) return;
    if (demo) { emit previewKey(name, control, alt, shift); return; }
    stroke(i.value(), keymap.modifiers(control, alt, shift)); flush();
}
