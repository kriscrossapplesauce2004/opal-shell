#include "Keymap.h"
#include <cstdlib>
#include <xkbcommon/xkbcommon-names.h>

Keymap::Keymap() : context(xkb_context_new(XKB_CONTEXT_NO_FLAGS)) { reset(); }
Keymap::~Keymap() { if (map) xkb_keymap_unref(map); if (context) xkb_context_unref(context); }
bool Keymap::reset(uint32_t unicode) {
    if (!context) return false;
    const auto extra = unicode ? QString(" key <I255> { [ U%1 ] }; ").arg(unicode, 4, 16, QLatin1Char('0')) : QString();
    const auto source = QString("xkb_keymap { xkb_keycodes { include \"evdev+aliases(qwerty)\" }; xkb_types { include \"complete\" }; xkb_compatibility { include \"complete\" }; xkb_symbols { include \"pc+us\" %1 }; };").arg(extra).toUtf8();
    auto *next = xkb_keymap_new_from_string(context, source.constData(), XKB_KEYMAP_FORMAT_TEXT_V1, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!next) return false;
    if (map) xkb_keymap_unref(map);
    map = next;
    rebuildLookup();
    return true;
}
QByteArray Keymap::bytes() const {
    if (!map) return {};
    char *text = xkb_keymap_get_as_string(map, XKB_KEYMAP_FORMAT_TEXT_V1);
    if (!text) return {};
    QByteArray result(text); result.append('\0'); free(text); return result;
}
uint32_t Keymap::modifiers(bool control, bool alt, bool shift) const {
    return (control ? controlMask : 0) | (alt ? altMask : 0) | (shift ? shiftMask : 0);
}
std::optional<Keymap::Stroke> Keymap::character(uint32_t unicode) const {
    const auto found = lookup.constFind(unicode);
    return found == lookup.cend() ? std::optional<Stroke>{} : std::optional<Stroke>{found.value()};
}
void Keymap::rebuildLookup() {
    lookup.clear(); controlMask = 0; altMask = 0; shiftMask = 0;
    if (!map) return;
    const auto maskFor = [this](const char *name) {
        const auto index = xkb_keymap_mod_get_index(map, name);
        return index != XKB_MOD_INVALID && index < 32 ? 1u << index : 0u;
    };
    controlMask = maskFor(XKB_MOD_NAME_CTRL); altMask = maskFor(XKB_MOD_NAME_ALT); shiftMask = maskFor(XKB_MOD_NAME_SHIFT);
    auto *state = xkb_state_new(map);
    if (!state) return;
    for (bool shifted : {false, true}) {
        const auto mask = shifted ? shiftMask : 0;
        xkb_state_update_mask(state, mask, 0, 0, 0, 0, 0);
        for (auto code = xkb_keymap_min_keycode(map); code <= xkb_keymap_max_keycode(map); ++code) {
            const auto unicode = xkb_state_key_get_utf32(state, code);
            if (code >= 8 && unicode && !lookup.contains(unicode)) lookup.insert(unicode, Stroke{code - 8, mask});
        }
    }
    xkb_state_unref(state);
}
