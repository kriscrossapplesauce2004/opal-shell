#pragma once
#include <QByteArray>
#include <QString>
#include <xkbcommon/xkbcommon.h>
#include <optional>
#include <QHash>

class Keymap {
public:
    struct Stroke { uint32_t code; uint32_t modifiers; };
    Keymap();
    ~Keymap();
    Keymap(const Keymap&) = delete;
    Keymap& operator=(const Keymap&) = delete;
    bool reset(uint32_t unicode = 0);
    QByteArray bytes() const;
    std::optional<Stroke> character(uint32_t unicode) const;
    uint32_t modifiers(bool control, bool alt, bool shift) const;
private:
    void rebuildLookup();
    xkb_context *context = nullptr;
    xkb_keymap *map = nullptr;
    QHash<uint32_t, Stroke> lookup;
    uint32_t controlMask = 0;
    uint32_t altMask = 0;
    uint32_t shiftMask = 0;
};
