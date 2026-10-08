#include "Gamepad.h"
#include <QSocketNotifier>
#include <QTimer>
#include <cerrno>
#include <fcntl.h>
#include <linux/joystick.h>
#include <unistd.h>

namespace {
// Repeat delay for a held direction, in milliseconds.
const int repeatInterval = 130;
// Minimum stick movement that counts as a direction.
const int deadZone = 16000;
}

Gamepad::Gamepad(QObject *parent) : QObject(parent) {
    retry = new QTimer(this);
    retry->setInterval(4000);
    connect(retry, &QTimer::timeout, this, &Gamepad::discover);
    retry->start();
    repeat = new QTimer(this);
    repeat->setInterval(repeatInterval);
    connect(repeat, &QTimer::timeout, this, [this] { if (!heldDirection.isEmpty()) emit action(heldDirection); });
    discover();
}
Gamepad::~Gamepad() { closeDevice(); }
QString Gamepad::buttonAction(int number) {
    switch (number) {
    case 0: return QStringLiteral("accept");
    case 1: return QStringLiteral("back");
    case 2: return QStringLiteral("space");
    case 3: return QStringLiteral("shift");
    // LB and RB pick the previous and next suggestion.
    case 4: return QStringLiteral("prev-suggestion");
    case 5: return QStringLiteral("next-suggestion");
    case 6: return QStringLiteral("emoji");
    case 7: return QStringLiteral("hide");
    default: return QString();
    }
}
QString Gamepad::axisAction(int number, int value) {
    if (value > -deadZone && value < deadZone) return QString();
    // Only the left stick and the directional hat are navigation axes.
    switch (number) {
    case 0: case 6: return value > 0 ? QStringLiteral("right") : QStringLiteral("left");
    case 1: case 7: return value > 0 ? QStringLiteral("down") : QStringLiteral("up");
    default: return QString();
    }
}
QString Gamepad::triggerAction(int number, int value) {
    // Triggers rest at the minimum value and report the maximum when fully pressed.
    const bool pressed = value > 0;
    if (number == 2) return pressed ? QStringLiteral("symbols") : QString();
    if (number == 5) return pressed ? QStringLiteral("cursor-on") : QStringLiteral("cursor-off");
    return QString();
}
void Gamepad::rescan() { if (!connected()) discover(); }
void Gamepad::discover() {
    if (connected()) return;
    for (int index = 0; index < 8 && !connected(); ++index) {
        const auto path = QStringLiteral("/dev/input/js%1").arg(index);
        const int handle = ::open(path.toLocal8Bit().constData(), O_RDONLY | O_NONBLOCK);
        if (handle < 0) continue;
        char label[128] = {0};
        __u8 buttons = 0;
        const bool named = ::ioctl(handle, JSIOCGNAME(sizeof(label) - 1), label) >= 0;
        const bool counted = ::ioctl(handle, JSIOCGBUTTONS, &buttons) >= 0;
        const auto text = QString::fromLocal8Bit(label).toLower();
        const bool pointer = text.contains("pointer") || text.contains("mouse") || text.contains("keyboard");
        if (!named || !counted || buttons < 6 || pointer) { ::close(handle); continue; }
        descriptor = handle;
        deviceName = QString::fromLocal8Bit(label);
        notifier = new QSocketNotifier(descriptor, QSocketNotifier::Read, this);
        connect(notifier, &QSocketNotifier::activated, this, &Gamepad::readEvents);
        retry->stop();
        emit changed();
        return;
    }
}
void Gamepad::readEvents() {
    js_event event;
    while (::read(descriptor, &event, sizeof(event)) == qint64(sizeof(event))) {
        if (event.type & JS_EVENT_INIT) continue;
        if (event.type == JS_EVENT_BUTTON && event.value == 1) {
            const auto name = buttonAction(event.number);
            if (!name.isEmpty()) emit action(name);
        } else if (event.type == JS_EVENT_AXIS && event.number < 8) {
            const int index = event.number;
            if (index == 2 || index == 5) {
                const bool was = axisState[index] > 0;
                axisState[index] = event.value;
                if (was != (event.value > 0)) {
                    const auto name = triggerAction(index, event.value);
                    if (!name.isEmpty()) emit action(name);
                }
                continue;
            }
            const auto before = axisAction(index, axisState[index]);
            axisState[index] = event.value;
            const auto now = axisAction(index, event.value);
            if (now == before) continue;
            if (!now.isEmpty()) {
                heldDirection = now;
                emit action(now);
                if (!repeat->isActive()) repeat->start();
            } else if (heldDirection == before) {
                releaseRepeat();
            }
        }
    }
    if (errno != EAGAIN && errno != EWOULDBLOCK) { closeDevice(); retry->start(); }
}
void Gamepad::releaseRepeat() {
    heldDirection.clear();
    repeat->stop();
}
void Gamepad::closeDevice() {
    releaseRepeat();
    delete notifier; notifier = nullptr;
    if (descriptor >= 0) ::close(descriptor);
    descriptor = -1;
    deviceName.clear();
    for (int index = 0; index < 8; ++index) axisState[index] = 0;
    if (retry && !retry->isActive()) retry->start();
    emit changed();
}
