// Coprocessor registers (upycore/docs/mpy_coproc.md, Mailbox registers)
// and the mailbox message format (Messages).
#pragma once
#include <stdint.h>

struct cmb {
    uint32_t tx;        // 0x00 push a word to the hart
    uint32_t rx;        // 0x04 pop a word from the hart
    uint32_t status;    // 0x08
    uint32_t kbd;       // 0x0C ring the hart's KBD source
    uint32_t irqen;     // 0x10
    uint32_t cycles;    // 0x14
    uint32_t debug;     // 0x18 simulation log byte
};

#define CMB ((volatile struct cmb *)0x80000000)
#define SHARED ((volatile uint32_t *)0x80004000)

#define CMB_ST_RX_LEVEL(s) ((s) & 0x1f)
#define CMB_ST_TX_FULL     (1u << 16)
#define CMB_ST_RX_ANY      (1u << 17)
#define CMB_ST_TX_OVR      (1u << 18)

#define MB_CH(w)       ((w) >> 24)
#define MB_PAYLOAD(w)  ((w) & 0xffffffu)
#define MB_WORD(ch, p) (((uint32_t)(ch) << 24) | ((p) & 0xffffffu))

enum { CH_CON = 0x00, CH_CTRL = 0x01, CH_ECHO = 0x02, CH_COPY = 0x03 };
enum { CTRL_KBD = 0x01, CTRL_KBD_TEST = 0x02, CTRL_STATE = 0x80 };

#define STATE_CONFIGURED (1u << 0)
#define STATE_SUSPENDED  (1u << 1)
#define STATE_DTR        (1u << 2)
