#pragma once

#include <QList>
#include <QObject>
#include <QString>

#include <functional>
#include <memory>

struct wlr_output;
struct wlr_renderer;
class FrameLog;

// Watches output commits: feeds the frame log and writes screenshots from the committed buffer.
class OutputCapture : public QObject
{
    Q_OBJECT

public:
    OutputCapture(wlr_renderer *renderer, FrameLog *frames, QObject *parent = nullptr);
    ~OutputCapture() override;

    void watch(wlr_output *output);
    void unwatch(wlr_output *output);

    // Writes the next committed frame of the first output to path as PNG; done gets the result.
    void requestShot(const QString &path, std::function<void(bool)> done = {});

private:
    struct Watch;
    void onCommit(Watch *watch, void *data);

    wlr_renderer *m_renderer;
    FrameLog *m_frames;
    QList<Watch *> m_watches;
    QString m_shotPath;
    std::function<void(bool)> m_shotDone;
};
