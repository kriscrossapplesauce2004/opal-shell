// Test pointer for nested sessions: reads commands from stdin and plays them through wlr-virtual-pointer.
// Commands: "move X Y W H" (absolute, in a W×H extent), "glide X Y W H STEPS" (from the last point), "down", "up", "sleep MS".
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

#define BTN_LEFT 0x110

static struct wl_seat* seat;
static struct zwlr_virtual_pointer_manager_v1* manager;

static void global(void* data, struct wl_registry* registry, uint32_t name, const char* interface, uint32_t version) {
    if (!strcmp(interface, wl_seat_interface.name))
        seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
    else if (!strcmp(interface, zwlr_virtual_pointer_manager_v1_interface.name))
        manager = wl_registry_bind(registry, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
}
static void global_remove(void* data, struct wl_registry* registry, uint32_t name) {}
static const struct wl_registry_listener listener = {global, global_remove};

static uint32_t now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

int main(void) {
    struct wl_display* display = wl_display_connect(NULL);
    if (!display) { fprintf(stderr, "no display\n"); return 1; }
    struct wl_registry* registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &listener, NULL);
    wl_display_roundtrip(display);
    if (!manager) { fprintf(stderr, "no virtual pointer manager\n"); return 1; }
    struct zwlr_virtual_pointer_v1* pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, seat);
    char line[256];
    double lx = 0, ly = 0;
    while (fgets(line, sizeof line, stdin)) {
        double x, y, w, h; int steps, ms;
        if (sscanf(line, "move %lf %lf %lf %lf", &x, &y, &w, &h) == 4) {
            zwlr_virtual_pointer_v1_motion_absolute(pointer, now_ms(), (uint32_t)x, (uint32_t)y, (uint32_t)w, (uint32_t)h);
            zwlr_virtual_pointer_v1_frame(pointer);
            lx = x; ly = y;
        } else if (sscanf(line, "glide %lf %lf %lf %lf %d", &x, &y, &w, &h, &steps) == 5) {
            for (int i = 1; i <= steps; i++) {
                double px = lx + (x - lx) * i / steps, py = ly + (y - ly) * i / steps;
                zwlr_virtual_pointer_v1_motion_absolute(pointer, now_ms(), (uint32_t)px, (uint32_t)py, (uint32_t)w, (uint32_t)h);
                zwlr_virtual_pointer_v1_frame(pointer);
                wl_display_flush(display);
                usleep(12000);
            }
            lx = x; ly = y;
        } else if (!strncmp(line, "down", 4) || !strncmp(line, "up", 2)) {
            zwlr_virtual_pointer_v1_button(pointer, now_ms(), BTN_LEFT, line[0] == 'd' ? WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED);
            zwlr_virtual_pointer_v1_frame(pointer);
        } else if (sscanf(line, "sleep %d", &ms) == 1) {
            wl_display_flush(display);
            usleep(ms * 1000);
        }
        wl_display_roundtrip(display);
    }
    zwlr_virtual_pointer_v1_destroy(pointer);
    wl_display_roundtrip(display);
    return 0;
}
