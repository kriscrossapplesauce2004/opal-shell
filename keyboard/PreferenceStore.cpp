#include "PreferenceStore.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QStandardPaths>

PreferenceStore::PreferenceStore(QObject *parent) : QObject(parent) {
    directory = QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + "/opal";
    path = directory + "/preferences.json";
    debounce.setSingleShot(true);
    debounce.setInterval(40);
    connect(&debounce, &QTimer::timeout, this, &PreferenceStore::reload);
    connect(&watcher, &QFileSystemWatcher::fileChanged, this, [this] { scheduleReload(); });
    connect(&watcher, &QFileSystemWatcher::directoryChanged, this, [this] { scheduleReload(); });
    if (QDir(directory).exists()) watcher.addPath(directory);
    reload();
}

void PreferenceStore::setLightOverride(bool enabled) {
    if (forceLight == enabled) return;
    forceLight = enabled;
    reload();
}

void PreferenceStore::scheduleReload() { debounce.start(); }

void PreferenceStore::reload() {
    QVariantMap next;
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        const auto document = QJsonDocument::fromJson(file.read(1024 * 1024));
        if (document.isObject()) next = document.toVariant().toMap();
    }
    if (forceLight) next["light"] = true;
    if (next != current) {
        current = next;
        emit changed();
    }
    if (QFile::exists(path) && !watcher.files().contains(path)) watcher.addPath(path);
    if (QDir(directory).exists() && !watcher.directories().contains(directory)) watcher.addPath(directory);
}
