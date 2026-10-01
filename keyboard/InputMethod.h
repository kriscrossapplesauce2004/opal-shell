#pragma once
#include "Keymap.h"
#include <QObject>
#include <QElapsedTimer>
#include <QSocketNotifier>
#include <wayland-client.h>
#include "input-method-unstable-v2.h"
#include "virtual-keyboard-unstable-v1.h"

class InputMethod : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "sm.puri.OSK0")
    Q_PROPERTY(bool Visible READ visible NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(bool sensitive READ sensitive NOTIFY changed)
    Q_PROPERTY(int purpose READ purpose NOTIFY changed)
    Q_PROPERTY(int contentHints READ contentHints NOTIFY contextChanged)
    Q_PROPERTY(int changeCause READ changeCause NOTIFY contextChanged)
    Q_PROPERTY(QString surroundingText READ surroundingText NOTIFY contextChanged)
    Q_PROPERTY(int cursorByte READ cursorByte NOTIFY contextChanged)
    Q_PROPERTY(int anchorByte READ anchorByte NOTIFY contextChanged)
    Q_PROPERTY(bool selectionActive READ selectionActive NOTIFY contextChanged)
    Q_PROPERTY(bool multiline READ multiline NOTIFY contextChanged)
    Q_PROPERTY(bool terminal READ terminal NOTIFY contextChanged)
    Q_PROPERTY(int generation READ generation NOTIFY contextChanged)
    Q_PROPERTY(QString status READ status NOTIFY changed)
public:
    explicit InputMethod(QObject *parent = nullptr);
    ~InputMethod() override;
    bool connectDisplay();
    bool visible() const { return shown; }
    bool active() const { return currentActive; }
    bool sensitive() const { return !currentActive || currentPurpose == 8 || (currentHints & 0xc0); }
    int purpose() const { return int(currentPurpose); }
    int contentHints() const { return int(currentHints); }
    int changeCause() const { return int(currentCause); }
    QString surroundingText() const { return currentSurrounding; }
    int cursorByte() const { return int(currentCursor); }
    int anchorByte() const { return int(currentAnchor); }
    bool selectionActive() const { return currentCursor != currentAnchor; }
    bool multiline() const { return currentHints & 0x200; }
    bool terminal() const { return currentPurpose == 12; }
    int generation() const { return epoch; }
    QString status() const;
    Q_INVOKABLE void text(const QString &text, int generation, bool control = false, bool alt = false);
    Q_INVOKABLE void key(const QString &name, int generation, bool control = false, bool alt = false, bool shift = false);
    Q_INVOKABLE void backspace(int generation);
    Q_INVOKABLE void replaceCurrentWord(const QString &text, int generation, int prefixBytes);
    Q_INVOKABLE void preedit(const QString &text, int generation);
    Q_INVOKABLE void hide() { SetVisible(false); }
    // Manual mode: focus alone never shows the keyboard; only SetVisible(true) does.
    void setAutoShow(bool value) { autoShow = value; }
    void preview();
public slots:
    void SetVisible(bool visible);
signals:
    void changed();
    void contextChanged();
    void previewText(const QString &text, bool control, bool alt);
    void previewKey(const QString &name, bool control, bool alt, bool shift);
private:
    void publish();
    void flush();
    void fail(const QString &reason);
    bool sendMap();
    void stroke(uint32_t code, uint32_t modifiers);
    static void global(void *, wl_registry *, uint32_t, const char *, uint32_t);
    static void removed(void *, wl_registry *, uint32_t);
    static void activate(void *, zwp_input_method_v2 *);
    static void deactivate(void *, zwp_input_method_v2 *);
    static void surrounding(void *, zwp_input_method_v2 *, const char *, uint32_t, uint32_t);
    static void cause(void *, zwp_input_method_v2 *, uint32_t);
    static void content(void *, zwp_input_method_v2 *, uint32_t, uint32_t);
    static void done(void *, zwp_input_method_v2 *);
    static void unavailable(void *, zwp_input_method_v2 *);
    wl_display *display = nullptr;
    wl_registry *registry = nullptr;
    wl_seat *seat = nullptr;
    uint32_t seatName = 0;
    zwp_input_method_manager_v2 *manager = nullptr;
    zwp_virtual_keyboard_manager_v1 *keyboardManager = nullptr;
    zwp_input_method_v2 *method = nullptr;
    zwp_virtual_keyboard_v1 *keyboard = nullptr;
    QSocketNotifier *reader = nullptr;
    QSocketNotifier *writer = nullptr;
    Keymap keymap;
    QElapsedTimer clock;
    uint32_t serial = 0, currentPurpose = 0, pendingPurpose = 0, currentHints = 0, pendingHints = 0, currentCause = 0, pendingCause = 0;
    uint32_t currentCursor = 0, currentAnchor = 0, pendingCursor = 0, pendingAnchor = 0;
    QString currentSurrounding, pendingSurrounding;
    bool currentSurroundingSupported = false, pendingSurroundingSupported = false;
    bool currentActive = false, pendingActive = false, contextPending = false;
    bool shown = false, manual = false, dismissed = false, demo = false, broken = false, autoShow = true;
    int epoch = 0;
    QString error;
};
