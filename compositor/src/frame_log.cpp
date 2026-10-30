#include "frame_log.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <algorithm>
#include <cmath>
#include <cstddef>

namespace {

// Returns the value at percentile p, with linear interpolation.
double percentile(std::vector<double> sorted, double p)
{
    if (sorted.empty())
        return 0.0;
    const double rank = (p / 100.0) * static_cast<double>(sorted.size() - 1);
    const auto low = static_cast<std::size_t>(std::floor(rank));
    const std::size_t high = std::min(low + 1, sorted.size() - 1);
    return sorted[low] + (sorted[high] - sorted[low]) * (rank - static_cast<double>(low));
}

}

FrameLog::FrameLog(double budgetMs)
    : m_budgetMs(budgetMs)
{
    m_clock.start();
    m_stampsNs.reserve(4096);
}

void FrameLog::frameSwapped()
{
    m_stampsNs.push_back(m_clock.nsecsElapsed());
}

bool FrameLog::write(const QString &path, const QString &backend) const
{
    std::vector<double> intervals;
    intervals.reserve(m_stampsNs.size());
    for (std::size_t i = 1; i < m_stampsNs.size(); ++i)
        intervals.push_back(static_cast<double>(m_stampsNs[i] - m_stampsNs[i - 1]) / 1.0e6);

    QJsonObject root;
    root[QStringLiteral("schema")] = QStringLiteral("luna-frames-v1");
    root[QStringLiteral("backend")] = backend;
    root[QStringLiteral("budget_ms")] = m_budgetMs;
    root[QStringLiteral("swaps")] = static_cast<qint64>(m_stampsNs.size());
    root[QStringLiteral("frames")] = static_cast<qint64>(intervals.size());

    if (!intervals.empty()) {
        std::vector<double> sorted = intervals;
        std::sort(sorted.begin(), sorted.end());
        const auto over = std::count_if(intervals.begin(), intervals.end(),
                                        [this](double v) { return v > m_budgetMs; });
        root[QStringLiteral("median_ms")] = percentile(sorted, 50.0);
        root[QStringLiteral("p95_ms")] = percentile(sorted, 95.0);
        root[QStringLiteral("p99_ms")] = percentile(sorted, 99.0);
        root[QStringLiteral("max_ms")] = sorted.back();
        root[QStringLiteral("over_budget_pct")] =
            100.0 * static_cast<double>(over) / static_cast<double>(intervals.size());
    }

    QJsonArray list;
    for (double value : intervals)
        list.append(std::round(value * 1000.0) / 1000.0);
    root[QStringLiteral("intervals_ms")] = list;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    return true;
}
