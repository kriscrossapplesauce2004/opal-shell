#include "ClipboardBridge.h"
#include "PhysicalKeyboard.h"
#include <QtTest>

class DevicesTest : public QObject {
    Q_OBJECT
private slots:
    void detectsRealKeyboard() {
        const QByteArray real =
            "I: Bus=0003 Vendor=046d Product=c52b Version=0111\nN: Name=\"Logitech USB Receiver\"\nH: Handlers=sysrq kbd leds event3\nB: EV=120013\n\n";
        QVERIFY(PhysicalKeyboard::detect(real));
    }
    void ignoresButtonsAndVirtualDevices() {
        const QByteArray other =
            "I: Bus=0019 Vendor=0000 Product=0001 Version=0000\nN: Name=\"Power Button\"\nH: Handlers=kbd event0\nB: EV=3\n\n"
            "I: Bus=0006 Vendor=0000 Product=0000 Version=0000\nN: Name=\"wlr_virtual_keyboard\"\nH: Handlers=sysrq kbd event9\nB: EV=120013\n\n"
            "I: Bus=0003 Vendor=1 Product=2 Version=0\nN: Name=\"Foo Consumer Control\"\nH: Handlers=kbd event5\nB: EV=1f\n\n"
            "I: Bus=0003 Vendor=1 Product=2 Version=0\nN: Name=\"Gaming Mouse\"\nH: Handlers=mouse0 event6\nB: EV=17\n\n";
        QVERIFY(!PhysicalKeyboard::detect(other));
        QVERIFY(!PhysicalKeyboard::detect(QByteArray()));
    }
    void missingSourceIsSafe() {
        PhysicalKeyboard keyboard(nullptr, "/nonexistent/devices");
        QVERIFY(!keyboard.present());
    }
    void classifiesClips() {
        QCOMPARE(ClipboardBridge::classify("#cfbdff", "Text"), QString("colour"));
        QCOMPARE(ClipboardBridge::classify("https://example.org/a", "Link"), QString("link"));
        QCOMPARE(ClipboardBridge::classify("sudo pacman -Syu", "Text"), QString("code"));
        QCOMPARE(ClipboardBridge::classify("Meet at 7", "Text"), QString("text"));
    }
    void parsesAndOrdersPinnedFirst() {
        const QByteArray json = R"([{"id":"a","text":"hello"},{"id":"b","text":"#fff","pinned":true},{"id":"c","text":"   "},{"id":"d","text":"x","image":"/nonexistent.png"}])";
        const auto items = ClipboardBridge::parse(json);
        QCOMPARE(items.size(), 2);
        QCOMPARE(items.at(0).toMap().value("id").toString(), QString("b"));
        QCOMPARE(items.at(0).toMap().value("kind").toString(), QString("colour"));
        QVERIFY(ClipboardBridge::parse("not json").isEmpty());
    }
    void fixtureStopsShellAccess() {
        ClipboardBridge bridge;
        QSignalSpy spy(&bridge, &ClipboardBridge::changed);
        bridge.setFixture(R"([{"id":"a","text":"one"}])");
        bridge.refresh();
        QCOMPARE(bridge.count(), 1);
        QVERIFY(bridge.available());
        QCOMPARE(spy.count(), 1);
    }
    void missingShellGivesEmptyState() {
        qputenv("OPAL_CONFIG_DIR", "/nonexistent");
        qputenv("PATH", "/nonexistent");
        ClipboardBridge bridge;
        QSignalSpy spy(&bridge, &ClipboardBridge::changed);
        bridge.refresh();
        QTest::qWait(200);
        QCOMPARE(bridge.count(), 0);
        QVERIFY(!bridge.available());
    }
};
QTEST_MAIN(DevicesTest)
#include "devices-test.moc"
