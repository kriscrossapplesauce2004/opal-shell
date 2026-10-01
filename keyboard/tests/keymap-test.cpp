#include "Keymap.h"
#include <QtTest>

class KeymapTest : public QObject {
    Q_OBJECT
private slots:
    void ascii() {
        Keymap map;
        QVERIFY(!map.bytes().isEmpty());
        for (uint32_t cp = 32; cp < 127; ++cp) QVERIFY2(map.character(cp).has_value(), qPrintable(QString::number(cp)));
        QCOMPARE(map.character('a')->code, 30u);
        QCOMPARE(map.character('A')->code, 30u);
        QVERIFY(map.character('A')->modifiers != map.character('a')->modifiers);
        QVERIFY(map.modifiers(true, false, false));
        QVERIFY(map.modifiers(false, true, false));
    }
    void unicode() {
        Keymap map;
        for (uint32_t cp : {0x00e9u, 0x1f600u, 0x20acu, 0x0301u}) {
            QVERIFY(map.reset(cp)); QVERIFY(map.character(cp).has_value());
            QVERIFY(map.character('a').has_value());
        }
        QVERIFY(map.reset());
        QVERIFY(!map.character(0).has_value());
    }
};
QTEST_GUILESS_MAIN(KeymapTest)
#include "keymap-test.moc"
