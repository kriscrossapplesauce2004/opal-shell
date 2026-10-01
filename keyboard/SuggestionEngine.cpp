#include "SuggestionEngine.h"
#include <QFile>
#include <QRegularExpression>
#include <QSet>

SuggestionEngine::SuggestionEngine(QObject *parent) : QObject(parent) {
    words = QStringLiteral(
        "the be to of and a in that have i it for not on with he as you do at this but his by from they we say her she or an will my one all would there their what so up out if about who get which go me when make can like time no just him know take people into year your good some could them see other than then now look only come its over think also back after use two how our work first well way even new want because these give day most us is are was were been being am hello thanks thank please yes okay sure right really maybe today tomorrow tonight love great nice cool awesome keyboard phone tablet desktop screen window app text message search send done next enter terminal email url number home where why how hey hi morning night more less much many very little big small fast slow open close start stop help try use using make made does did done works working worked better best new local private secure material aurora borealis opal linux wayland game gamepad controller emoji clipboard edit select copy paste undo redo job join jump joke joy journey january javascript journal jelly juice jacket judge keep kind knew know last later learn leave left life light long look lot made main many may mean might move must need never next night nothing now old once only open own part place play point put read real really right run same say school should show small something still such system tell than thing think three through too under very want water well while world write year young"
    ).split(QLatin1Char(' '), Qt::SkipEmptyParts);
    for (const auto &path : {QStringLiteral("/usr/share/dict/words"), QStringLiteral("/usr/share/dict/american-english")}) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) continue;
        QSet<QString> seen;
        for (const auto &word : words) seen.insert(word);
        while (!file.atEnd() && words.size() < 12000) {
            const auto word = QString::fromUtf8(file.readLine()).trimmed().toLower();
            if (word.size() < 2 || word.size() > 24 || !word.contains(QRegularExpression(QStringLiteral("^[a-z][a-z'-]*$"))) || seen.contains(word)) continue;
            seen.insert(word); words.append(word);
        }
        break;
    }
}

void SuggestionEngine::updateEditorContext(const QString &text, int cursorCharacters, bool sensitive, int purpose) {
    const auto bounded = qBound(0, cursorCharacters, text.size());
    updateContext(text, text.left(bounded).toUtf8().size(), sensitive, purpose);
}

void SuggestionEngine::noteAccepted(const QString &word) {
    const auto normalized = word.trimmed().toLower();
    if (normalized.isEmpty() || normalized.size() > 32) return;
    accepted[normalized] = qMin(accepted.value(normalized) + 1, 1000);
}

QString SuggestionEngine::previousWord(const QString &text) {
    const auto parts = text.toLower().split(QRegularExpression(QStringLiteral("[^a-z']+")), Qt::SkipEmptyParts);
    return parts.isEmpty() ? QString() : parts.last();
}

int SuggestionEngine::distanceAtMostOne(const QString &left, const QString &right) {
    if (qAbs(left.size() - right.size()) > 1) return 2;
    if (left.size() == right.size()) {
        int first = -1, second = -1;
        for (int index = 0; index < left.size(); ++index) {
            if (left[index] == right[index]) continue;
            if (first < 0) first = index;
            else if (second < 0) second = index;
            else { first = -2; break; }
        }
        if (first >= 0 && second == first + 1 && left[first] == right[second] && left[second] == right[first]) return 1;
    }
    int i = 0, j = 0, edits = 0;
    while (i < left.size() && j < right.size()) {
        if (left[i] == right[j]) { ++i; ++j; continue; }
        if (++edits > 1) return 2;
        if (left.size() > right.size()) ++i;
        else if (right.size() > left.size()) ++j;
        else { ++i; ++j; }
    }
    if (i < left.size() || j < right.size()) ++edits;
    return edits;
}

void SuggestionEngine::updateContext(const QString &text, int cursorByte, bool sensitive, int purpose) {
    QString nextPrefix;
    int nextPrefixBytes = 0;
    QStringList next;
    if (!sensitive && purpose != 8 && purpose != 12) {
        const auto bytes = text.toUtf8();
        const auto bounded = qBound(0, cursorByte, bytes.size());
        const auto before = QString::fromUtf8(bytes.left(bounded));
        int start = before.size();
        while (start > 0 && (before[start - 1].isLetter() || before[start - 1] == QLatin1Char('\''))) --start;
        nextPrefix = before.mid(start).toLower();
        nextPrefixBytes = nextPrefix.toUtf8().size();
        if (!nextPrefix.isEmpty()) {
            QStringList matches;
            for (const auto &word : words) {
                if (word == nextPrefix || !word.startsWith(nextPrefix)) continue;
                matches.append(word);
                if (matches.size() == 24) break;
            }
            std::stable_sort(matches.begin(), matches.end(), [this](const QString &left, const QString &right) { return accepted.value(left) > accepted.value(right); });
            next = matches.mid(0, 3);
            if (next.size() < 3 && nextPrefix.size() >= 3) {
                for (const auto &word : words) {
                    if (next.contains(word) || qAbs(word.size() - nextPrefix.size()) > 1 || word.front() != nextPrefix.front()) continue;
                    if (distanceAtMostOne(nextPrefix, word) <= 1) next.append(word);
                    if (next.size() == 3) break;
                }
            }
        } else {
            const auto previous = previousWord(before);
            static const QHash<QString, QStringList> follow = {
                {"thank", {"you"}}, {"how", {"are", "do", "can"}}, {"are", {"you", "we"}},
                {"i", {"am", "have", "think"}}, {"you", {"are", "can", "have"}}, {"good", {"morning", "night", "luck"}},
                {"see", {"you", "the"}}, {"talk", {"to", "about"}}, {"way", {"to", "more"}}
            };
            next = previous.isEmpty() ? QStringList{QStringLiteral("I"), QStringLiteral("the"), QStringLiteral("you")} : follow.value(previous).mid(0, 3);
        }
    }
    if (next == candidates && nextPrefix == prefix && nextPrefixBytes == prefixBytes) return;
    candidates = next; prefix = nextPrefix; prefixBytes = nextPrefixBytes; emit changed();
}
