#include "ClipboardBridge.h"
#include "Gamepad.h"
#include "InputMethod.h"
#include "PhysicalKeyboard.h"
#include "PreferenceStore.h"
#include "SuggestionEngine.h"
#include <QInputMethodEvent>
#include <QTemporaryFile>
#include <QJSValue>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtTest>

class KeyboardUiTest : public QObject {
    Q_OBJECT
    std::unique_ptr<InputMethod> input;
    std::unique_ptr<Gamepad> gamepad;
    std::unique_ptr<PreferenceStore> preferences;
    std::unique_ptr<SuggestionEngine> suggestions;
    std::unique_ptr<ClipboardBridge> clipboard;
    std::unique_ptr<PhysicalKeyboard> physical;
    std::unique_ptr<QQmlApplicationEngine> engine;
    QQuickWindow *window = nullptr;
    QQuickItem *deck = nullptr;
    QObject *editor = nullptr;
    QQuickItem *key(const QString &value) {
        QList<QQuickItem *> pending{window->contentItem()};
        while (!pending.isEmpty()) {
            auto *item = pending.takeLast();
            if (item->objectName() == "key-" + value && item->isVisible()) return item;
            pending.append(item->childItems());
        }
        return nullptr;
    }
    QQuickItem *item(const QString &name) {
        QList<QQuickItem *> pending{window->contentItem()};
        while (!pending.isEmpty()) {
            auto *candidate = pending.takeLast();
            if (candidate->objectName() == name && candidate->isVisible()) return candidate;
            pending.append(candidate->childItems());
        }
        return nullptr;
    }
    void openMenu() {
        tap("__tools");
        QTRY_VERIFY_WITH_TIMEOUT(deck->property("progressValue").toReal() > 0.99, 5000);
        QTRY_VERIFY(key("__tool-edit") && key("__tool-edit")->width() > 20);
    }
    void useTool(const QString &name) {
        openMenu(); tap("__tool-" + name);
        // A closing sheet still covers the keys, so wait until it has gone.
        if (deck->property("panel").toString() != "menu") QTRY_VERIFY_WITH_TIMEOUT(deck->property("progressValue").toReal() < 0.01, 5000);
    }
    void typeWord(const QString &word) { for (const auto &letter : word) tap(QString(letter)); }
    QPoint center(QQuickItem *item) { return item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint(); }
    void tap(const QString &value) {
        QTRY_VERIFY2_WITH_TIMEOUT(key(value) && key(value)->width() > 0, qPrintable(value), 1000);
        auto *item = key(value);
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, center(item));
        QCoreApplication::processEvents();
    }
