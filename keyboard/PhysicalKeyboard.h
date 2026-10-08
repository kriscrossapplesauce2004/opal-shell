#pragma once
#include <QObject>
#include <QTimer>

// Detects a real attached keyboard without grabbing any device.
class PhysicalKeyboard : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool present READ present NOTIFY changed)
public:
    explicit PhysicalKeyboard(QObject *parent = nullptr, const QString &source = QStringLiteral("/proc/bus/input/devices"));
    bool present() const { return found; }
    // True when the device list holds a real typing keyboard and not a virtual or button-only device.
    static bool detect(const QByteArray &deviceList);
    Q_INVOKABLE void rescan();
signals:
    void changed();
private:
    QString path;
    QTimer poll;
    bool found = false;
};
