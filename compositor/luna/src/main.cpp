#include "frame_log.h"
#include "output_capture.h"
#include "server.h"

#include <wlogging.h>
#include <wlr_all.h>
#include <wrenderhelper.h>
#include <wserver.h>
#include <woutputrenderwindow.h>

#include <QCommandLineParser>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLoggingCategory>
#include <QQmlApplicationEngine>
#include <QSocketNotifier>
#include <QTimer>

#include <chrono>
#include <csignal>
#include <thread>
#include <cstdio>
#include <cstdlib>
#include <sys/socket.h>
#include <unistd.h>

WAYLIB_SERVER_USE_NAMESPACE

namespace {

int g_shotPipe[2] = {-1, -1};
int g_quitPipe[2] = {-1, -1};

// Signal handler: write one byte, the event loop quits.
void onQuitSignal(int)
{
    const char byte = 1;
    [[maybe_unused]] const auto written = ::write(g_quitPipe[0], &byte, 1);
}

// Signal handler: write one byte, the event loop takes the screenshot.
void onShotSignal(int)
{
    const char byte = 1;
    [[maybe_unused]] const auto written = ::write(g_shotPipe[0], &byte, 1);
}

// Reads one option before QGuiApplication exists, because the backend choice must be set first.
QString earlyOption(int argc, char *argv[], const char *name, const QString &fallback)
{
    const QByteArray flag = QByteArray("--") + name;
    for (int i = 1; i < argc; ++i) {
        const QByteArray arg(argv[i]);
        if (arg == flag && i + 1 < argc)
            return QString::fromLocal8Bit(argv[i + 1]);
        if (arg.startsWith(flag + '='))
            return QString::fromLocal8Bit(arg.mid(flag.size() + 1));
    }
    return fallback;
}

// Sets WLR_BACKENDS for the chosen backend; returns false for a refused choice.
bool selectBackend(const QString &backend)
{
    if (backend == QLatin1String("headless")) {
        // Outputs are made here with the --size mode, not by the backend.
        qputenv("WLR_BACKENDS", "headless");
        qputenv("WLR_HEADLESS_OUTPUTS", "1");
        qputenv("WLR_LIBINPUT_NO_DEVICES", "1");
        return true;
    }
    if (backend == QLatin1String("wayland")) {
        if (qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY")) {
            std::fprintf(stderr, "luna-compositor: --backend wayland needs WAYLAND_DISPLAY\n");
            return false;
        }
        qputenv("WLR_BACKENDS", "wayland");
        return true;
    }
    if (backend == QLatin1String("drm")) {
        // DRM takes the seat; never start it inside another graphical session.
        if (!qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY") || !qEnvironmentVariableIsEmpty("DISPLAY")
            || !qEnvironmentVariableIsEmpty("HYPRLAND_INSTANCE_SIGNATURE")) {
            std::fprintf(stderr, "luna-compositor: --backend drm runs only from a text VT, not inside a session\n");
            return false;
        }
        qputenv("WLR_BACKENDS", "drm,libinput");
        return true;
    }
    if (backend == QLatin1String("auto"))
        return true;
    std::fprintf(stderr, "luna-compositor: unknown backend %s\n", qPrintable(backend));
    return false;
}

}

