// The I/O core's production firmware: one event loop that executes the
// hart's commands (fw/proto.h) and keeps the state page current.
// Spec: upycore/docs/mpy_io_core.md (Firmware, Commands).
#include "iocore.h"
#include "proto.h"

static uint32_t cmd_next(void) {
    while (!(BR_STATUS & BR_ST_CMD)) { }
    return BR_CMD;
}

static void command(uint32_t w) {
    uint32_t ch = w >> 24;
    switch (ch) {
    case CH_ECHO:
        BR_RSP = w;
        break;
    case CH_EVT:
        BR_EVT = w & 0xFFFF;
        break;
    case CH_PAGE: {
        uint32_t v = cmd_next();
        BR_UP(w & 31) = v;
        BR_RSP = w;
        break;
    }
    case CH_DNRD:
        BR_RSP = BR_DN(w & 7);
        break;
    case CH_SYS:
        if (((w >> 16) & 0xFF) == SYS_PING) BR_RSP = PROTO_VERSION;
        break;
    default:
        break;
    }
}

int main(void) {
    BR_UP(PG_VERSION) = 0x494F0000u | PROTO_VERSION;
    for (;;) {
        if (BR_STATUS & BR_ST_CMD) command(BR_CMD);
    }
}
