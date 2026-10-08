#include "PhysicalKeyboard.h"
#include <QFile>

PhysicalKeyboard::PhysicalKeyboard(QObject *parent, const QString &source) : QObject(parent), path(source) {
    // /proc files do not send change events, so poll slowly.
    poll.setInterval(5000);
    connect(&poll, &QTimer::timeout, this, &PhysicalKeyboard::rescan);
    poll.start();
    rescan();
}
void PhysicalKeyboard::rescan() {
    QFile file(path);
    const bool now = file.open(QIODevice::ReadOnly) && detect(file.read(256 * 1024));
    if (now == found) return;
    found = now;
    emit changed();
}
bool PhysicalKeyboard::detect(const QByteArray &list) {
    const auto blocks = QString::fromUtf8(list).split(QStringLiteral("\n\n"), Qt::SkipEmptyParts);
    for (const auto &block : blocks) {
        QString name, handlers, bus, ev;
        for (const auto &line : block.split('\n')) {
            if (line.startsWith(QLatin1String("I: "))) {
                const int at = line.indexOf(QLatin1String("Bus="));
                if (at >= 0) bus = line.mid(at + 4, 4);
            } else if (line.startsWith(QLatin1String("N: Name="))) name = line.mid(8).remove('"').toLower();
            else if (line.startsWith(QLatin1String("H: Handlers="))) handlers = line.mid(12);
            else if (line.startsWith(QLatin1String("B: EV="))) ev = line.mid(6).trimmed();
        }
        if (!handlers.split(' ').contains(QLatin1String("kbd"))) continue;
        // Bus 0006 is a virtual device, for example our own virtual keyboard.
        if (bus == QLatin1String("0006")) continue;
        bool ok = false;
        const auto events = ev.toULongLong(&ok, 16);
        // A typing keyboard reports key repeat (EV_REP, bit 20). Buttons and lids do not.
        if (!ok || !(events & (1ull << 20))) continue;
        static const QStringList ignored{"virtual", "uinput", "ydotool", "dummy", "consumer control", "system control", "power button", "sleep button", "video bus", "lid switch", "avrcp", "headset", "touchpad", "mouse"};
        bool skip = false;
        for (const auto &word : ignored) if (name.contains(word)) skip = true;
        if (!skip) return true;
    }
    return false;
}
