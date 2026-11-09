// The command protocol between the hart and the I/O core
// (upycore/docs/mpy_io_core.md, Commands). A CMD word is a channel in bits
// 31:24 and a payload in bits 23:0; a multi-word command states its length
// in its first word. The hart's side is upycore/runtime/machine.py and
// time.py; keep the numbers in step.
#ifndef PROTO_H
#define PROTO_H

#define CH_SYS        0x01   // 23:16 op
#define   SYS_OP_PING 0x01   //   RSP: the protocol version
#define   SYS_OP_FREQ 0x02   //   RSP: io_clk in Hz
#define CH_ECHO       0x02   // RSP: the same word
#define CH_EVT        0x03   // raise the events in 15:0 (a bridge test)
#define CH_PAGE       0x04   // 4:0 page word, then its value (a bridge test). RSP: the CMD word
#define CH_DNRD       0x05   // RSP: the hart-written page word 2:0

#define CH_PIN_INIT   0x10   // 4:0 pin, 7:5 mode (0 IN, 1 OUT, 2 OPEN_DRAIN),
                             // 9:8 pull (0 none, 1 up, 2 down), 10 set the value, 11 value
#define CH_PIN_WRITE  0x11   // 4:0 pin, 8 value
#define CH_PIN_TOGGLE 0x12   // 4:0 pin

#define CH_UART_INIT  0x20   // 3:0 id; the next word is the baud rate. RSP: the baud rate set
#define CH_UART_TX1   0x21   // one to three bytes, byte 0 in bits 7:0
#define CH_UART_TX2   0x22
#define CH_UART_TX3   0x23
#define CH_UART_RX    0x28   // 7:0 at most this many bytes. RSP: count k, then ceil(k/3)
                             // words of three bytes (byte 0 in bits 7:0)
#define CH_UART_DEINIT 0x29

#define CH_TIMER_INIT 0x30   // 1:0 id, 2 periodic; the next word is the period in µs
#define CH_TIMER_DEINIT 0x31 // 1:0 id

#define PROTO_VERSION 2

// State page words (I/O core writes, hart reads): BR_UP(i).
#define PG_VERSION 0     // 0x494F_00vv: protocol version vv
#define PG_PIN_IN  1     // pin levels
#define PG_MS      3     // the timer's ms count (hardware: mpy_iobr's tick crossing)
#define PG_US      4     // the timer's µs count (hardware)
#define PG_CYCLES  5     // io_clk cycles, updated each ms
#define PG_UART0   6     // 15:0 RX bytes waiting, 27:16 TX ring free, 31 TX busy
#define PG_SEQ     7     // CMD words the I/O core has finished
#define PG_TIMER0  8     // 8-11: expirations of timer 0-3
#define NTIMERS    4
#endif
