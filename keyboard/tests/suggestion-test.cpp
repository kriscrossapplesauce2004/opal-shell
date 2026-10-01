#include "SuggestionEngine.h"
#include <QtTest>

class SuggestionTest : public QObject {
    Q_OBJECT
private slots:
    void completesAndCorrects() {
        SuggestionEngine engine;
        engine.updateEditorContext("tha", 3, false, 0);
        QVERIFY(!engine.suggestions().isEmpty());
        QCOMPARE(engine.currentPrefix(), QString("tha"));
        QCOMPARE(engine.currentPrefixBytes(), 3);
        engine.updateEditorContext("teh", 3, false, 0);
        QVERIFY(engine.suggestions().contains("the"));
    }
    void predictsAndProtectsPrivateInput() {
        SuggestionEngine engine;
        engine.updateEditorContext("thank ", 6, false, 0);
        QVERIFY(engine.suggestions().contains("you"));
        engine.updateEditorContext("password", 8, true, 8);
        QVERIFY(engine.suggestions().isEmpty());
        QCOMPARE(engine.currentPrefixBytes(), 0);
    }
};
QTEST_GUILESS_MAIN(SuggestionTest)
#include "suggestion-test.moc"
