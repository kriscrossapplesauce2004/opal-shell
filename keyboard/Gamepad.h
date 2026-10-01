#pragma once
#include <QObject>
#include <QString>
class QSocketNotifier;
class QTimer;

// Reads the Linux joystick API without grabbing the device or injecting input.
class Gamepad : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
public:
    explicit Gamepad(QObject *parent = nullptr);
    ~Gamepad() override;
    bool connected() const { return descriptor >= 0; }
    QString name() const { return deviceName; }
    // Map one joystick button number to a keyboard action name.
    static QString buttonAction(int number);
    // Map one joystick axis direction to a navigation action name.
    static QString axisAction(int number, int value);
    Q_INVOKABLE void rescan();
signals:
    void changed();
    void action(const QString &name);
private:
    void discover();
    void readEvents();
    void closeDevice();
    void releaseRepeat();
    int descriptor = -1;
    QString deviceName;
    QSocketNotifier *notifier = nullptr;
    QTimer *retry = nullptr;
    QTimer *repeat = nullptr;
    int axisState[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    QString heldDirection;
};
