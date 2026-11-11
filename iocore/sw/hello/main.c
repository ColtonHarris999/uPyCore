// Phase 0 hello: print over the UART, show the timer runs, take one timer
// interrupt, echo two received bytes, then halt.
#include "iocore.h"

static void putc_(char c) { UART_DATA = (uint8_t)c; }
static void puts_(const char *s) { while (*s) putc_(*s++); }
static void puthex(uint32_t v) {
    for (int i = 28; i >= 0; i -= 4) putc_("0123456789abcdef"[(v >> i) & 15]);
}

static volatile uint32_t ticks;

void _irq_timer(void) __attribute__((interrupt("machine")));
void _irq_timer(void) {
    ticks++;
    TMR_CTRL = 2;            // clear pending; leaves the compare disabled
}

int main(void) {
    puts_("hello from the I/O core\n");
    puts_("id ");
    puthex(SYS_ID);
    putc_('\n');
    uint32_t t0 = TMR_US;
    while (TMR_US - t0 < 50) { }
    puts_("timer ok\n");
    // One timer interrupt 20 us from now.
    TMR_CMP = TMR_US + 20;
    TMR_CTRL = 1;
    csr_set_mie(1u << 7);
    irq_on();
    while (ticks == 0) wfi();
    irq_off();
    puts_("irq ok\n");
    // Echo two bytes from the line model.
    for (int n = 0; n < 2; ) {
        uint32_t w = UART_DATA;
        if (w & UART_RX_VALID) { putc_('<'); putc_((char)w); putc_('>'); n++; }
    }
    putc_('\n');
    while (UART_STATUS & UART_ST_TXBUSY) { }
    SYS_HALT = 0;
    for (;;) { }
}
