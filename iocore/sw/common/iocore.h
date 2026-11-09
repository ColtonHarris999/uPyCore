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

static inline void csr_set_mie(uint32_t m) { __asm__ volatile("csrs mie, %0" :: "r"(m)); }
static inline void irq_on(void) { __asm__ volatile("csrsi mstatus, 8"); }
static inline void irq_off(void) { __asm__ volatile("csrci mstatus, 8"); }
static inline void wfi(void) { __asm__ volatile("wfi"); }
#endif
