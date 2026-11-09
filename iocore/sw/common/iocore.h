// I/O core register map (upycore/docs/mpy_io_core.md). Word registers only.
#ifndef IOCORE_H
#define IOCORE_H
#include <stdint.h>

#define REG(a) (*(volatile uint32_t *)(a))

// SYS
#define SYS_BASE      0x80000000u
#define SYS_ID        REG(SYS_BASE + 0x00)
#define SYS_DEBUG     REG(SYS_BASE + 0x04)
#define SYS_HALT      REG(SYS_BASE + 0x08)
#define SYS_IRQ_PEND  REG(SYS_BASE + 0x0C)
#define SYS_IRQ_EN    REG(SYS_BASE + 0x10)
#define SYS_SCRATCH   REG(SYS_BASE + 0x14)
#define IRQ_UART0     (1u << 0)

// Timer
#define TMR_BASE      0x80001000u
#define TMR_CYCLES    REG(TMR_BASE + 0x00)
#define TMR_DIV       REG(TMR_BASE + 0x04)
#define TMR_US        REG(TMR_BASE + 0x08)
#define TMR_MS        REG(TMR_BASE + 0x0C)
#define TMR_CMP       REG(TMR_BASE + 0x10)
#define TMR_CTRL      REG(TMR_BASE + 0x14)

// UART0
#define UART_BASE     0x80002000u
#define UART_DATA     REG(UART_BASE + 0x00)
#define UART_STATUS   REG(UART_BASE + 0x04)
#define UART_BAUD     REG(UART_BASE + 0x08)
#define UART_IRQEN    REG(UART_BASE + 0x0C)
#define UART_CLR      REG(UART_BASE + 0x10)
#define UART_RX_VALID (1u << 31)
#define UART_ST_TXFULL (1u << 18)
#define UART_ST_TXBUSY (1u << 16)

// Bridge to the hart (I/O core side)
#define BR_BASE       0x80003000u
#define BR_CMD        REG(BR_BASE + 0x00)   // load pops a CMD word (0 when empty)
#define BR_CMD_LEVEL  REG(BR_BASE + 0x04)
#define BR_RSP        REG(BR_BASE + 0x08)   // store pushes a RSP word (waits while full)
#define BR_EVT        REG(BR_BASE + 0x0C)   // store pushes an event set-mask
#define BR_CON        REG(BR_BASE + 0x10)   // load pops a console byte: bit 31 valid, bit 8 stderr
#define BR_CONRX      REG(BR_BASE + 0x14)   // store pushes a console input byte
#define BR_STATUS     REG(BR_BASE + 0x18)
#define BR_IRQEN      REG(BR_BASE + 0x1C)
#define BR_DN_NEW     REG(BR_BASE + 0x20)
#define BR_UP(i)      REG(BR_BASE + 0x800 + 4 * (i))   // page words the hart reads
#define BR_DN(i)      REG(BR_BASE + 0xC00 + 4 * (i))   // page words the hart writes
#define BR_ST_CMD     (1u << 0)
#define BR_ST_CON     (1u << 1)
#define BR_ST_RSP_FULL (1u << 2)
#define BR_ST_CONRX_FULL (1u << 3)
#define IRQ_BRIDGE    (1u << 1)

static inline void csr_set_mie(uint32_t m) { __asm__ volatile("csrs mie, %0" :: "r"(m)); }
static inline void irq_on(void) { __asm__ volatile("csrsi mstatus, 8"); }
static inline void irq_off(void) { __asm__ volatile("csrci mstatus, 8"); }
static inline void wfi(void) { __asm__ volatile("wfi"); }
#endif
