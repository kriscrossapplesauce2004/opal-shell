#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QSocketNotifier>
#include <QTimer>
#include <QtWaylandCompositor/QWaylandCompositor>
#include <QtWaylandCompositor/private/qwaylandpresentationtime_p.h>

#include <csignal>
#include <ctime>
#include <cstdio>
#include <sys/socket.h>
#include <unistd.h>

#include "frame_log.h"

namespace {

int g_shotPipe[2] = {-1, -1};

// Signal handler: write one byte, the event loop takes the screenshot.
void onShotSignal(int)
{
    const char byte = 1;
    [[maybe_unused]] const auto written = ::write(g_shotPipe[0], &byte, 1);
}

// Writes the current scene to path as PNG.
bool saveShot(QQuickWindow *window, const QString &path)
{
    const QImage image = window->grabWindow();
    if (image.isNull() || !image.save(path)) {
        std::fprintf(stderr, "luna-compositor: cannot write screenshot %s\n", qPrintable(path));
        return false;
    }
    std::printf("luna-compositor screenshot=%s\n", qPrintable(path));
    std::fflush(stdout);
    return true;
}

}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("luna-compositor"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Luna compositor spike (QtWaylandCompositor)."));
    parser.addHelpOption();
    const QCommandLineOption socketOpt(QStringLiteral("socket"),
        QStringLiteral("Wayland socket name."), QStringLiteral("name"), QStringLiteral("luna-0"));
    const QCommandLineOption frameLogOpt(QStringLiteral("frame-log"),
        QStringLiteral("Write frame intervals as JSON to PATH on exit."), QStringLiteral("path"));
    const QCommandLineOption exitOpt(QStringLiteral("exit-after"),
        QStringLiteral("Quit after MS milliseconds; 0 runs until closed."), QStringLiteral("ms"),
        QStringLiteral("0"));
    const QCommandLineOption budgetOpt(QStringLiteral("budget-ms"),
        QStringLiteral("Frame budget used for the over-budget percentage."), QStringLiteral("ms"),
        QStringLiteral("16.7"));
    const QCommandLineOption shotOpt(QStringLiteral("screenshot"),
        QStringLiteral("Write the scene to PATH as PNG after --screenshot-after MS."), QStringLiteral("path"));
    const QCommandLineOption shotAfterOpt(QStringLiteral("screenshot-after"),
        QStringLiteral("Delay for --screenshot in milliseconds."), QStringLiteral("ms"), QStringLiteral("5000"));
    const QCommandLineOption shotDirOpt(QStringLiteral("shot-dir"),
        QStringLiteral("On SIGUSR1, write the scene to DIR/shot-NN.png."), QStringLiteral("dir"));
    const QCommandLineOption barOpt(QStringLiteral("stand-in-bar"),
        QStringLiteral("Show the minimal stand-in bar, for runs without a real shell."));
    parser.addOptions({socketOpt, frameLogOpt, exitOpt, budgetOpt, shotOpt, shotAfterOpt, shotDirOpt, barOpt});
    parser.process(app);

    const QString socketName = parser.value(socketOpt);
    const QString logPath = parser.value(frameLogOpt);
    const qint64 exitAfterMs = parser.value(exitOpt).toLongLong();

    FrameLog frames(parser.value(budgetOpt).toDouble());

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lunaSocketName"), socketName);
    engine.rootContext()->setContextProperty(QStringLiteral("lunaStandInBar"), parser.isSet(barOpt));
    engine.loadFromModule(QStringLiteral("Luna.Compositor"), QStringLiteral("Main"));

    auto *window = engine.rootObjects().isEmpty()
        ? nullptr
        : qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    if (!window) {
        std::fprintf(stderr, "luna-compositor: Main.qml did not load a QQuickWindow\n");
        return 1;
    }

    auto *compositor = window->findChild<QWaylandCompositor *>();

    // The QML PresentationTime element finds no compositor, so wp_presentation is made here.
    QWaylandPresentationTime *presentation = nullptr;
    if (compositor) {
        presentation = new QWaylandPresentationTime(compositor);
        presentation->initialize();
    }
    quint64 presentSequence = 0;

    // Each swapped frame adds one timestamp and sends presentation feedback.
    QObject::connect(window, &QQuickWindow::frameSwapped, &app, [&frames, presentation, window, &presentSequence] {
        frames.frameSwapped();
        if (presentation) {
            timespec now {};
            clock_gettime(CLOCK_MONOTONIC, &now);
            presentation->sendFeedback(window, ++presentSequence, static_cast<quint64>(now.tv_sec),
                                       static_cast<quint32>(now.tv_nsec));
        }
    });
    const QString shownSocket = compositor ? QString::fromUtf8(compositor->socketName()) : socketName;
    std::printf("luna-compositor socket=%s platform=%s\n", qPrintable(shownSocket),
                qPrintable(app.platformName()));
    std::fflush(stdout);

    const QString shotPath = parser.value(shotOpt);
    if (!shotPath.isEmpty()) {
        QTimer::singleShot(parser.value(shotAfterOpt).toInt(), window, [window, shotPath] {
            saveShot(window, shotPath);
        });
    }

    // SIGUSR1 asks for a numbered screenshot in the shot folder.
    const QString shotDir = parser.value(shotDirOpt);
    int shotCount = 0;
    if (!shotDir.isEmpty() && ::socketpair(AF_UNIX, SOCK_STREAM, 0, g_shotPipe) == 0) {
        QDir().mkpath(shotDir);
        auto *notifier = new QSocketNotifier(g_shotPipe[1], QSocketNotifier::Read, &app);
        QObject::connect(notifier, &QSocketNotifier::activated, window, [window, shotDir, &shotCount] {
            char byte = 0;
            [[maybe_unused]] const auto got = ::read(g_shotPipe[1], &byte, 1);
            const QString name = QStringLiteral("shot-%1.png").arg(++shotCount, 2, 10, QLatin1Char('0'));
            const QString tmp = shotDir + QStringLiteral("/.") + name;
            if (saveShot(window, tmp))
                QFile::rename(tmp, shotDir + QLatin1Char('/') + name);
        });
        std::signal(SIGUSR1, onShotSignal);
    }

    if (exitAfterMs > 0)
        QTimer::singleShot(static_cast<int>(exitAfterMs), &app, &QCoreApplication::quit);

    QObject::connect(&app, &QCoreApplication::aboutToQuit, &app, [&frames, &logPath, &app] {
        if (logPath.isEmpty())
            return;
        if (!frames.write(logPath, app.platformName()))
            std::fprintf(stderr, "luna-compositor: cannot write %s\n", qPrintable(logPath));
    });

    return app.exec();
}
