# I/O core toolchain (RV32EMC, ilp32e)

The I/O core's firmware is C, built with Ubuntu's RISC-V GCC and picolibc
for `-march=rv32emc_zicsr -mabi=ilp32e`. The recipe is the epic branch's
(`coproc/sw/TOOLCHAIN.md` on `claude/epic-dirac-58oxzv`), unchanged:

```bash
apt-get install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf \
                picolibc-riscv64-unknown-elf
```

| Package | Version used on this branch |
| --- | --- |
| `gcc-riscv64-unknown-elf` | 13.2.0-11ubuntu1+12 |
| `binutils-riscv64-unknown-elf` | 2.42-1ubuntu1+6 |
| `picolibc-riscv64-unknown-elf` | 1.8.6-2 |

There is no `rv32emc` multilib; `-march=rv32emc_zicsr -mabi=ilp32e` links
`rv32em/ilp32e` libgcc and picolibc (no compressed instructions in the few
library routines the firmware uses). The firmware calls almost nothing
from the C library.

```bash
make -C iocore/sw APP=hello      # build/iocore/hello/{code,data}.hex
make -C iocore/sw                # APP=fw, the production image
```

`common/iocore.ld` places `.vectors` and `.text` in code SRAM at
`0x0000_0000`, and `.rodata`, `.data`, `.bss` and the stack in data SRAM at
`0x0001_0000`. The data port cannot read code SRAM, so read-only data lives
in data SRAM; `mpy_boot` loads both images from the boot stream, so the
startup code copies nothing. The link fails if code passes 16 KB or data
8 KB (the SRAMs), or code 14 KB or data 7 KB (the plan's budget).

The same image runs on both core options (`iocore/rtl/iocore_cpu.sv`):
both reset at `0x80` with a vectored `mtvec` at 0.
