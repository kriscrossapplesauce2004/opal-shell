#include "output_capture.h"

#include "frame_log.h"

#include <wlr_all.h>
#include <drm_fourcc.h>

#include <QImage>

#include <cstdio>

// One listener on one output's commit signal.
struct OutputCapture::Watch
{
    OutputCapture *owner = nullptr;
    wlr_output *output = nullptr;
    wl_listener commit {};
    wl_listener destroy {};
};

namespace {

// Reads a buffer back through the renderer; returns a null image on failure.
QImage readBuffer(wlr_renderer *renderer, wlr_buffer *buffer)
{
    wlr_texture *texture = wlr_texture_from_buffer(renderer, buffer);
    if (!texture)
        return {};
    QImage image(static_cast<int>(texture->width), static_cast<int>(texture->height), QImage::Format_ARGB32);
    wlr_texture_read_pixels_options options {
        .data = image.bits(),
        .format = DRM_FORMAT_ARGB8888,
        .stride = static_cast<uint32_t>(image.bytesPerLine()),
        .dst_x = 0,
        .dst_y = 0,
        .src_box = {},
    };
    const bool ok = wlr_texture_read_pixels(texture, &options);
    wlr_texture_destroy(texture);
    if (!ok)
        return {};
    // The output content is opaque; drop the alpha that the read-back may leave at zero.
    return image.convertToFormat(QImage::Format_RGB32);
}

}

OutputCapture::OutputCapture(wlr_renderer *renderer, FrameLog *frames, QObject *parent)
    : QObject(parent)
    , m_renderer(renderer)
    , m_frames(frames)
{
}

OutputCapture::~OutputCapture()
{
    while (!m_watches.isEmpty())
        unwatch(m_watches.first()->output);
}

void OutputCapture::watch(wlr_output *output)
{
    auto *w = new Watch;
    w->owner = this;
    w->output = output;
    w->commit.notify = [](wl_listener *listener, void *data) {
        Watch *self = wl_container_of(listener, self, commit);
        self->owner->onCommit(self, data);
    };
    w->destroy.notify = [](wl_listener *listener, void *) {
        Watch *self = wl_container_of(listener, self, destroy);
        self->owner->unwatch(self->output);
    };
    wl_signal_add(&output->events.commit, &w->commit);
    wl_signal_add(&output->events.destroy, &w->destroy);
    m_watches.append(w);
}

void OutputCapture::unwatch(wlr_output *output)
{
    for (int i = 0; i < m_watches.size(); ++i) {
        Watch *w = m_watches.at(i);
        if (w->output != output)
            continue;
        wl_list_remove(&w->commit.link);
        wl_list_remove(&w->destroy.link);
        m_watches.removeAt(i);
        delete w;
        return;
    }
}

void OutputCapture::requestShot(const QString &path, std::function<void(bool)> done)
{
    m_shotPath = path;
    m_shotDone = std::move(done);
}

void OutputCapture::onCommit(Watch *watch, void *data)
{
    auto *event = static_cast<wlr_output_event_commit *>(data);
    if (!(event->state->committed & WLR_OUTPUT_STATE_BUFFER) || !event->state->buffer)
        return;

    // Only the first output paces the frame log.
    if (m_frames && !m_watches.isEmpty() && m_watches.first() == watch)
        m_frames->frameSwapped();

    if (m_shotPath.isEmpty() || m_watches.first() != watch)
        return;
    const QString path = m_shotPath;
    auto done = std::move(m_shotDone);
    m_shotPath.clear();
    m_shotDone = {};

    const QImage image = readBuffer(m_renderer, event->state->buffer);
    const bool ok = !image.isNull() && image.save(path);
    if (ok)
        std::printf("luna-compositor screenshot=%s\n", qPrintable(path));
    else
        std::fprintf(stderr, "luna-compositor: cannot write screenshot %s\n", qPrintable(path));
    std::fflush(stdout);
    if (done)
        done(ok);
}
