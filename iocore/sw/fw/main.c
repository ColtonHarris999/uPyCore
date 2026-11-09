// The I/O core's production firmware: one loop that executes the hart's
// commands (fw/proto.h), moves UART and console bytes, runs the software
// timers, and keeps the state page current.
// Spec: upycore/docs/mpy_io_core.md (Firmware, Commands, State page).
#include "iocore.h"
#include "proto.h"

// ---- state page ----
static uint32_t seq;               // CMD words finished (PG_SEQ)
static uint32_t pin_in_last = 0xFFFFFFFFu;
static uint32_t uart0_last = 0xFFFFFFFFu;
static uint32_t ms_last;

// ---- UART0: 256-byte RX ring, 256-byte TX ring ----
#define RING 256
static uint8_t rx_ring[RING], tx_ring[RING];
static uint32_t rx_head, rx_tail, tx_head, tx_tail;   // free-running indices
static uint32_t con_mode;
static int uart0_open;
static uint32_t kbd_char = 0x103;           // 8 armed, 7:0 the character (Ctrl-C)

// ---- events ----
static uint32_t pin_irq_mask;               // pins with Pin.irq armed
static uint8_t pin_cnt[NPINS];
static uint32_t pin_flags;
static uint32_t uart_irq_mask, uart_ev, uart_rx_seen, uart_tx_seen;
static uint32_t uart_last_rx_us;
static uint32_t timer_notify;
static uint32_t od_mask;           // open-drain pins

static inline uint32_t rx_count(void) { return rx_head - rx_tail; }
static inline uint32_t tx_free(void) { return RING - (tx_head - tx_tail); }

// ---- software timers on the µs counter ----
static struct { uint32_t period, next, count; uint8_t on, periodic; } tmr[NTIMERS];

static void event(uint32_t bits) {
    while (BR_STATUS & (1u << 4)) { }      // EVT FIFO full (4 deep): brief
    BR_EVT = bits;
}

static void service(void);

static void page(uint32_t i, uint32_t v) { BR_UP(i) = v; }

// The next CMD word of a multi-word command (the loop keeps running).
static uint32_t cmd_next(void) {
    while (!(BR_STATUS & BR_ST_CMD)) service();
    seq++;
    return BR_CMD;
}

// A RSP word; the loop keeps running while RSP is full.
static void rsp(uint32_t w) {
    while (BR_STATUS & BR_ST_RSP_FULL) service();
    BR_RSP = w;
}

static void tx_put(uint8_t b) {
    while (tx_free() == 0) service();
    tx_ring[tx_head++ % RING] = b;
    uart_tx_seen = 1;
}

static void pin_init(uint32_t w) {
    uint32_t pin = w & 31, mode = (w >> 5) & 7, pull = (w >> 8) & 3, bit = 1u << pin;
    if (pin >= NPINS) return;
    if (w & (1u << 10)) { if (w & (1u << 11)) GPIO_SET = bit; else GPIO_CLR = bit; }
    GPIO_PU = (pull == 1) ? (GPIO_PU | bit) : (GPIO_PU & ~bit);
    GPIO_PD = (pull == 2) ? (GPIO_PD | bit) : (GPIO_PD & ~bit);
    // Open drain: driven only while the output is 0 (pin_write keeps OE in step).
    if (mode == 1 || (mode == 2 && !(GPIO_OUT & bit))) GPIO_OE = GPIO_OE | bit;
    else GPIO_OE = GPIO_OE & ~bit;
    od_mask = (mode == 2) ? (od_mask | bit) : (od_mask & ~bit);
}

