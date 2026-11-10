// The I/O core's production firmware: one loop that executes the hart's
// commands (fw/proto.h), moves UART and console bytes, runs the software
// timers, and keeps the state page current.
// Spec: upycore/docs/mpy_io_core.md (Firmware, Commands, State page).
#include "iocore.h"
#include "proto.h"
#include "tusb.h"

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
static uint32_t con_prev;           // the console's last byte out (cooking)
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

static void service(void);
static uint32_t cmd_next(void);
static void rsp(uint32_t w);

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

// The chip's unique id (machine.unique_id): a constant of this build.
#define UID_HI 0x75507943u   // "uPyC"
#define UID_LO 0x494F0001u

// SPI: n bytes out and in, three to a word each way.
static void spi_xfer(uint32_t w) {
    uint32_t n = w & 0xFF, want = (w >> 8) & 1, out = 0, in_w = 0, nin = 0, sent = 0, got = 0;
    uint32_t have = 0;                     // the bytes of `out` not yet sent
    while (got < n) {
        if (sent < n && have == 0) { out = cmd_next(); have = 3; }
        if (sent < n && (SPI_STATUS & 31) < 8) {
            SPI_DATA = (out >> (8 * (sent % 3))) & 0xFF;
            sent++;
            have--;
        }
        uint32_t d = SPI_DATA;
        if (d & (1u << 31)) {
            in_w |= (d & 0xFF) << (8 * nin);
            nin++;
            got++;
            if (nin == 3 || got == n) {
                if (want) rsp(in_w);
                in_w = 0;
                nin = 0;
            }
        }
    }
}

// I2C: one transfer on the epic branch's command controller.
#define I2C_START 1
#define I2C_STOP  2
#define I2C_WRITE 3
#define I2C_READ  4
static uint32_t i2c_cmd(uint32_t c) {
    I2C_CMDR = c;
    uint32_t st;
    while ((st = I2C_STATUS) & 1) service();
    return st;
}

static void i2c_xfer(uint32_t w) {
    uint32_t addr = w & 0x7F, rd = (w >> 7) & 1, n = (w >> 8) & 0xFF, words[86];
    int32_t status = 0;
    uint32_t nw = (n + 2) / 3;
    if (!rd) for (uint32_t i = 0; i < nw; i++) words[i] = cmd_next();
    if (w & (1u << 16)) {
        uint32_t st = i2c_cmd(I2C_START);
        if (st & 4) status = -110;
    }
    if (status == 0) {
        uint32_t st = i2c_cmd(I2C_WRITE | (((addr << 1) | rd) << 8));
        if (st & 4) status = -110;
        else if (st & 2) status = -19;
    }
    uint32_t acked = 0;
    for (uint32_t i = 0; i < n && status == 0; i++) {
        if (rd) {
            uint32_t last = (i + 1 == n) && (w & (1u << 18));
            uint32_t st = i2c_cmd(I2C_READ | (last << 16));
            if (st & 4) { status = -110; break; }
            uint32_t b = (st >> 8) & 0xFF;
            words[i / 3] = (i % 3 == 0 ? 0 : words[i / 3]) | (b << (8 * (i % 3)));
        } else {
            uint32_t st = i2c_cmd(I2C_WRITE | (((words[i / 3] >> (8 * (i % 3))) & 0xFF) << 8));
            if (st & 4) { status = -110; break; }
            if (st & 2) break;
            acked++;
        }
    }
    if (status == 0 && !rd) status = (int32_t)(n - acked);
    if ((w & (1u << 17)) || status < 0) i2c_cmd(I2C_STOP);
    rsp((uint32_t)status);
    if (rd) for (uint32_t i = 0; i < nw; i++) rsp(status == 0 ? words[i] : 0);
}