private slots:
    void init() {
        input = std::make_unique<InputMethod>(); input->preview();
        gamepad = std::make_unique<Gamepad>();
        preferences = std::make_unique<PreferenceStore>();
        suggestions = std::make_unique<SuggestionEngine>();
        clipboard = std::make_unique<ClipboardBridge>();
        physical = std::make_unique<PhysicalKeyboard>(nullptr, "/nonexistent/devices");
        engine = std::make_unique<QQmlApplicationEngine>();
        engine->rootContext()->setContextProperty("inputMethod", input.get());
        engine->rootContext()->setContextProperty("gamepad", gamepad.get());
        engine->rootContext()->setContextProperty("preferenceStore", preferences.get());
        engine->rootContext()->setContextProperty("suggestionEngine", suggestions.get());
        engine->rootContext()->setContextProperty("clipboardBridge", clipboard.get());
        engine->rootContext()->setContextProperty("physicalKeyboardDetector", physical.get());
        engine->rootContext()->setContextProperty("previewDocked", false);
        engine->rootContext()->setContextProperty("previewFloating", false);
        engine->rootContext()->setContextProperty("previewTerminal", false);
        engine->rootContext()->setContextProperty("previewMode", true);
        engine->rootContext()->setContextProperty("previewWidth", 390);
        engine->rootContext()->setContextProperty("previewHeight", 780);
        engine->rootContext()->setContextProperty("initialLayout", "letters");
        engine->load(QUrl("qrc:/Main.qml"));
        QVERIFY(!engine->rootObjects().isEmpty());
        window = qobject_cast<QQuickWindow *>(engine->rootObjects().first()); QVERIFY(window);
        deck = window->findChild<QQuickItem *>("keyboard"); QVERIFY(deck);
        editor = window->findChild<QObject *>("previewEditor"); QVERIFY(editor);
        connect(input.get(), &InputMethod::previewText, this, [this](const QString &text, bool control, bool alt) {
            if (control || alt) return;
            QInputMethodEvent event; event.setCommitString(text); QCoreApplication::sendEvent(editor, &event);
        });
        connect(input.get(), &InputMethod::previewKey, this, [this](const QString &name, bool control, bool alt, bool shift) {
            const QHash<QString, int> keys{{"Backspace", Qt::Key_Backspace}, {"Left", Qt::Key_Left}, {"Right", Qt::Key_Right}, {"Return", Qt::Key_Return}};
            Qt::KeyboardModifiers mods;
            if (control) mods |= Qt::ControlModifier;
            if (alt) mods |= Qt::AltModifier;
            if (shift) mods |= Qt::ShiftModifier;
            QKeyEvent event(QEvent::KeyPress, keys.value(name, Qt::Key_unknown), mods); QCoreApplication::sendEvent(editor, &event);
        });
        window->show(); QVERIFY(QTest::qWaitForWindowExposed(window));
        QTRY_VERIFY_WITH_TIMEOUT(key("q") && key("q")->width() > 20, 1000);
    }
    void cleanup() { delete window; window = nullptr; engine.reset(); clipboard.reset(); physical.reset(); suggestions.reset(); preferences.reset(); input.reset(); gamepad.reset(); }
    void typingAndSelection() {
        tap("q"); tap("w"); QCOMPARE(editor->property("text").toString(), QString("qw"));
        editor->setProperty("text", "hello world");
        QVERIFY(QMetaObject::invokeMethod(editor, "select", Q_ARG(int, 0), Q_ARG(int, 5)));
        tap("a"); QCOMPARE(editor->property("text").toString(), QString("a world"));
        editor->setProperty("cursorPosition", 2);
        tap("z"); QCOMPARE(editor->property("text").toString(), QString("a zworld"));
        QVERIFY(editor->property("activeFocus").toBool());
    }
    void shiftCapsAndLayouts() {
        tap("Shift"); tap("a"); tap("b"); QCOMPARE(editor->property("text").toString(), QString("Ab"));
        tap("Shift"); tap("Shift"); tap("c"); tap("d"); QCOMPARE(editor->property("text").toString(), QString("AbCD"));
        tap("Shift"); tap("__layout"); QTRY_VERIFY(key("1") && key("1")->width() > 20); tap("1");
        tap("Symbols"); QTRY_VERIFY(key("€") && key("€")->width() > 20); tap("€");
        tap("__emoji"); QTRY_VERIFY(key("😀") && key("😀")->width() > 20); tap("😀");
        QCOMPARE(editor->property("text").toString(), QString::fromUtf8("AbCD1€😀"));
    }
    void repeatAndCancel() {
        editor->setProperty("text", "abcdefghijklmnopqrstuv"); editor->setProperty("cursorPosition", 22);
        auto *item = key("⌫"); QVERIFY(item);
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, center(item));
        QTest::qWait(530);
        QVERIFY(editor->property("text").toString().size() < 20);
        input->SetVisible(false);
        const auto stopped = editor->property("text").toString();
        QTest::qWait(150); QCOMPARE(editor->property("text").toString(), stopped);
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, center(item));
        QCOMPARE(editor->property("text").toString(), stopped);
    }
    void dragOutCancels() {
        auto *item = key("q"); QVERIFY(item);
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, center(item));
        const QPoint outside = item->mapToScene(QPointF(item->width() + 30, item->height() / 2)).toPoint();
        QTest::mouseMove(window, outside);
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, outside);
        QCOMPARE(editor->property("text").toString(), QString());
    }
    void longPressAccent() {
        auto *item = key("a"); QVERIFY(item);
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, center(item));
        QTest::qWait(470); QVERIFY(item->property("choosing").toBool());
        const auto x = item->property("popupX").toReal() + item->property("popupWidth").toReal() * 2.5 / 8;
        const QPoint position = item->mapToScene(QPointF(x, -20)).toPoint();
        QTest::mouseMove(window, position);
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, position);
        QCOMPARE(editor->property("text").toString(), QString::fromUtf8("á"));
    }
    void spaceScrub() {
        editor->setProperty("text", "abcdef"); editor->setProperty("cursorPosition", 3);
        auto *item = key(" "); QVERIFY(item);
        const auto start = center(item);
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, start);
        QTest::mouseMove(window, start + QPoint(30, 0));
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, start + QPoint(30, 0));
        QCOMPARE(editor->property("text").toString(), QString("abcdef"));
        QCOMPARE(editor->property("cursorPosition").toInt(), 5);
    }
    void numberRowAndEmojiCategories() {
        QTRY_VERIFY(key("1") && key("1")->width() > 20); tap("1"); tap("a");
        QCOMPARE(editor->property("text").toString(), QString("1a"));
        tap("__emoji"); QTRY_VERIFY(key("__category1") && key("__category1")->width() > 20); tap("__category2"); QTRY_VERIFY(key("👍") && key("👍")->width() > 20); tap("👍");
        QTRY_VERIFY(key("__category3") && key("__category3")->width() > 20); tap("__category3"); QTRY_VERIFY(key("🐈") && key("🐈")->width() > 20); tap("🐈");
        QCOMPARE(editor->property("text").toString(), QString::fromUtf8("1a👍🐈"));
    }
    void numberRowIsPermanent() {
        QTRY_VERIFY(key("1") && key("1")->width() > 20);
        window->resize(320, 520); QTest::qWait(80);
        QTRY_VERIFY(key("1") && key("1")->width() > 20);
        tap("1"); QCOMPARE(editor->property("text").toString(), QString("1"));
    }
    void suggestionsArePrivateAndContextual() {
        suggestions->updateEditorContext("tha", 3, false, 0);
        QVERIFY(!suggestions->suggestions().isEmpty());
        QVERIFY(suggestions->currentPrefixBytes() == 3);
        suggestions->updateEditorContext("secret", 6, true, 8);
        QVERIFY(suggestions->suggestions().isEmpty());
    }
    void persistentSelection() {
        editor->setProperty("text", "abcdef"); editor->setProperty("cursorPosition", 1);
        useTool("edit"); tap("__select"); tap("Right"); tap("Right");
        QCOMPARE(editor->property("selectedText").toString(), QString("bc"));
        tap("__keys"); QTRY_VERIFY(key("z") && key("z")->width() > 20); tap("z");
        QCOMPARE(editor->property("text").toString(), QString("azdef"));
        QVERIFY(!deck->property("selecting").toBool());
    }
    void privateHoldDoesNotReveal() {
        window->setProperty("privatePreview", true);
        auto *item = key("a"); QVERIFY(item);
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, center(item));
        QTest::qWait(470); QVERIFY(!item->property("choosing").toBool());
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, center(item));
        QCOMPARE(editor->property("text").toString(), QString("a"));
    }
    void adaptiveGeometry() {
        for (const auto size : {QSize(320, 780), QSize(390, 844), QSize(844, 390), QSize(1200, 900)}) {
            window->resize(size); QTest::qWait(60);
            const qreal limit = size.width() < 600 ? (size.width() > size.height() ? .78 : .68) : .62;
            QVERIFY(deck->height() <= window->height() * limit + 1);
            auto *q = key("q"); auto *space = key(" "); QVERIFY(q && space);
            QVERIFY(q->width() > 20); QVERIFY(q->height() >= 25);
            QVERIFY(space->mapToScene(QPointF(0, space->height())).y() <= window->height() + 1);
            tap("q");
        }
        QCOMPARE(editor->property("text").toString(), QString("qqqq"));
        window->resize(390, 844); QTest::qWait(60);
        const auto full = key("q")->width(); useTool("hand"); QTRY_VERIFY(key("q") && key("q")->width() > 20); QTest::qWait(60);
        QVERIFY(key("q")->width() < full);
    }
    void materialGeometryAndPalette() {
        window->resize(575, 962); QTest::qWait(80);
        QVERIFY(key("q")->height() >= 44);
        QVERIFY(key("1")->height() >= 28);
        QVERIFY(key("__hide")->width() >= 44);
        QVERIFY(key("__hide")->height() >= 40);
        for (const auto &role : {"primaryInk", "primaryContainerInk", "secondaryContainerInk", "tertiaryContainerInk"})
            QVERIFY2(deck->property(role).value<QColor>().isValid(), role);
        const auto lettersHeight = deck->height();
        tap("__layout"); QTest::qWait(80);
        QVERIFY(window->grabWindow().save("/tmp/borealis-material-symbols.png"));
        QCOMPARE(deck->height(), lettersHeight);
        tap("__layout"); QTest::qWait(80);
        QCOMPARE(deck->height(), lettersHeight);
        for (bool light : {false, true}) {
            deck->setProperty("preferences", QVariantMap{{"light", light}, {"palette", 1}});
            QTest::qWait(80);
            QVERIFY(window->grabWindow().save(light ? "/tmp/borealis-material-light.png" : "/tmp/borealis-material-dark.png"));
        }
    }
    void splitLayoutOnWideDisplays() {
        window->resize(1000, 700); QTest::qWait(80);
        for (int step = 0; step < 3; ++step) { useTool("hand"); QTRY_VERIFY_WITH_TIMEOUT(key("q") && key("q")->width() > 20, 3000); }
        QTest::qWait(80);
        QVERIFY(deck->property("splitLayout").toBool());
        auto *t = key("t"); auto *y = key("y"); QVERIFY(t && y);
        const auto gap = y->mapToScene(QPointF(0, 0)).x() - t->mapToScene(QPointF(t->width(), 0)).x();
        QVERIFY(gap >= 20);
    }
    void immediateHighlightAndOverlay() {
        auto *item = key("a"); QVERIFY(item);
        auto *surface = item->findChild<QQuickItem *>("keySurface"); QVERIFY(surface);
        auto *stateLayer = surface->findChild<QQuickItem *>("stateLayer"); QVERIFY(stateLayer);
        const auto restingRadius = surface->property("radius").toReal();
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, center(item));
        QVERIFY(stateLayer->property("opacity").toReal() > 0.1);
        QCOMPARE(surface->property("radius").toReal(), restingRadius);
        QTest::qWait(470);
        bool found = false;
        QList<QQuickItem *> pending{deck};
        while (!pending.isEmpty()) {
            auto *popup = pending.takeLast();
            pending.append(popup->childItems());
            if (popup->objectName() != "keyPreview" || !popup->isVisible()) continue;
            QVERIFY(popup->parentItem()->z() >= 1000);
            QVERIFY(popup->x() >= 0);
            QVERIFY(popup->x() + popup->width() <= deck->width());
            found = true;
        }
        QVERIFY(found);
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, center(item));
    }
    void purposeAndEmojiVariants() {
        deck->setProperty("purpose", 2); QTRY_VERIFY(key("1") && key("1")->width() > 20); QVERIFY(!key("q"));
        tap("1"); tap("2"); QCOMPARE(editor->property("text").toString(), QString("12"));
        deck->setProperty("purpose", 6); QTRY_VERIFY(key("@") && key("@")->width() > 20); tap("@");
        tap("__emoji"); tap("__category2"); QTRY_VERIFY(key("👍") && key("👍")->width() > 20);
        auto *item = key("👍");
        QCOMPARE(item->property("alternatives").value<QJSValue>().toVariant().toList().size(), 6);
    }
    void terminalPurposeKeepsFullKeyboard() {
        deck->setProperty("purpose", 12); QTRY_VERIFY(key("q") && key("q")->width() > 20);
        QVERIFY(key("Ctrl")); QVERIFY(key("Escape")); QVERIFY(key("|")); QVERIFY(key("~"));
        suggestions->updateEditorContext("hel", 3, false, 12);
        QVERIFY(suggestions->suggestions().isEmpty());
    }
    void controllerNavigation() {
        deck->setProperty("handheld", true);
        QVERIFY(deck->property("controllerActive").toBool());
        deck->setProperty("focusedKey", QVariant::fromValue(key("q")));
        QMetaObject::invokeMethod(deck, "controllerActivate");
        QCOMPARE(editor->property("text").toString(), QString("q"));
        QMetaObject::invokeMethod(deck, "controllerMove", Q_ARG(QVariant, 1), Q_ARG(QVariant, 0));
        auto *moved = deck->property("focusedKey").value<QQuickItem *>();
        QVERIFY(moved); QVERIFY(moved != key("q"));
        QMetaObject::invokeMethod(deck, "controllerActivate");
        QCOMPARE(editor->property("text").toString().size(), 2);
        QMetaObject::invokeMethod(deck, "controllerBack");
        QCOMPARE(editor->property("text").toString(), QString("q"));
    }
    void autoCapitalizeAndPunctuation() {
        tap("a"); tap("."); tap(" "); tap("b");
        QCOMPARE(editor->property("text").toString(), QString("a. B"));
        editor->setProperty("text", "hi"); editor->setProperty("cursorPosition", 2);
        tap(" "); tap(" "); tap("t");
        QCOMPARE(editor->property("text").toString(), QString("hi. T"));
    }
    void recentEmojiTab() {
        tap("__emoji"); QTRY_VERIFY(key("😀") && key("😀")->width() > 20);
        tap("😀"); QTRY_VERIFY(key("__category0") && key("__category0")->width() > 20);
        tap("__category0"); QTRY_VERIFY(key("😀") && key("😀")->width() > 20);
        tap("😀");
        QCOMPARE(editor->property("text").toString(), QString::fromUtf8("😀😀"));
    }
    void toolsMenuMorphsAndCloses() {
        openMenu();
        for (const auto &name : {"clipboard", "emoji", "edit", "trackpad", "terminal", "hand", "float", "resize", "languages", "symbols", "theme", "settings"})
            QVERIFY2(key(QString("__tool-") + name), name);
        QCOMPARE(deck->property("panel").toString(), QString("menu"));
        QVERIFY(!key("q"));
        tap("__keys");
        QTRY_VERIFY(deck->property("progressValue").toReal() < 0.01);
        QTRY_VERIFY(key("q") && key("q")->width() > 20);
        QVERIFY(!key("__tool-edit"));
    }
    void reduceMotionOpensAtOnce() {
        deck->setProperty("preferences", QVariantMap{{"reduceMotion", true}});
        tap("__tools");
        QCOMPARE(deck->property("progressValue").toReal(), 1.0);
    }
    void editPanelMovesAndSelects() {
        editor->setProperty("text", "abcdef"); editor->setProperty("cursorPosition", 2);
        useTool("edit");
        QTRY_VERIFY(key("Right") && key("Right")->width() > 20);
        QVERIFY(key("__select")); QVERIFY(key("Home")); QVERIFY(key("End")); QVERIFY(key("WordLeft")); QVERIFY(key("WordRight"));
        QVERIFY(key("Select all")); QVERIFY(key("Cut")); QVERIFY(key("Copy")); QVERIFY(key("Paste")); QVERIFY(key("Undo")); QVERIFY(key("Redo"));
        tap("Right"); QCOMPARE(editor->property("cursorPosition").toInt(), 3);
        tap("Left"); QTest::qWait(450); tap("Left"); QCOMPARE(editor->property("cursorPosition").toInt(), 1);
        tap("__keys"); QTRY_VERIFY(key("q") && key("q")->width() > 20);
    }
    void emojiSearchFindsByName() {
        useTool("emoji");
        QTRY_VERIFY(item("emojiSearch") && item("emojiSearch")->width() > 20);
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, center(item("emojiSearch"))); QCoreApplication::processEvents();
        QVERIFY(deck->property("emojiSearching").toBool());
        QTRY_VERIFY(key("f") && key("f")->width() > 20);
        typeWord("fire");
        QCOMPARE(deck->property("emojiQuery").toString(), QString("fire"));
        QTRY_VERIFY(key("🔥") && key("🔥")->width() > 20);
        QVERIFY(editor->property("text").toString().isEmpty());
        tap("🔥");
        QCOMPARE(editor->property("text").toString(), QString::fromUtf8("🔥"));
        tap("__searchdone");
        QTRY_VERIFY(!deck->property("emojiSearching").toBool());
        QCOMPARE(deck->property("panel").toString(), QString("emoji"));
    }
    void clipboardEmptyWithoutShell() {
        useTool("clipboard");
        QTRY_VERIFY(item("clipEmpty") && item("clipEmpty")->isVisible());
        QVERIFY(!deck->property("clipAvailable").toBool());
        QCOMPARE(deck->property("clipCount").toInt(), 0);
    }
    void clipboardPopulatedCommitsText() {
        clipboard->setFixture("[{\"id\":\"a\",\"text\":\"hello clip\"},{\"id\":\"b\",\"text\":\"#cfbdff\"},{\"id\":\"c\",\"text\":\"git status\",\"pinned\":true},{\"id\":\"d\",\"text\":\"https:\x2f/example.org/x\"}]");
        openMenu();
        QCOMPARE(deck->property("clipCount").toInt(), 4);
        tap("__tool-clipboard");
        QTRY_VERIFY_WITH_TIMEOUT(deck->property("progressValue").toReal() < 0.01, 5000);
        QTRY_VERIFY(item("clip-a") && item("clip-a")->width() > 20);
        QVERIFY(!item("clipEmpty") || !item("clipEmpty")->isVisible());
        QVERIFY(item("clip-c")->y() <= item("clip-a")->y());
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, center(item("clip-a"))); QCoreApplication::processEvents();
        QCOMPARE(editor->property("text").toString(), QString("hello clip"));
    }
    void clipboardHiddenInSensitiveFields() {
        clipboard->setFixture(R"([{"id":"a","text":"secret"}])");
        window->setProperty("privatePreview", true);
        deck->setProperty("privateInput", true);
        QCOMPARE(deck->property("clipCount").toInt(), 0);
        openMenu();
        tap("__tool-clipboard"); QTest::qWait(60);
        QVERIFY(deck->property("panel").toString() != "clipboard");
    }
    void trackpadPanelAndSpaceHold() {
        editor->setProperty("text", "abcdefghij"); editor->setProperty("cursorPosition", 0);
        useTool("trackpad");
        QTRY_VERIFY(item("trackpadSurface") && item("trackpadSurface")->width() > 20);
        const auto start = center(item("trackpadSurface"));
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, start);
        QTest::mouseMove(window, start + QPoint(40, 0));
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, start + QPoint(40, 0));
        QCOMPARE(editor->property("cursorPosition").toInt(), 3);
        tap("__keys"); QTRY_VERIFY(key(" ") && key(" ")->width() > 20);
        auto *space = key(" ");
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, center(space));
        QTRY_VERIFY_WITH_TIMEOUT(deck->property("trackpadHold").toBool(), 1500);
        const auto from = center(space);
        QTest::mouseMove(window, from + QPoint(24, 0));
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, from + QPoint(24, 0));
        QVERIFY(!deck->property("trackpadHold").toBool());
        QCOMPARE(editor->property("cursorPosition").toInt(), 5);
    }
    void terminalRowAndCtrlLatch() {
        useTool("terminal");
        QVERIFY(deck->property("terminalMode").toBool());
        QTRY_VERIFY(key("Ctrl") && key("Ctrl")->width() > 20);
        QVERIFY(key("Escape")); QVERIFY(key("Tab")); QVERIFY(key("Alt")); QVERIFY(key("Left")); QVERIFY(key("Down")); QVERIFY(key("Up")); QVERIFY(key("Right"));
        QVERIFY(!key("1"));
        QCOMPARE(key("q")->property("hint").toString(), QString("1"));
        QVERIFY(key("|") && key("~") && key("/") && key("-") && key("_"));
        tap("Ctrl"); QVERIFY(deck->property("control").toBool()); QVERIFY(key("Ctrl")->property("filled").toBool());
        tap("c"); QVERIFY(!deck->property("control").toBool());
        QVERIFY(editor->property("text").toString().isEmpty());
        const auto chips = deck->property("suggestionChips").value<QJSValue>().toVariant().toList();
        QCOMPARE(chips.size(), 3);
        QCOMPARE(chips.at(0).toMap().value("label").toString(), QString("Paste"));
        QCOMPARE(chips.at(1).toMap().value("label").toString(), QString("Ctrl C"));
        QCOMPARE(chips.at(2).toMap().value("label").toString(), QString("Tab"));
        editor->setProperty("text", "hi"); editor->setProperty("cursorPosition", 2);
        tap(" "); QTest::qWait(450); tap(" "); tap("t");
        QCOMPARE(editor->property("text").toString(), QString("hi  t"));
    }
    void dockedBarToggles() {
        QVERIFY(!deck->property("dockedBar").toBool());
        deck->setProperty("dockedPreview", true);
        QTRY_VERIFY(item("dockedBar") && item("dockedBar")->width() > 100);
        QVERIFY(!key("q"));
        QVERIFY(key("__dock-emoji") && key("__dock-clipboard") && key("__dock-show"));
        tap("__dock-show");
        QTRY_VERIFY(key("q") && key("q")->width() > 20);
        QVERIFY(!item("dockedBar"));
    }
    void dockedBarFollowsPhysicalKeyboardAndPreference() {
        QTemporaryFile devices; QVERIFY(devices.open());
        devices.write("I: Bus=0003 Vendor=046d Product=c52b Version=0111\nN: Name=\"Logitech USB Receiver\"\nH: Handlers=sysrq kbd leds event3\nB: EV=120013\n\n"); devices.flush();
        physical = std::make_unique<PhysicalKeyboard>(nullptr, devices.fileName());
        QVERIFY(physical->present());
        deck->setProperty("physicalKeyboard", QVariant::fromValue(static_cast<QObject *>(physical.get())));
        QTRY_VERIFY(deck->property("dockedBar").toBool());
        deck->setProperty("preferences", QVariantMap{{"keyboardDocked", "never"}});
        QTRY_VERIFY(!deck->property("dockedBar").toBool());
        deck->setProperty("preferences", QVariantMap{});
        QTRY_VERIFY(deck->property("dockedBar").toBool());
        tap("__dock-clipboard");
        QTRY_VERIFY(!deck->property("dockedBar").toBool());
        QCOMPARE(deck->property("panel").toString(), QString("clipboard"));
    }
    void controllerFocusRingAndSuggestionPicks() {
        deck->setProperty("handheld", true);
        QTRY_VERIFY(item("hintBar") && item("hintBar")->isVisible());
        QTRY_VERIFY(deck->property("focusedKey").value<QQuickItem *>() != nullptr);
        auto *focused = deck->property("focusedKey").value<QQuickItem *>();
        auto *surface = focused->findChild<QQuickItem *>("keySurface"); QVERIFY(surface);
        QTRY_VERIFY(surface->property("scale").toReal() > 1.05);
        QVERIFY(key("q")->height() >= 60);
        editor->setProperty("text", "tha"); editor->setProperty("cursorPosition", 3);
        QTRY_VERIFY(!suggestions->suggestions().isEmpty());
        const auto chips = deck->property("suggestionChips").value<QJSValue>().toVariant().toList();
        QVERIFY(chips.size() >= 1);
        emit gamepad->action("prev-suggestion");
        QCOMPARE(editor->property("text").toString(), chips.first().toMap().value("label").toString() + " ");
        editor->setProperty("text", "tha"); editor->setProperty("cursorPosition", 3);
        QTRY_VERIFY(!suggestions->suggestions().isEmpty());
        const auto again = deck->property("suggestionChips").value<QJSValue>().toVariant().toList();
        emit gamepad->action("next-suggestion");
        QCOMPARE(editor->property("text").toString(), again.last().toMap().value("label").toString() + " ");
        emit gamepad->action("symbols");
        QTRY_VERIFY(key("@") && key("@")->width() > 20);
        emit gamepad->action("symbols");
        QTRY_VERIFY(key("q") && key("q")->width() > 20);
        editor->setProperty("text", "abc"); editor->setProperty("cursorPosition", 3);
        emit gamepad->action("cursor-on"); emit gamepad->action("left"); emit gamepad->action("cursor-off");
        QCOMPARE(editor->property("cursorPosition").toInt(), 2);
    }
    void floatingCardMovesResizesDocks() {
        window->resize(1280, 800); QTest::qWait(80);
        QVERIFY(deck->property("canFloat").toBool());
        useTool("float");
        QTRY_VERIFY(deck->property("floating").toBool());
        QVERIFY(deck->width() < 700);
        QTRY_VERIFY(key("q") && key("q")->width() > 20);
        QTRY_VERIFY(item("floatGrip") && item("floatGrip")->isVisible());
        const auto x0 = deck->property("floatX").toReal();
        const auto grip = center(item("floatGrip"));
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, grip);
        QTest::mouseMove(window, grip + QPoint(-30, -10)); QTest::mouseMove(window, grip + QPoint(-90, -40));
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, grip + QPoint(-90, -40));
        QVERIFY(deck->property("floatX").toReal() < x0 - 40);
        QMetaObject::invokeMethod(deck, "resizeFloat", Q_ARG(QVariant, 640));
        QCOMPARE(deck->property("floatWidth").toReal(), 640.0);
        tap("q"); QCOMPARE(editor->property("text").toString(), QString("q"));
        const auto gripNow = center(item("floatGrip"));
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, gripNow); QTest::mouseDClick(window, Qt::LeftButton, Qt::NoModifier, gripNow);
        QTRY_VERIFY(!deck->property("floating").toBool());
        QCOMPARE(deck->width(), qreal(window->width()));
    }
    void floatingNeedsWideHost() {
        openMenu();
        auto *tile = key("__tool-float"); QVERIFY(tile);
        QVERIFY(!tile->isEnabled());
    }
    void keyStyleToggles() {
        QCOMPARE(deck->property("keyStyle").toString(), QString("tonal"));
        useTool("theme"); QTRY_COMPARE(deck->property("keyStyle").toString(), QString("borderless"));
        tap("__keys"); QTRY_VERIFY(key("q") && key("q")->width() > 20);
    }
    void simultaneousTouches() {
        auto *device = QTest::createTouchDevice();
        auto *a = key("a"); auto *s = key("s"); QVERIFY(a && s);
        auto sequence = QTest::touchEvent(window, device);
        sequence.press(0, center(a), window).press(1, center(s), window).commit();
        sequence.release(0, center(a), window).stationary(1).commit();
        sequence.release(1, center(s), window).commit();
        QTRY_COMPARE_WITH_TIMEOUT(editor->property("text").toString(), QString("as"), 1000);
    }
};
QTEST_MAIN(KeyboardUiTest)
#include "ui-test.moc"
