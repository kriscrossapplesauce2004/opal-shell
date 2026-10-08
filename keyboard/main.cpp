#include "ClipboardBridge.h"
#include "Gamepad.h"
#include "InputMethod.h"
#include "PhysicalKeyboard.h"
#include "PreferenceStore.h"
#include "SuggestionEngine.h"
#include <LayerShellQt/Window>
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusError>
#include <QFile>
#include <QRegion>
#include <QGuiApplication>
#include <QInputMethodEvent>
#include <QJsonDocument>
#include <QKeyEvent>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QScreen>
#include <QStandardPaths>
#include <QTimer>

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("borealis-keyboard");
    app.setApplicationDisplayName("Borealis Keyboard");
    app.setApplicationVersion("0.2.0");
    app.setQuitOnLastWindowClosed(false);
    QCommandLineParser parser;
    parser.setApplicationDescription("Borealis system keyboard. Wayland input method and convergent touch keyboard.");
    parser.addHelpOption(); parser.addVersionOption();
    parser.addOption({"preview", "Open an isolated typing playground; do not connect an input method."});
    parser.addOption({"show", "Show immediately for the currently focused application."});
    parser.addOption({"light", "Use light appearance."});
    parser.addOption({"width", "Preview width in logical pixels.", "pixels", "980"});
    parser.addOption({"height", "Preview height in logical pixels.", "pixels", "780"});
    parser.addOption({"handheld", "Preview in handheld controller mode."});
    parser.addOption({"layout", "Initial preview layout or panel: letters, numbers, symbols, emoji, edit, menu, clipboard, trackpad.", "layout", "letters"});
    parser.addOption({"docked", "Preview the slim docked bar that a physical keyboard brings."});
    parser.addOption({"floating", "Preview the floating card (needs a width of 720 or more)."});
    parser.addOption({"clipboard-fixture", "Preview clipboard history from a JSON file instead of the running shell.", "file"});
    parser.addOption({"purpose", "Preview content purpose: text, digits, number, phone, url, email, password, date, time, datetime, terminal.", "purpose", "text"});
    parser.addOption({"placement", "Preview placement: full, left, right, split.", "placement", "full"});
    parser.addOption({"screenshot", "Save a preview image and exit (requires --preview).", "path"});
    parser.addOption({"output", "Place the keyboard on the named Wayland output.", "name"});
    parser.addOption({"manual", "Show only on an explicit request, never on text focus alone (desktop use)."});
    parser.process(app);
    const bool preview = parser.isSet("preview");
    if (!preview && app.platformName() != "wayland") { qCritical("A Wayland session is required; use --preview for isolated UI testing."); return 1; }
    if (parser.isSet("screenshot") && !preview) { qCritical("--screenshot requires --preview"); return 1; }
    InputMethod input;
    Gamepad gamepad;
    PreferenceStore preferences;
    SuggestionEngine suggestions;
    ClipboardBridge clipboard;
    PhysicalKeyboard physical;
    if (parser.isSet("clipboard-fixture")) {
        QFile fixture(parser.value("clipboard-fixture"));
        if (fixture.open(QIODevice::ReadOnly)) clipboard.setFixture(fixture.read(2 * 1024 * 1024));
    }
    auto bus = QDBusConnection::sessionBus();
    if (preview) input.preview();
    if (parser.isSet("manual")) input.setAutoShow(false);
    else {
        if (!bus.registerService("sm.puri.OSK0")) { qCritical("An OSK already owns sm.puri.OSK0, or the session bus is unavailable."); return 1; }
        if (!input.connectDisplay()) { qCritical().noquote() << input.status(); return 1; }
        if (!bus.registerObject("/sm/puri/OSK0", &input, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllProperties)) { qCritical("Cannot register the keyboard visibility interface."); return 1; }
    }
    if (parser.isSet("light")) preferences.setLightOverride(true);
    QObject::connect(&input, &InputMethod::contextChanged, &suggestions, [&] {
        suggestions.updateContext(input.surroundingText(), input.cursorByte(), input.sensitive(), input.purpose());
    });
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("inputMethod", &input);
    engine.rootContext()->setContextProperty("gamepad", &gamepad);
    engine.rootContext()->setContextProperty("preferenceStore", &preferences);
    engine.rootContext()->setContextProperty("suggestionEngine", &suggestions);
    engine.rootContext()->setContextProperty("clipboardBridge", &clipboard);
    engine.rootContext()->setContextProperty("physicalKeyboardDetector", &physical);
    engine.rootContext()->setContextProperty("previewDocked", parser.isSet("docked"));
    engine.rootContext()->setContextProperty("previewFloating", parser.isSet("floating"));
    engine.rootContext()->setContextProperty("previewTerminal", false);
    engine.rootContext()->setContextProperty("previewMode", preview);
    engine.rootContext()->setContextProperty("previewWidth", qBound(320, parser.value("width").toInt(), 1920));
    engine.rootContext()->setContextProperty("previewHeight", qBound(320, parser.value("height").toInt(), 2160));
    engine.rootContext()->setContextProperty("previewHandheld", parser.isSet("handheld"));
    const QHash<QString, int> purposes{{"text",0},{"digits",2},{"number",3},{"phone",4},{"url",5},{"email",6},{"password",8},{"date",9},{"time",10},{"datetime",11},{"terminal",12}};
    const QHash<QString, int> placements{{"full",0},{"left",1},{"right",2},{"split",3}};
    engine.rootContext()->setContextProperty("previewPurpose", purposes.value(parser.value("purpose").toLower(), 0));
    engine.rootContext()->setContextProperty("previewPlacement", placements.value(parser.value("placement").toLower(), 0));
    engine.rootContext()->setContextProperty("initialLayout", parser.value("layout"));
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty()) return 1;
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!window) return 1;
    if (!preview) {
        auto *layer = LayerShellQt::Window::get(window);
        layer->setScope("opal-keyboard");
        layer->setLayer(LayerShellQt::Window::LayerOverlay);
        layer->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorBottom) | LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight);
        layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        layer->setActivateOnShow(false);
        if (parser.isSet("output")) {
            QScreen *selected = nullptr;
            for (auto *screen : app.screens()) if (screen->name() == parser.value("output")) selected = screen;
            if (!selected) { qCritical("Requested output is unavailable."); return 1; }
            layer->setScreen(selected);
        }
        // A floating card reserves no space. Docked or floating, only the visible card takes input.
        auto reserve = [layer, window] {
            const bool sparse = window->property("sparse").toBool();
            layer->setExclusiveZone(window->isVisible() && window->property("reserveSpace").toBool() ? window->height() : 0);
            window->setMask(sparse ? QRegion(window->property("inputRect").toRectF().toAlignedRect()) : QRegion());
        };
        QObject::connect(window, &QWindow::heightChanged, &app, reserve);
        QObject::connect(window, &QWindow::visibleChanged, &app, reserve);
        // QML property changes are polled because this file has no signal receiver class.
        auto *shape = new QTimer(window);
        shape->setInterval(120);
        QObject::connect(shape, &QTimer::timeout, window, reserve);
        shape->start();
        reserve();
        QObject::connect(&input, &InputMethod::changed, window, [&input, window] { window->setVisible(input.visible()); });
        if (parser.isSet("show")) input.SetVisible(true);
    } else {
        auto modifiers = [](bool control, bool alt, bool shift) {
            Qt::KeyboardModifiers mods;
            if (control) mods |= Qt::ControlModifier;
            if (alt) mods |= Qt::AltModifier;
            if (shift) mods |= Qt::ShiftModifier;
            return mods;
        };
        QObject::connect(&input, &InputMethod::previewText, window, [window, modifiers](const QString &text, bool control, bool alt) {
            auto *target = window->focusObject();
            if (!target) return;
            if (!control && !alt) { QInputMethodEvent event; event.setCommitString(text); QCoreApplication::sendEvent(target, &event); }
            else {
                const int key = text.size() == 1 ? text.at(0).toUpper().unicode() : Qt::Key_unknown;
                QKeyEvent press(QEvent::KeyPress, key, modifiers(control, alt, false), text);
                QKeyEvent release(QEvent::KeyRelease, key, modifiers(control, alt, false), text);
                QCoreApplication::sendEvent(target, &press); QCoreApplication::sendEvent(target, &release);
            }
        });
        QObject::connect(&input, &InputMethod::previewKey, window, [window, modifiers](const QString &name, bool control, bool alt, bool shift) {
            static const QHash<QString, int> keys{{"Backspace", Qt::Key_Backspace}, {"Delete", Qt::Key_Delete}, {"Return", Qt::Key_Return}, {"Tab", Qt::Key_Tab}, {"Escape", Qt::Key_Escape}, {"Left", Qt::Key_Left}, {"Right", Qt::Key_Right}, {"Up", Qt::Key_Up}, {"Down", Qt::Key_Down}, {"Home", Qt::Key_Home}, {"End", Qt::Key_End}, {"PageUp", Qt::Key_PageUp}, {"PageDown", Qt::Key_PageDown}};
            if (!window->focusObject()) return;
            QKeyEvent press(QEvent::KeyPress, keys.value(name), modifiers(control, alt, shift));
            QKeyEvent release(QEvent::KeyRelease, keys.value(name), modifiers(control, alt, shift));
            QCoreApplication::sendEvent(window->focusObject(), &press); QCoreApplication::sendEvent(window->focusObject(), &release);
        });
        QObject::connect(window, &QWindow::visibleChanged, &app, [window, &app] { if (!window->isVisible()) app.quit(); });
        window->show();
        if (parser.isSet("screenshot")) QTimer::singleShot(700, window, [window, &app, &parser] { app.exit(window->grabWindow().save(parser.value("screenshot")) ? 0 : 1); });
    }
    return app.exec();
}
