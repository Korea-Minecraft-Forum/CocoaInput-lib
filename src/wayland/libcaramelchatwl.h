#include <wayland-client-core.h>
#include <stdio.h>
#include <stdbool.h>

#include "text-input-unstable-v3-client-protocol.h"
#include "logger.h"

void initialize(
    struct wl_display *display,
    void (*callPreedit)(wchar_t*),
    void (*callPreeditNull),
    void (*callDone)(wchar_t*),
    bool (*callRect)(float*),
    LogFunction log,
    LogFunction error,
    LogFunction debug
);

void setFocus(bool flag);
