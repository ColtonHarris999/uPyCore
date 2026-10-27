// The coprocessor firmware: TinyUSB CDC ACM on the no2usb SIE, bridged to
// the hart through the mailbox (upycore/docs/mpy_coproc.md, Messages and
// Firmware). One polled loop; no interrupts.
#include "tusb.h"
#include "coproc.h"

static uint32_t kbd_char;       // the hart's interrupt character
static int kbd_armed;
static uint32_t kbd_test_at;    // CMB_CYCLES at which KBD_TEST rings, 0 = none
static uint32_t state_sent = 0xffffffffu;
static int suspended;

// A word for the hart that waits for room in the up FIFO. While one waits
// no further word is taken from the hart, so neither side can wedge the
// other: the hart pops replies without waiting on its own sends.
static uint32_t reply;
static int reply_pending;

// A console byte from the hart that waits for room in the CDC IN FIFO.
static uint8_t con_out;
static int con_out_pending;

static void log_str(const char *s) {
    while (*s)
        CMB->debug = (uint8_t)*s++;
}

static int up_full(void) {
    return (CMB->status & CMB_ST_TX_FULL) != 0;
}

static void reply_word(uint32_t w) {
    reply = w;
    reply_pending = 1;
}

static void hart_word(uint32_t w) {
    uint32_t p = MB_PAYLOAD(w);
    switch (MB_CH(w)) {
    case CH_CON:
        // Output with no host is dropped, so the hart never blocks on it. A
        // byte waits only while the CDC IN FIFO is full.
        if (tud_mounted() && !suspended) {
            if (tud_cdc_write_available() > 0)
                tud_cdc_write_char((char)p);
            else {
                con_out = (uint8_t)p;
                con_out_pending = 1;
            }
        }
        break;
    case CH_CTRL:
        if ((p >> 16) == CTRL_KBD) {
            kbd_armed = (p >> 8) & 1;
            kbd_char = p & 0xff;
        } else if ((p >> 16) == CTRL_KBD_TEST) {
            kbd_test_at = CMB->cycles + 1000;
            if (kbd_test_at == 0)
                kbd_test_at = 1;
        }
        break;
    case CH_ECHO:
        reply_word(w);
        break;
    case CH_COPY:
        SHARED[(p >> 10) & 0x3ff] = SHARED[p & 0x3ff];
        reply_word(w);
        break;
    default:
        break;
    }
}

static uint32_t usb_state(void) {
    uint32_t s = 0;
    if (tud_mounted())
        s |= STATE_CONFIGURED;
    if (suspended)
        s |= STATE_SUSPENDED;
    if (tud_mounted() && tud_cdc_connected())
        s |= STATE_DTR;
    return s;
}

int main(void) {
    tusb_rhport_init_t init = { .role = TUSB_ROLE_DEVICE, .speed = TUSB_SPEED_FULL };
    tusb_init(0, &init);
    log_str("coproc up\n");
    for (;;) {
        tud_int_handler(0);
        tud_task();

        if (reply_pending && !up_full()) {
            CMB->tx = reply;
            reply_pending = 0;
        }
        if (con_out_pending) {
            if (!tud_mounted() || suspended)
                con_out_pending = 0;
            else if (tud_cdc_write_available() > 0) {
                tud_cdc_write_char((char)con_out);
                con_out_pending = 0;
            }
        }
        // Hart to coprocessor, a burst at a time.
        for (int n = 0; n < 64 && !reply_pending && !con_out_pending &&
                        (CMB->status & CMB_ST_RX_ANY); n++)
            hart_word(CMB->rx);
        if (tud_mounted() && tud_cdc_write_available() < CFG_TUD_CDC_TX_BUFSIZE)
            tud_cdc_write_flush();

        // CDC OUT to the hart; the armed interrupt character rings KBD.
        while (!reply_pending && !up_full() && tud_cdc_available()) {
            int c = tud_cdc_read_char();
            if (c < 0)
                break;
            if (kbd_armed && (uint32_t)c == kbd_char)
                CMB->kbd = 1;
            else
                CMB->tx = MB_WORD(CH_CON, (uint32_t)c);
        }

        if (kbd_test_at && (int32_t)(CMB->cycles - kbd_test_at) >= 0) {
            CMB->kbd = 1;
            kbd_test_at = 0;
        }

        uint32_t s = usb_state();
        if (s != state_sent && !reply_pending && !up_full()) {
            CMB->tx = MB_WORD(CH_CTRL, (CTRL_STATE << 16) | s);
            state_sent = s;
        }
    }
}

void tud_mount_cb(void) {
    log_str("mount\n");
}

void tud_umount_cb(void) {
    log_str("umount\n");
}

void tud_suspend_cb(bool remote_wakeup_en) {
    (void)remote_wakeup_en;
    suspended = 1;
    log_str("suspend\n");
}

void tud_resume_cb(void) {
    suspended = 0;
    log_str("resume\n");
}

void tud_cdc_line_state_cb(uint8_t itf, bool dtr, bool rts) {
    (void)itf;
    (void)rts;
    log_str(dtr ? "dtr 1\n" : "dtr 0\n");
}
