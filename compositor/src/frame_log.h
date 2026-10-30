#pragma once

#include <QElapsedTimer>
#include <QString>
#include <vector>

// Records the time between swapped frames and writes them as JSON.
class FrameLog
{
public:
    explicit FrameLog(double budgetMs);

    // Call once for every frame the window swaps.
    void frameSwapped();

    // Writes the intervals and summary statistics to path.
    bool write(const QString &path, const QString &backend) const;

private:
    QElapsedTimer m_clock;
    std::vector<qint64> m_stampsNs;
    double m_budgetMs;
};
