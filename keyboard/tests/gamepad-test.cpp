#include "Gamepad.h"
#include <QtTest>

class GamepadTest : public QObject {
    Q_OBJECT
private slots:
    void buttonMapping() {
        QCOMPARE(Gamepad::buttonAction(0), QString("accept"));
        QCOMPARE(Gamepad::buttonAction(1), QString("back"));
        QCOMPARE(Gamepad::buttonAction(3), QString("shift"));
        QCOMPARE(Gamepad::buttonAction(2), QString("space"));
        QCOMPARE(Gamepad::buttonAction(4), QString("prev-suggestion"));
        QCOMPARE(Gamepad::buttonAction(5), QString("next-suggestion"));
        QCOMPARE(Gamepad::buttonAction(7), QString("hide"));
        QCOMPARE(Gamepad::buttonAction(9), QString());
        QCOMPARE(Gamepad::buttonAction(12), QString());
    }
    void axisMapping() {
        QCOMPARE(Gamepad::axisAction(0, 30000), QString("right"));
        QCOMPARE(Gamepad::axisAction(0, -30000), QString("left"));
        QCOMPARE(Gamepad::axisAction(1, 30000), QString("down"));
        QCOMPARE(Gamepad::axisAction(7, -30000), QString("up"));
        QCOMPARE(Gamepad::axisAction(6, 30000), QString("right"));
        QCOMPARE(Gamepad::axisAction(0, 12000), QString());
        QCOMPARE(Gamepad::axisAction(2, 30000), QString());
        QCOMPARE(Gamepad::axisAction(5, -30000), QString());
    }
    void triggerMapping() {
        QCOMPARE(Gamepad::triggerAction(2, 30000), QString("symbols"));
        QCOMPARE(Gamepad::triggerAction(2, -30000), QString());
        QCOMPARE(Gamepad::triggerAction(5, 30000), QString("cursor-on"));
        QCOMPARE(Gamepad::triggerAction(5, -30000), QString("cursor-off"));
        QCOMPARE(Gamepad::triggerAction(1, 30000), QString());
    }
    void missingDeviceIsSafe() {
        Gamepad pad;
        QVERIFY(!pad.connected());
        QVERIFY(pad.name().isEmpty());
    }
};
QTEST_MAIN(GamepadTest)
#include "gamepad-test.moc"
