/* opal-pointer: drive the cursor on one output from the docked phone's trackpad.
 * Reads commands on stdin, one per line:
 *   output NAME        bind to an output (absolute motion stays inside it)
 *   move DX DY         move by a delta in output pixels
 *   down BTN / up BTN  press or release (left, right, middle)
 *   click BTN          press and release
 *   scroll DX DY       scroll in pixels (two-finger drag)
 * Uses wlr-virtual-pointer v2. It only runs while Opal asks it to. */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <wayland-client.h>
#include "wlr-virtual-pointer-unstable-v1.h"

struct output { struct wl_output *wl; char name[64]; int width, height; struct output *next; };
static struct zwlr_virtual_pointer_manager_v1 *manager;
static struct wl_seat *seat;
static struct output *outputs;
static uint32_t manager_version;

static void out_geometry(void *d, struct wl_output *o, int32_t x, int32_t y, int32_t pw, int32_t ph, int32_t sp, const char *mk, const char *md, int32_t t) {
    (void)d; (void)o; (void)x; (void)y; (void)pw; (void)ph; (void)sp; (void)mk; (void)md; (void)t; }
static void out_mode(void *d, struct wl_output *o, uint32_t flags, int32_t w, int32_t h, int32_t r) {
    (void)o; (void)r; struct output *out = d; if (flags & WL_OUTPUT_MODE_CURRENT) { out->width = w; out->height = h; } }
static void out_done(void *d, struct wl_output *o) { (void)d; (void)o; }
static void out_scale(void *d, struct wl_output *o, int32_t s) { (void)d; (void)o; (void)s; }
static void out_name(void *d, struct wl_output *o, const char *name) { (void)o; struct output *out = d; snprintf(out->name, sizeof out->name, "%s", name); }
static void out_description(void *d, struct wl_output *o, const char *s) { (void)d; (void)o; (void)s; }
static const struct wl_output_listener output_listener = { out_geometry, out_mode, out_done, out_scale, out_name, out_description };

static void global(void *d, struct wl_registry *r, uint32_t id, const char *iface, uint32_t version) {
    (void)d;
    if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name)) {
        manager_version = version < 2 ? version : 2;
        manager = wl_registry_bind(r, id, &zwlr_virtual_pointer_manager_v1_interface, manager_version);
    } else if (!strcmp(iface, wl_seat_interface.name) && !seat) {
        seat = wl_registry_bind(r, id, &wl_seat_interface, 1);
    } else if (!strcmp(iface, wl_output_interface.name) && version >= 4) {
        struct output *out = calloc(1, sizeof *out);
        if (!out) return;
        out->wl = wl_registry_bind(r, id, &wl_output_interface, 4);
        wl_output_add_listener(out->wl, &output_listener, out);
        out->next = outputs; outputs = out;
    }
}
static void global_remove(void *d, struct wl_registry *r, uint32_t id) { (void)d; (void)r; (void)id; }
static const struct wl_registry_listener registry_listener = { global, global_remove };

static uint32_t now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (uint32_t)(t.tv_sec * 1000 + t.tv_nsec / 1000000); }
static uint32_t button_code(const char *name) { return !strcmp(name, "right") ? 0x111 : !strcmp(name, "middle") ? 0x112 : 0x110; }

int main(void) {
    struct wl_display *display = wl_display_connect(NULL);
    if (!display) { fprintf(stderr, "opal-pointer: no Wayland display\n"); return 1; }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display); wl_display_roundtrip(display);
    if (!manager) { fprintf(stderr, "opal-pointer: the compositor has no virtual pointer support\n"); return 2; }
    struct zwlr_virtual_pointer_v1 *pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, seat);
    struct output *bound = NULL;
    double x = 0, y = 0;
    char line[256];
    printf("ready\n"); fflush(stdout);
    while (fgets(line, sizeof line, stdin)) {
        char cmd[16] = {0}, arg[64] = {0};
        double a = 0, b = 0;
        if (sscanf(line, "%15s", cmd) != 1) continue;
        uint32_t t = now();
        if (!strcmp(cmd, "output") && sscanf(line, "%*s %63s", arg) == 1) {
            for (struct output *o = outputs; o; o = o->next) if (!strcmp(o->name, arg)) bound = o;
            if (bound && manager_version >= 2) {
                zwlr_virtual_pointer_v1_destroy(pointer);
                pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer_with_output(manager, seat, bound->wl);
                x = bound->width / 2.0; y = bound->height / 2.0;
                zwlr_virtual_pointer_v1_motion_absolute(pointer, t, (uint32_t)x, (uint32_t)y, bound->width, bound->height);
                zwlr_virtual_pointer_v1_frame(pointer);
            }
            printf(bound ? "bound %s\n" : "unknown %s\n", arg); fflush(stdout);
        } else if (!strcmp(cmd, "move") && sscanf(line, "%*s %lf %lf", &a, &b) == 2) {
            if (bound && manager_version >= 2 && bound->width > 0) {
                x += a; y += b;
                if (x < 0) x = 0;
                if (y < 0) y = 0;
                if (x > bound->width - 1) x = bound->width - 1;
                if (y > bound->height - 1) y = bound->height - 1;
                zwlr_virtual_pointer_v1_motion_absolute(pointer, t, (uint32_t)x, (uint32_t)y, bound->width, bound->height);
            } else zwlr_virtual_pointer_v1_motion(pointer, t, wl_fixed_from_double(a), wl_fixed_from_double(b));
            zwlr_virtual_pointer_v1_frame(pointer);
        } else if ((!strcmp(cmd, "down") || !strcmp(cmd, "up") || !strcmp(cmd, "click")) && sscanf(line, "%*s %63s", arg) == 1) {
            uint32_t code = button_code(arg);
            if (strcmp(cmd, "up")) { zwlr_virtual_pointer_v1_button(pointer, t, code, WL_POINTER_BUTTON_STATE_PRESSED); zwlr_virtual_pointer_v1_frame(pointer); }
            if (strcmp(cmd, "down")) { zwlr_virtual_pointer_v1_button(pointer, t, code, WL_POINTER_BUTTON_STATE_RELEASED); zwlr_virtual_pointer_v1_frame(pointer); }
        } else if (!strcmp(cmd, "scroll") && sscanf(line, "%*s %lf %lf", &a, &b) == 2) {
            zwlr_virtual_pointer_v1_axis_source(pointer, WL_POINTER_AXIS_SOURCE_FINGER);
            if (b != 0) zwlr_virtual_pointer_v1_axis(pointer, t, WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_double(b));
            if (a != 0) zwlr_virtual_pointer_v1_axis(pointer, t, WL_POINTER_AXIS_HORIZONTAL_SCROLL, wl_fixed_from_double(a));
            zwlr_virtual_pointer_v1_frame(pointer);
        }
        wl_display_flush(display);
        if (wl_display_dispatch_pending(display) < 0) break;
    }
    zwlr_virtual_pointer_v1_destroy(pointer);
    wl_display_flush(display);
    wl_display_disconnect(display);
    return 0;
}
