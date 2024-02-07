#include <string.h>
#include <stdlib.h>
#include <wchar.h>

#include "libcaramelchatwl.h"

struct wl_seat* wlSeat = NULL;
struct zwp_text_input_manager_v3* textInputManager = NULL;
struct zwp_text_input_v3* textInput = NULL;

void (*javaPreedit)(wchar_t*);
void (*javaPreeditNull)();
void (*javaDone)(wchar_t*);
bool (*javaRect)(float*);

void setCallback(void (*callPreedit)(wchar_t*), void (*callPreeditNull), void (*callDone)(wchar_t*), bool (*callRect)(float*)) {
    javaPreedit = callPreedit;
    javaPreeditNull = callPreeditNull;
    javaDone = callDone;
    javaRect = callRect;
}

wchar_t* convert(const char* text) {
    size_t len = (strlen(text) + 1);

    wchar_t* wideStr = (wchar_t*) malloc(len * sizeof(wchar_t));
    if (wideStr == NULL) {
        CIError("Memory allocation failed.");
        return NULL;
    }

    if (mbstowcs(wideStr, text, len) == -1) {
        CIError("Conversion failed.");
        free(wideStr);
        return NULL;
    }

    return wideStr;
}

// =================================== (Registry)

int mathMin(int a, int b) {
    return (a < b) ? a : b;
}

static void _registryHandleGlobal(void* data, struct wl_registry* registry, uint32_t name, const char* interface, uint32_t version) {
    CIDebug("Wayland Registery Listener (Add): %s", interface);
    if (strcmp(interface, "wl_seat") == 0) {
        wlSeat = wl_registry_bind(registry, name, &wl_seat_interface, mathMin(4, version));
    } else if (strcmp(interface, "zwp_text_input_manager_v3") == 0) {
        textInputManager = wl_registry_bind(registry, name, &zwp_text_input_manager_v3_interface, 1);
    }
}

static void _registryHandleGlobalRemove(void* data, struct wl_registry* registry, uint32_t name) {
    if (wlSeat) {
        wl_seat_destroy(wlSeat);
    }

    if (textInput) {
        zwp_text_input_v3_destroy(textInput);
    }
    if (textInputManager) {
        zwp_text_input_manager_v3_destroy(textInputManager);
    }
}

static const struct wl_registry_listener _registryListener = {
    _registryHandleGlobal,
    _registryHandleGlobalRemove
};

// =================================== (IME)

bool enableIme = false;

static void _updateRect() {
    float* rect = malloc(sizeof(float) * 4);
    if (javaRect(rect)) {
        free(rect);
        return;
    }

    zwp_text_input_v3_set_cursor_rectangle(textInput, 0, (int32_t) rect[1], (int32_t) rect[0], 0);
    free(rect);
}

static void _textInputEnter(void* data, struct zwp_text_input_v3* textInput, struct wl_surface* surface) {
    CIDebug("IME Enter");
    if (enableIme) {
        zwp_text_input_v3_enable(textInput);
        _updateRect();
        zwp_text_input_v3_commit(textInput);
    }
}

static void _textInputLeave(void* data, struct zwp_text_input_v3* textInput, struct wl_surface* surface) {
    zwp_text_input_v3_disable(textInput);
    zwp_text_input_v3_commit(textInput);
}

static void _textInputPreeditString(void* data, struct zwp_text_input_v3* textInput, const char* text, int32_t cursorBegin, int32_t cursorEnd) {
    CIDebug("IME Preedit: \"%s\"", text);

    if (text == NULL) {
        javaPreeditNull();
        return;
    }

    wchar_t* converted = convert(text);
    if (converted != NULL) {
        javaPreedit(converted);
        free(converted);
    }
}

static void _textInputCommitString(void* data, struct zwp_text_input_v3* textInput, const char* text) {
    if (text == NULL) {
        return;
    }

    CIDebug("IME CommitString: \"%s\"", text);

    wchar_t* converted = convert(text);
    if (converted != NULL) {
        javaDone(converted);
        free(converted);
    }

    // Update Rect
    _updateRect();
    zwp_text_input_v3_commit(textInput);
}

static void _textInputDeleteSurroundingText(void* data, struct zwp_text_input_v3* textInput, uint32_t beforeLength, uint32_t afterLength) {
    CIDebug("IME Delete: %d %d", beforeLength, afterLength);
}

static void _textInputDone(void* data, struct zwp_text_input_v3* textInput, uint32_t serial) {
    CIDebug("IME Done");
}

static const struct zwp_text_input_v3_listener _textInputListener = {
    _textInputEnter,
    _textInputLeave,
    _textInputPreeditString,
    _textInputCommitString,
    _textInputDeleteSurroundingText,
    _textInputDone
};

// ===================================

void initialize(
    struct wl_display* display,
    void (*callPreedit)(wchar_t*),
    void (*callPreeditNull),
    void (*callDone)(wchar_t*),
    bool (*callRect)(float*),
    LogFunction log,
    LogFunction error,
    LogFunction debug
) {
    initLogPointer(log, error, debug); // TODO Rewrite Logger

    struct wl_registry* _registry = wl_display_get_registry(display);
    wl_registry_add_listener(_registry, &_registryListener, NULL);
    wl_display_dispatch(display);

    if (!wlSeat) {
        CIError("Critical Error!!!");
        return;
    }

    if (!textInputManager) {
        CIError("This system is using an unsupported Wayland...");
        return;
    }

    setCallback(callPreedit, callPreeditNull, callDone, callRect);
    textInput = zwp_text_input_manager_v3_get_text_input(textInputManager, wlSeat);
    zwp_text_input_v3_add_listener(textInput, &_textInputListener, display);
}

void setFocus(bool flag) {
    // Change state
    if (flag) {
        enableIme = true;
        zwp_text_input_v3_enable(textInput);
        _updateRect();
    } else {
        enableIme = false;
        zwp_text_input_v3_disable(textInput);
    }

    // Commit
    zwp_text_input_v3_commit(textInput);
}