int main(int argc, char *argv[])
{
    const QString backend = earlyOption(argc, argv, "backend", QStringLiteral("headless"));
    if (!selectBackend(backend))
        return 2;

    // wlroots logs only errors unless LUNA_DEBUG is set.
    WLog::init(qEnvironmentVariableIsSet("LUNA_DEBUG") ? WLR_DEBUG : WLR_ERROR);
    if (!qEnvironmentVariableIsSet("LUNA_DEBUG"))
        QLoggingCategory::setFilterRules(QStringLiteral("wlroots.debug=false\nwlroots.info=false\nwaylib.*.debug=false\nwaylib.*.info=false\nqt.qml.propertyCache.append=false"));
    WRenderHelper::setupRendererBackend();
    WServer::initializeQPA();

    QGuiApplication::setAttribute(Qt::AA_UseOpenGLES);
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
    QGuiApplication::setQuitOnLastWindowClosed(false);
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("luna-compositor"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Luna compositor on the waylib fork (wlroots)."));
    parser.addHelpOption();
    const QCommandLineOption backendOpt(QStringLiteral("backend"),
        QStringLiteral("headless (default), wayland (nested), drm (from a text VT only) or auto."),
        QStringLiteral("name"), QStringLiteral("headless"));
    const QCommandLineOption socketOpt(QStringLiteral("socket"),
        QStringLiteral("Wayland socket name."), QStringLiteral("name"), QStringLiteral("luna-0"));
    const QCommandLineOption sizeOpt(QStringLiteral("size"),
        QStringLiteral("Headless output size."), QStringLiteral("WxH"), QStringLiteral("1280x800"));
    const QCommandLineOption frameLogOpt(QStringLiteral("frame-log"),
        QStringLiteral("Write frame intervals as JSON to PATH on exit."), QStringLiteral("path"));
    const QCommandLineOption exitOpt(QStringLiteral("exit-after"),
        QStringLiteral("Quit after MS milliseconds; 0 runs until closed."), QStringLiteral("ms"), QStringLiteral("0"));
    const QCommandLineOption budgetOpt(QStringLiteral("budget-ms"),
        QStringLiteral("Frame budget used for the over-budget percentage."), QStringLiteral("ms"),
        QStringLiteral("16.7"));
    const QCommandLineOption shotOpt(QStringLiteral("screenshot"),
        QStringLiteral("Write the output to PATH as PNG after --screenshot-after MS."), QStringLiteral("path"));
    const QCommandLineOption shotAfterOpt(QStringLiteral("screenshot-after"),
        QStringLiteral("Delay for --screenshot in milliseconds."), QStringLiteral("ms"), QStringLiteral("5000"));
    const QCommandLineOption shotDirOpt(QStringLiteral("shot-dir"),
        QStringLiteral("On SIGUSR1, write the output to DIR/shot-NN.png."), QStringLiteral("dir"));
    const QCommandLineOption barOpt(QStringLiteral("stand-in-bar"),
        QStringLiteral("Show the minimal stand-in bar, for runs without a real shell."));
    const QCommandLineOption noXOpt(QStringLiteral("no-xwayland"), QStringLiteral("Do not offer Xwayland."));
    parser.addOptions({backendOpt, socketOpt, sizeOpt, frameLogOpt, exitOpt, budgetOpt, shotOpt, shotAfterOpt,
                       shotDirOpt, barOpt, noXOpt});
    parser.process(app);

    LunaOptions options;
    options.socketName = parser.value(socketOpt);
    options.standInBar = parser.isSet(barOpt);
    options.xwayland = !parser.isSet(noXOpt);
    const QStringList size = parser.value(sizeOpt).split(QLatin1Char('x'));
    if (size.size() == 2 && size[0].toInt() > 0 && size[1].toInt() > 0)
        options.headlessSize = QSize(size[0].toInt(), size[1].toInt());

    const double budget = parser.value(budgetOpt).toDouble();
    const QString logPath = parser.value(frameLogOpt);
    FrameLog frames(budget);

    auto *engine = new QQmlApplicationEngine;
    auto *server = new LunaServer(engine, options);
    if (!server->start()) {
        delete server;
        delete engine;
        return 1;
    }
    auto *capture = new OutputCapture(server->renderer(), &frames);
    server->setCapture(capture);

    // Children of the compositor (the shell, clients) find it through these.
    qputenv("WAYLAND_DISPLAY", QFileInfo(server->socketPath()).fileName().toLocal8Bit());
    if (!server->xwaylandDisplay().isEmpty())
        qputenv("DISPLAY", server->xwaylandDisplay());
    std::printf("luna-compositor socket=%s backend=%s xwayland=%s\n", qPrintable(server->socketPath()),
                qPrintable(backend), server->xwaylandDisplay().isEmpty() ? "off" : server->xwaylandDisplay().constData());
    std::fflush(stdout);

    // Asks for the next frame and schedules one, so an idle scene still gives a screenshot.
    auto shoot = [server, capture](const QString &path, std::function<void(bool)> done) {
        capture->requestShot(path, std::move(done));
        server->window()->update();
    };

    const QString shotPath = parser.value(shotOpt);
    if (!shotPath.isEmpty())
        QTimer::singleShot(parser.value(shotAfterOpt).toInt(), &app, [shoot, shotPath] { shoot(shotPath, {}); });

    // SIGUSR1 asks for a numbered screenshot in the shot folder.
    const QString shotDir = parser.value(shotDirOpt);
    int shotCount = 0;
    if (!shotDir.isEmpty() && ::socketpair(AF_UNIX, SOCK_STREAM, 0, g_shotPipe) == 0) {
        QDir().mkpath(shotDir);
        auto *notifier = new QSocketNotifier(g_shotPipe[1], QSocketNotifier::Read, &app);
        QObject::connect(notifier, &QSocketNotifier::activated, &app, [shoot, shotDir, &shotCount] {
            char byte = 0;
            [[maybe_unused]] const auto got = ::read(g_shotPipe[1], &byte, 1);
            const QString name = QStringLiteral("shot-%1.png").arg(++shotCount, 2, 10, QLatin1Char('0'));
            const QString tmp = shotDir + QStringLiteral("/.") + name;
            const QString final = shotDir + QLatin1Char('/') + name;
            shoot(tmp, [tmp, final](bool ok) {
                if (ok)
                    QFile::rename(tmp, final);
            });
        });
        std::signal(SIGUSR1, onShotSignal);
    }

    const qint64 exitAfterMs = parser.value(exitOpt).toLongLong();
    if (exitAfterMs > 0)
        QTimer::singleShot(static_cast<int>(exitAfterMs), &app, &QCoreApplication::quit);

    // SIGTERM and SIGINT end the run cleanly, so the frame log is still written.
    if (::socketpair(AF_UNIX, SOCK_STREAM, 0, g_quitPipe) == 0) {
        auto *quitNotifier = new QSocketNotifier(g_quitPipe[1], QSocketNotifier::Read, &app);
        QObject::connect(quitNotifier, &QSocketNotifier::activated, &app, &QCoreApplication::quit);
        std::signal(SIGTERM, onQuitSignal);
        std::signal(SIGINT, onQuitSignal);
    }

    const int code = app.exec();

    if (!logPath.isEmpty() && !frames.write(logPath, QStringLiteral("waylib-") + backend))
        std::fprintf(stderr, "luna-compositor: cannot write %s\n", qPrintable(logPath));

    // A teardown that hangs (seen once, nested) must not keep the seat or the socket: give it 5 s.
    std::thread([code] {
        std::this_thread::sleep_for(std::chrono::seconds(5));
        std::fprintf(stderr, "luna-compositor: teardown took over 5 s, exiting now\n");
        std::_Exit(code == 0 ? 3 : code);
    }).detach();

    delete capture;
    delete server;
    delete engine;
    return code;
}
