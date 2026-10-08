#include "ClipboardBridge.h"
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

namespace {
// Largest history the keyboard shows.
const int maxEntries = 24;
// Largest image file the keyboard shows as a thumbnail.
const qint64 maxImageBytes = 8 * 1024 * 1024;
}

ClipboardBridge::ClipboardBridge(QObject *parent) : QObject(parent) {}

QString ClipboardBridge::classify(const QString &text, const QString &kind) {
    static const QRegularExpression colour(QStringLiteral("^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"));
    static const QRegularExpression link(QStringLiteral("^https?://\\S+$"));
    static const QRegularExpression code(QStringLiteral("(&&|\\|\\||;\\s*$|\\{|\\}|=>|::|^\\s*(sudo|git|cmake|npm|cargo|pacman|ls|cd|curl)\\b|\\$\\()"), QRegularExpression::MultilineOption);
    const auto trimmed = text.trimmed();
    if (colour.match(trimmed).hasMatch()) return QStringLiteral("colour");
    if (link.match(trimmed).hasMatch() || kind == QLatin1String("Link")) return QStringLiteral("link");
    if (kind == QLatin1String("Snippet") || code.match(trimmed).hasMatch()) return QStringLiteral("code");
    return QStringLiteral("text");
}

QVariantList ClipboardBridge::parse(const QByteArray &json) {
    QVariantList pinned, rest;
    const auto document = QJsonDocument::fromJson(json.left(2 * 1024 * 1024));
    if (!document.isArray()) return {};
    for (const auto &value : document.array()) {
        if (!value.isObject()) continue;
        const auto object = value.toObject();
        const auto text = object.value("text").toString().left(4000);
        const auto image = object.value("image").toString();
        QVariantMap entry;
        entry["id"] = object.value("id").toString();
        entry["pinned"] = object.value("pinned").toBool(false);
        entry["text"] = text;
        entry["tooLong"] = object.value("text").toString().toUtf8().size() > 4000;
        if (!image.isEmpty()) {
            // Only local image files of sane size are shown. Remote sources are never fetched.
            const QFileInfo info(image);
            const auto suffix = info.suffix().toLower();
            if (!info.isAbsolute() || !info.isFile() || info.size() > maxImageBytes || (suffix != "png" && suffix != "jpg" && suffix != "jpeg" && suffix != "webp")) continue;
            entry["kind"] = QStringLiteral("image");
            entry["image"] = QUrl::fromLocalFile(image).toString();
        } else {
            if (text.trimmed().isEmpty()) continue;
            entry["kind"] = classify(text, object.value("kind").toString());
            if (entry["kind"] == QLatin1String("colour")) entry["colour"] = text.trimmed();
        }
        (entry["pinned"].toBool() ? pinned : rest) << entry;
    }
    QVariantList all = pinned + rest;
    while (all.size() > maxEntries) all.removeLast();
    return all;
}

void ClipboardBridge::setFixture(const QByteArray &json) {
    fixed = true;
    if (process) { process->kill(); process->deleteLater(); process = nullptr; }
    entries = parse(json);
    reachable = true;
    emit changed();
}

void ClipboardBridge::refresh() {
    if (fixed || process) return;
    // An explicit switch lets tests and previews avoid touching a running shell.
    if (qEnvironmentVariable("BOREALIS_CLIPBOARD") == QLatin1String("off")) return;
    QString config = qEnvironmentVariable("OPAL_CONFIG_DIR");
    if (config.isEmpty()) config = QDir::homePath() + QStringLiteral("/.config/quickshell/opal");
    QStringList arguments{QStringLiteral("ipc")};
    if (QDir(config).exists()) arguments << QStringLiteral("-p") << config;
    arguments << QStringLiteral("call") << QStringLiteral("opal") << QStringLiteral("clipboardHistory");
    process = new QProcess(this);
    auto *deadline = new QTimer(process);
    deadline->setSingleShot(true);
    connect(deadline, &QTimer::timeout, process, [this] { if (process) process->kill(); });
    connect(process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        const auto output = process->readAllStandardOutput();
        process->deleteLater(); process = nullptr;
        finish(status == QProcess::NormalExit && code == 0, output);
    });
    connect(process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart || !process) return;
        process->deleteLater(); process = nullptr;
        finish(false, {});
    });
    process->setProcessChannelMode(QProcess::SeparateChannels);
    process->start(QStringLiteral("quickshell"), arguments, QIODevice::ReadOnly);
    deadline->start(3000);
}

void ClipboardBridge::finish(bool ok, const QByteArray &output) {
    const auto next = ok ? parse(output.trimmed()) : QVariantList();
    if (next == entries && ok == reachable) return;
    entries = next; reachable = ok;
    emit changed();
}
