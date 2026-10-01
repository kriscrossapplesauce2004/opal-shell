#pragma once
#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantMap>

class PreferenceStore : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap values READ values NOTIFY changed)
public:
    explicit PreferenceStore(QObject *parent = nullptr);
    QVariantMap values() const { return current; }
    void setLightOverride(bool enabled);
signals:
    void changed();
private:
    void scheduleReload();
    void reload();
    QString path;
    QString directory;
    QFileSystemWatcher watcher;
    QTimer debounce;
    QVariantMap current;
    bool forceLight = false;
};
