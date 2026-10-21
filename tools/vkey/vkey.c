// Test keyboard for nested sessions: reads commands from stdin and plays them through zwp-virtual-keyboard with a real US keymap.
#define _GNU_SOURCE
// Commands: "tap KEYSYM", "down KEYSYM", "up KEYSYM", "sleep MS". KEYSYM is an XKB name such as XF86PowerOff or Escape.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>
#include "virtual-keyboard-unstable-v1-client-protocol.h"

static struct wl_seat* seat;
static struct zwp_virtual_keyboard_manager_v1* manager;
static struct xkb_keymap* keymap;

static void global(void* data, struct wl_registry* registry, uint32_t name, const char* interface, uint32_t version) {
    if (!strcmp(interface, wl_seat_interface.name))
        seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
    else if (!strcmp(interface, zwp_virtual_keyboard_manager_v1_interface.name))
        manager = wl_registry_bind(registry, name, &zwp_virtual_keyboard_manager_v1_interface, 1);
}
static void global_remove(void* data, struct wl_registry* registry, uint32_t name) {}
static const struct wl_registry_listener listener = {global, global_remove};

static uint32_t now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

// The evdev code of the first key that produces this keysym on level one.
static int code_for(const char* name) {
    xkb_keysym_t sym = xkb_keysym_from_name(name, XKB_KEYSYM_CASE_INSENSITIVE);
    if (sym == XKB_KEY_NoSymbol) return -1;
    for (xkb_keycode_t k = xkb_keymap_min_keycode(keymap); k <= xkb_keymap_max_keycode(keymap); k++) {
        const xkb_keysym_t* syms;
        if (xkb_keymap_key_get_syms_by_level(keymap, k, 0, 0, &syms) > 0 && syms[0] == sym) return (int)k - 8;
    }
    return -1;
}

int main(void) {
    struct wl_display* display = wl_display_connect(NULL);
    if (!display) { fprintf(stderr, "no display\n"); return 1; }
    struct wl_registry* registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &listener, NULL);
    wl_display_roundtrip(display);
    if (!manager || !seat) { fprintf(stderr, "no virtual keyboard manager\n"); return 1; }
    struct xkb_context* context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    struct xkb_rule_names names = {.rules = "evdev", .model = "pc105", .layout = "us"};
    keymap = xkb_keymap_new_from_names(context, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    if (!keymap) { fprintf(stderr, "no keymap\n"); return 1; }
    char* text = xkb_keymap_get_as_string(keymap, XKB_KEYMAP_FORMAT_TEXT_V1);
    size_t size = strlen(text) + 1;
    int fd = memfd_create("vkey-keymap", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, size) < 0) return 1;
    char* map = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    memcpy(map, text, size);
    munmap(map, size);
    struct zwp_virtual_keyboard_v1* keyboard = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(manager, seat);
    zwp_virtual_keyboard_v1_keymap(keyboard, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, fd, size);
    wl_display_roundtrip(display);
    char line[256], name[128];
    int ms;
    while (fgets(line, sizeof line, stdin)) {
        int state = -1, tap = 0;
        if (sscanf(line, "tap %127s", name) == 1) tap = 1;
        else if (sscanf(line, "down %127s", name) == 1) state = WL_KEYBOARD_KEY_STATE_PRESSED;
        else if (sscanf(line, "up %127s", name) == 1) state = WL_KEYBOARD_KEY_STATE_RELEASED;
        else if (sscanf(line, "sleep %d", &ms) == 1) { wl_display_flush(display); usleep(ms * 1000); continue; }
        else continue;
        int code = code_for(name);
        if (code < 0) { fprintf(stderr, "unknown key %s\n", name); continue; }
        if (tap || state == WL_KEYBOARD_KEY_STATE_PRESSED) zwp_virtual_keyboard_v1_key(keyboard, now_ms(), code, WL_KEYBOARD_KEY_STATE_PRESSED);
        if (tap) { wl_display_roundtrip(display); usleep(40000); }
        if (tap || state == WL_KEYBOARD_KEY_STATE_RELEASED) zwp_virtual_keyboard_v1_key(keyboard, now_ms(), code, WL_KEYBOARD_KEY_STATE_RELEASED);
        wl_display_roundtrip(display);
    }
    zwp_virtual_keyboard_v1_destroy(keyboard);
    wl_display_roundtrip(display);
    return 0;
}
