// LD_PRELOAD shim for promo recordings: wall-clock time reads as PROMO_CLOCK (epoch seconds) at process start, then runs normally.
// Monotonic clocks are untouched, so animations and timers behave.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>

static long shift_seconds(void) {
    static int ready;
    static long shift;
    if (!ready) {
        const char *target = getenv("PROMO_CLOCK");
        const char *base = getenv("PROMO_CLOCK_BASE");
        // PROMO_CLOCK_BASE (real epoch seconds when the session started) keeps every process on one shifted clock.
        if (target && base) shift = atol(target) - atol(base);
        ready = 1;
    }
    return shift;
}

int clock_gettime(clockid_t id, struct timespec *ts) {
    static int (*real)(clockid_t, struct timespec *);
    if (!real) real = dlsym(RTLD_NEXT, "clock_gettime");
    int r = real(id, ts);
    if (r == 0 && ts && (id == CLOCK_REALTIME || id == CLOCK_REALTIME_COARSE)) ts->tv_sec += shift_seconds();
    return r;
}

int gettimeofday(struct timeval *tv, void *tz) {
    static int (*real)(struct timeval *, void *);
    if (!real) real = dlsym(RTLD_NEXT, "gettimeofday");
    int r = real(tv, tz);
    if (r == 0 && tv) tv->tv_sec += shift_seconds();
    return r;
}

time_t time(time_t *out) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    if (out) *out = ts.tv_sec;
    return ts.tv_sec;
}