// Before a hart reset (machine.reset, machine.soft_reset): what the hart
// set up goes back to its reset state, as MicroPython's soft reset deinits
// pins, timers and buses (ports/rp2/main.c). A hard reset also stops the
// watchdog; a soft reset leaves it running, as on a chip. UART0 keeps its
// rings and rate: the console may be on it.
static void board_reset(uint32_t hard) {
    for (int i = 0; i < NTIMERS; i++) tmr[i].on = 0;
    timer_notify = 0;
    pin_irq_mask = 0; pin_flags = 0;
    for (int p = 0; p < NPINS; p++) pin_cnt[p] = 0;
    for (int i = 0; i < 4; i++) page(PG_PIN_CNT + i, 0);
    page(PG_PIN_FLAGS, 0);
    GPIO_IRQEN = 0; GPIO_EDGE = 0; GPIO_STATUS = 0xFFFFu; GPIO_OE = 0; GPIO_PU = 0; GPIO_PD = 0; GPIO_OUT = 0;
    od_mask = 0;
    PINMUX(0) = 0; PINMUX(1) = 0;
    PWM_EN = 0; SPI_CTRL = 0; I2C_CTRL = 0;
    uart_irq_mask = 0; uart_ev = 0; page(PG_UART0_EV, 0);
    uart0_open = 0;
    if (hard) WDT_KICK = WDT_STOP_KEY;
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
        case SYS_OP_UID: rsp(UID_HI); rsp(UID_LO); break;
        case SYS_OP_RESET: board_reset(w & 1); rsp(0); break;
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
    case CH_PIN_FUNC: {
        uint32_t pin = w & 15, f = (w >> 8) & 15, sh = 4 * (pin % 8);
        PINMUX(pin / 8) = (PINMUX(pin / 8) & ~(15u << sh)) | (f << sh);
        break;
    }
    case CH_PWM_CFG: {
        uint32_t v = cmd_next();
        PWM_PRESC = v >> 16;
        PWM_TOP = v & 0xFFFF;
        break;
    }
    case CH_PWM_DUTY: PWM_DUTY(w & 3) = cmd_next(); break;
    case CH_PWM_EN: PWM_EN = w & 15; break;
    case CH_SPI_INIT: {
        uint32_t div = cmd_next();
        SPI_CTRL = 1 | ((w & 3) << 1) | ((div & 0xFFFF) << 8);
        break;
    }
    case CH_SPI_DEINIT: SPI_CTRL = 0; break;
    case CH_SPI_XFER: spi_xfer(w); break;
    case CH_I2C_INIT: {
        I2C_DIV = cmd_next();
        I2C_TIMEOUT = cmd_next();
        I2C_CTRL = 1;
        break;
    }
    case CH_I2C_DEINIT: I2C_CTRL = 0; break;
    case CH_I2C_XFER: i2c_xfer(w); break;
    case CH_ADC_READ: {
        ADC_CTRL = 0x100 | (w & 15);
        while (ADC_STATUS & 1) service();
        rsp(ADC_DATA & 0xFFFF);
        break;
    }
    case CH_WDT_START: {
        uint32_t ms = cmd_next();
        WDT_LOAD = ms;
        WDT_CTRL = 1;
        break;
    }
    case CH_WDT_FEED: WDT_KICK = WDT_KEY; break;
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

// ---- the USB console (the usb strap): TinyUSB CDC ACM ----
// Output waits in CON until the host has the port open (DTR), for at most
// USB_HOLD_MS after the I/O core starts; after that, with no host listening
// it is dropped, as MicroPython's CDC console drops it. It is cooked as on
// the UART. Input goes to CON_RX; the armed interrupt character is the KBD
// event instead.
#define USB_HOLD_MS 2000u
static int usb_suspended;

static void usb_console(void) {
    tud_int_handler(0);
    tud_task();
    int live = tud_mounted() && !usb_suspended;
    if (live && tud_cdc_connected()) {
        while (tud_cdc_write_available() >= 2) {
            uint32_t c = BR_CON;
            if (!(c & (1u << 31))) break;
            uint8_t b = (uint8_t)c;
            if (b == '\n' && con_prev != '\r') tud_cdc_write_char('\r');
            tud_cdc_write_char((char)b);
            con_prev = b;
        }
        tud_cdc_write_flush();
    } else if (TMR_MS >= USB_HOLD_MS) {
        while (BR_CON & (1u << 31)) { }
    }
    while (live && tud_cdc_available() && !(BR_STATUS & BR_ST_CONRX_FULL)) {
        int c = tud_cdc_read_char();
        if (c < 0) break;
        if ((kbd_char & 0x100) && (uint8_t)c == (uint8_t)kbd_char) event(EV_KBD);
        else BR_CONRX = (uint32_t)c;
    }
}

void tud_suspend_cb(bool remote_wakeup_en) { (void)remote_wakeup_en; usb_suspended = 1; }
void tud_resume_cb(void) { usb_suspended = 0; }

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
        if (con_mode == 1 && (kbd_char & 0x100) && (uint8_t)d == (uint8_t)kbd_char) {
            event(EV_KBD);
            continue;
        }
        if (rx_count() < RING) rx_ring[rx_head++ % RING] = (uint8_t)d;
    }
    // Console: UART input to the hart's CON_RX, the hart's output to UART TX.
    if (con_mode == 1) {
        while (rx_count() && !(BR_STATUS & BR_ST_CONRX_FULL)) BR_CONRX = rx_ring[rx_tail++ % RING];
        // Cooked as MicroPython's console text is (mp_hal_stdout_tx_strn_cooked):
        // \n goes out as \r\n, unless the byte before was \r (the REPL's own
        // line ends, which MicroPython writes raw).
        for (;;) {
            if (tx_free() < 2) break;
            uint32_t c = BR_CON;
            if (!(c & (1u << 31))) break;
            uint8_t b = (uint8_t)c;
            if (b == '\n' && con_prev != '\r') tx_ring[tx_head++ % RING] = '\r';
            tx_ring[tx_head++ % RING] = b;
            con_prev = b;
        }
    }
    if (con_mode == 2) usb_console();
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
    // The microsecond divider rounds to the nearest io_clk count (at
    // 149,992,500 Hz truncating would make the µs 0.7 % short).
    TMR_DIV = (hz + 500000u) / 1000000u - 1;
    con_mode = SYS_CON_MODE;
    // UART0 starts at 115200 8N1 (the console's rate, and machine.UART's
    // default), so bytes that arrive before machine.UART() are kept.
    UART_BAUD = (hz + 57600) / 115200;
    if (con_mode == 2) {
        tusb_rhport_init_t init = { .role = TUSB_ROLE_DEVICE, .speed = TUSB_SPEED_FULL };
        tusb_init(0, &init);
    }
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
