#pragma once
#include <QObject>
#include <QHash>
#include <QStringList>

class SuggestionEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList suggestions READ suggestions NOTIFY changed)
    Q_PROPERTY(int currentPrefixBytes READ currentPrefixBytes NOTIFY changed)
    Q_PROPERTY(QString currentPrefix READ currentPrefix NOTIFY changed)
public:
    explicit SuggestionEngine(QObject *parent = nullptr);
    QStringList suggestions() const { return candidates; }
    int currentPrefixBytes() const { return prefixBytes; }
    QString currentPrefix() const { return prefix; }
    Q_INVOKABLE void updateContext(const QString &text, int cursorByte, bool sensitive, int purpose);
    Q_INVOKABLE void updateEditorContext(const QString &text, int cursorCharacters, bool sensitive, int purpose);
    Q_INVOKABLE void noteAccepted(const QString &word);
signals:
    void changed();
private:
    static int distanceAtMostOne(const QString &left, const QString &right);
    static QString previousWord(const QString &text);
    QStringList words;
    QStringList candidates;
    QString prefix;
    int prefixBytes = 0;
    QHash<QString, int> accepted;
};