static void command(uint32_t w) {
    uint32_t ch = w >> 24;
    switch (ch) {
    case CH_ECHO: rsp(w); break;
    case CH_EVT:  BR_EVT = w & 0xFFFF; break;
    case CH_PAGE: { uint32_t v = cmd_next(); page(w & 31, v); rsp(w); break; }
    case CH_DNRD: rsp(BR_DN(w & 7)); break;
    case CH_SYS:
        switch ((w >> 16) & 0xFF) {
        case SYS_OP_PING: rsp(PROTO_VERSION); break;
        case SYS_OP_FREQ: rsp(SYS_FREQ); break;
        default: break;
        }
        break;
    case CH_PIN_INIT: pin_init(w); break;
    case CH_PIN_WRITE: {
        uint32_t bit = 1u << (w & 15);
        if (w & (1u << 8)) GPIO_SET = bit; else GPIO_CLR = bit;
        if (od_mask & bit) GPIO_OE = (w & (1u << 8)) ? (GPIO_OE & ~bit) : (GPIO_OE | bit);
        break;
    }
    case CH_PIN_IRQ: {
        uint32_t pin = w & 15, edges = (w >> 8) & 3, bit = 1u << pin;
        uint32_t e = GPIO_EDGE & ~(3u << (2 * pin));
        GPIO_EDGE = e | (edges << (2 * pin));
        GPIO_STATUS = bit;
        pin_irq_mask = edges ? (pin_irq_mask | bit) : (pin_irq_mask & ~bit);
        pin_flags &= ~(3u << (2 * pin));
        page(PG_PIN_FLAGS, pin_flags);
        break;
    }
    case CH_KBD: kbd_char = w & 0x1FF; break;
    case CH_UART_IRQ: uart_irq_mask = w & 0xFFFF; break;
    case CH_PIN_TOGGLE: {
        uint32_t bit = 1u << (w & 15);
        GPIO_XOR = bit;
        if (od_mask & bit) GPIO_OE = (GPIO_OUT & bit) ? (GPIO_OE & ~bit) : (GPIO_OE | bit);
        break;
    }
    case CH_UART_INIT: {
        uint32_t baud = cmd_next();
        uint32_t div = (SYS_FREQ + baud / 2) / baud;
        UART_BAUD = div;
        uart0_open = 1;
        rsp(SYS_FREQ / div);
        break;
    }
    case CH_UART_TX1: case CH_UART_TX2: case CH_UART_TX3:
        for (uint32_t i = 0; i < ch - CH_UART_TX1 + 1; i++) tx_put((uint8_t)(w >> (8 * i)));
        break;
    case CH_UART_RX: {
        uint32_t n = w & 0xFF, k = rx_count();
        if (k > n) k = n;
        rsp(k);
        for (uint32_t i = 0; i < k; i += 3) {
            uint32_t v = 0;
            for (uint32_t j = 0; j < 3 && i + j < k; j++) v |= (uint32_t)rx_ring[rx_tail++ % RING] << (8 * j);
            rsp(v);
        }
        break;
    }
    case CH_UART_DEINIT: uart0_open = 0; break;
    case CH_TIMER_INIT: {
        uint32_t id = w & 3, period = cmd_next();
        tmr[id].period = period ? period : 1;
        tmr[id].next = TMR_US + tmr[id].period;
        tmr[id].periodic = (w >> 2) & 1;
        tmr[id].on = 1;
        timer_notify = (w & 8) ? (timer_notify | (1u << id)) : (timer_notify & ~(1u << id));
        break;
    }
    case CH_TIMER_DEINIT: tmr[w & 3].on = 0; break;
    default: break;
    }
}

