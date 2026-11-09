// The command protocol between the hart and the I/O core
// (upycore/docs/mpy_io_core.md, Commands). A CMD word is a channel in bits
// 31:24 and a payload in bits 23:0; a multi-word command states its length
// in its first word. The hart's side is upycore/runtime/machine.py and
// upycore/firmware/io.py; keep the numbers in step.
#ifndef PROTO_H
#define PROTO_H

#define CH_SYS    0x01   // 23:16 op
#define CH_ECHO   0x02   // RSP: the same word
#define CH_EVT    0x03   // raise the events in 15:0 (a bridge test)
#define CH_PAGE   0x04   // 4:0 page word; the next word is its value (a bridge test). RSP: the CMD word
#define CH_DNRD   0x05   // RSP: the hart-written page word 2:0

#define SYS_PING  0x01   // RSP: the protocol version
#define PROTO_VERSION 1

// State page words (I/O core writes, hart reads): BR_UP(i).
#define PG_VERSION 0     // 0x494F_xxyy: protocol version yy
#endif
