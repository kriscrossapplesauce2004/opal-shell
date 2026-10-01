#include "Gamepad.h"
#include "InputMethod.h"
#include "PreferenceStore.h"
#include "SuggestionEngine.h"
#include <QInputMethodEvent>
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
    QPoint center(QQuickItem *item) { return item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint(); }
    void tap(const QString &value) {
        auto *item = key(value); QVERIFY2(item, qPrintable(value));
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, center(item));
        QCoreApplication::processEvents();
    }
private slots:
    void init() {
        input = std::make_unique<InputMethod>(); input->preview();
        gamepad = std::make_unique<Gamepad>();
        preferences = std::make_unique<PreferenceStore>();
        suggestions = std::make_unique<SuggestionEngine>();
        engine = std::make_unique<QQmlApplicationEngine>();
        engine->rootContext()->setContextProperty("inputMethod", input.get());
        engine->rootContext()->setContextProperty("gamepad", gamepad.get());
        engine->rootContext()->setContextProperty("preferenceStore", preferences.get());
        engine->rootContext()->setContextProperty("suggestionEngine", suggestions.get());
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
    void cleanup() { delete window; window = nullptr; engine.reset(); suggestions.reset(); preferences.reset(); input.reset(); gamepad.reset(); }
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
        tap("__emoji"); QTRY_VERIFY(key("__category1") && key("__category1")->width() > 20); tap("__category1"); QTRY_VERIFY(key("💜") && key("💜")->width() > 20); tap("💜");
        QTRY_VERIFY(key("__category2") && key("__category2")->width() > 20); tap("__category2"); QTRY_VERIFY(key("☕") && key("☕")->width() > 20); tap("☕");
        QCOMPARE(editor->property("text").toString(), QString::fromUtf8("1a💜☕"));
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
        tap("__edit"); tap("__select"); tap("Right"); tap("Right");
        QCOMPARE(editor->property("selectedText").toString(), QString("bc"));
        tap("__edit"); tap("z");
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
        const auto full = key("q")->width(); tap("__hand"); QTest::qWait(60);
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
        tap("__hand"); tap("__hand"); tap("__hand"); QTest::qWait(80);
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
        tap("__emoji"); tap("__category1"); QTRY_VERIFY(key("👍") && key("👍")->width() > 20);
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
        tap("😀"); QTRY_VERIFY(key("__category3") && key("__category3")->width() > 20);
        tap("__category3"); QTRY_VERIFY(key("😀") && key("😀")->width() > 20);
        tap("😀");
        QCOMPARE(editor->property("text").toString(), QString::fromUtf8("😀😀"));
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