// Everything the loop does between commands.
static void service(void) {
    // UART0 hardware FIFO into the RX ring (a full ring drops the byte, as
    // MicroPython's ring buffers do).
    uint32_t now = TMR_US;
    for (;;) {
        uint32_t d = UART_DATA;
        if (!(d & UART_RX_VALID)) break;
        uart_last_rx_us = now;
        uart_rx_seen = 1;
        // The console's armed interrupt character is the KBD event, not a byte.
        if (con_mode != 0 && (kbd_char & 0x100) && (uint8_t)d == (uint8_t)kbd_char) {
            event(EV_KBD);
            continue;
        }
        if (rx_count() < RING) rx_ring[rx_head++ % RING] = (uint8_t)d;
    }
    // Console: UART input to the hart's CON_RX, the hart's output to UART TX.
    if (con_mode == 1) {
        while (rx_count() && !(BR_STATUS & BR_ST_CONRX_FULL)) BR_CONRX = rx_ring[rx_tail++ % RING];
        for (;;) {
            if (tx_free() == 0) break;
            uint32_t c = BR_CON;
            if (!(c & (1u << 31))) break;
            tx_ring[tx_head++ % RING] = (uint8_t)c;
        }
    }
    // TX ring into the UART's hardware FIFO.
    while (tx_head != tx_tail && !(UART_STATUS & UART_ST_TXFULL)) UART_DATA = tx_ring[tx_tail++ % RING];
    // Software timers.
    for (int i = 0; i < NTIMERS; i++) {
        if (tmr[i].on && (int32_t)(now - tmr[i].next) >= 0) {
            tmr[i].count++;
            page(PG_TIMER0 + i, tmr[i].count);
            if (timer_notify & (1u << i)) event(EV_TIMER);
            if (tmr[i].periodic) tmr[i].next += tmr[i].period;
            else tmr[i].on = 0;
        }
    }
    // Pin edges (the GPIO block latches them, so a short pulse is not lost).
    uint32_t st = GPIO_STATUS & pin_irq_mask;
    if (st) {
        uint32_t lv = GPIO_IN;
        GPIO_STATUS = st;
        for (int p = 0; p < NPINS; p++) {
            if (!(st & (1u << p))) continue;
            pin_cnt[p]++;
            // The edge's direction: the level after it (rising leaves 1).
            pin_flags |= ((lv >> p) & 1 ? 1u : 2u) << (2 * p);
            page(PG_PIN_CNT + p / 4, pin_cnt[p & ~3] | (pin_cnt[(p & ~3) + 1] << 8) |
                 (pin_cnt[(p & ~3) + 2] << 16) | ((uint32_t)pin_cnt[(p & ~3) + 3] << 24));
        }
        page(PG_PIN_FLAGS, pin_flags);
        event(EV_PIN);
    }
    // UART0 triggers: RXIDLE after bytes and two character times quiet
    // (20 bit times); TXIDLE when everything queued has left the wire.
    if (uart_irq_mask) {
        uint32_t ev = 0;
        uint32_t idle_us = 20000000u / 115200u + 1;
        if (uart0_open && UART_BAUD) idle_us = (20u * UART_BAUD) / (SYS_FREQ / 1000000u) + 1;
        if ((uart_irq_mask & UIRQ_RXIDLE) && uart_rx_seen && now - uart_last_rx_us > idle_us) {
            uart_rx_seen = 0;
            uart_ev = (uart_ev & ~0xFFu) | ((uart_ev + 1) & 0xFFu);
            ev |= UIRQ_RXIDLE;
        }
        int tx_idle = tx_head == tx_tail && !(UART_STATUS & UART_ST_TXBUSY);
        if ((uart_irq_mask & UIRQ_TXIDLE) && uart_tx_seen && tx_idle) {
            uart_tx_seen = 0;
            uart_ev = (uart_ev & ~0xFF00u) | ((uart_ev + 0x100u) & 0xFF00u);
            ev |= UIRQ_TXIDLE;
        }
        if (ev) {
            uart_ev = (uart_ev & 0xFFFFu) | (ev << 16);
            page(PG_UART0_EV, uart_ev);
            event(EV_UART0);
        }
    } else uart_rx_seen = 0;
    // State page.
    uint32_t in = GPIO_IN;
    if (in != pin_in_last) { pin_in_last = in; page(PG_PIN_IN, in); }
    uint32_t u = rx_count() | (tx_free() << 16) |
                 ((tx_head != tx_tail || (UART_STATUS & UART_ST_TXBUSY)) ? (1u << 31) : 0);
    if (u != uart0_last) { uart0_last = u; page(PG_UART0, u); }
    uint32_t ms = TMR_MS;
    if (ms != ms_last) { ms_last = ms; page(PG_CYCLES, TMR_CYCLES); }
}

int main(void) {
    uint32_t hz = SYS_FREQ;
    TMR_DIV = hz / 1000000u - 1;
    con_mode = SYS_CON_MODE;
    // UART0 starts at 115200 8N1 (the console's rate, and machine.UART's
    // default), so bytes that arrive before machine.UART() are kept.
    UART_BAUD = (hz + 57600) / 115200;
    page(PG_VERSION, 0x494F0000u | PROTO_VERSION);
    for (;;) {
        if (BR_STATUS & BR_ST_CMD) {
            seq++;
            command(BR_CMD);
            page(PG_SEQ, seq);
        }
        service();
    }
}
