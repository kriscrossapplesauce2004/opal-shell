#pragma once
#include <QObject>
#include <QProcess>
#include <QVariantList>

// Read-only view of Opal's clipboard history. It calls one shell IPC method and never writes.
class ClipboardBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ items NOTIFY changed)
    Q_PROPERTY(int count READ count NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)
public:
    explicit ClipboardBridge(QObject *parent = nullptr);
    QVariantList items() const { return entries; }
    int count() const { return entries.size(); }
    bool available() const { return reachable; }
    // Parse the shell reply into display entries. Pinned entries come first.
    static QVariantList parse(const QByteArray &json);
    // Classify one text as text, code, link or colour.
    static QString classify(const QString &text, const QString &kind);
    // Ask the running shell for its history. A missing shell gives an empty state.
    Q_INVOKABLE void refresh();
    // Test seam: replace the history with fixed entries and stop talking to the shell.
    Q_INVOKABLE void setFixture(const QByteArray &json);
signals:
    void changed();
private:
    void finish(bool ok, const QByteArray &output);
    QProcess *process = nullptr;
    QVariantList entries;
    bool reachable = false;
    bool fixed = false;
};
