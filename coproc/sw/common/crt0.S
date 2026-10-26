// Reset entry for the coprocessor (RV32EMC, ilp32e).
// The Ibex-class core starts at boot_addr + 0x80; boot_addr is the base
// of code SRAM, and the 32 words below the entry are the vectored trap
// table (mtvec mode 1). Every trap but the external IRQ lands on
// _trap_default. Code SRAM already holds the image (preload or the
// upycore write port), so only .data is copied and .bss cleared.
    .section .vectors, "ax"
    .option norvc
    .global _vectors
_vectors:
    .rept 11
    j _trap_default
    .endr
    j _irq_external          // 11: machine external
    .rept 4
    j _trap_default
    .endr
    .rept 15
    j _irq_fast              // 16..30: fast interrupt lines
    .endr
    j _trap_default          // 31: NMI
    // 0x80: reset
    j _start

    .section .text.start, "ax"
    .option rvc
    .global _start
_start:
    la sp, __stack_top
    la a0, __data_lma
    la a1, __data_start
    la a2, __data_end
1:  bgeu a1, a2, 2f
    lw a3, 0(a0)
    sw a3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j 1b
2:  la a1, __bss_start
    la a2, __bss_end
3:  bgeu a1, a2, 4f
    sw zero, 0(a1)
    addi a1, a1, 4
    j 3b
4:  la a0, _vectors
    ori a0, a0, 1
    csrw mtvec, a0
    call main
5:  wfi
    j 5b

    .weak _irq_external
    .weak _irq_fast
_irq_external:
_irq_fast:
_trap_default:
    mret
