// Reset entry and vector table for the I/O core (RV32EMC, ilp32e).
// Ported from the epic branch's coproc/sw/common/crt0.S.
//
// Both core options reset at 0x80 with mtvec at 0 in vectored mode: the 32
// words below the entry are the trap table (cause i at 4*i). Machine timer
// (7) goes to _irq_timer, machine external (11) to _irq_external; every
// other trap lands on _trap_default.
//
// mpy_boot loads the code SRAM and the data SRAM (.rodata and .data at their
// run addresses) from the boot stream, so nothing is copied here; .bss is
// cleared. The stack is at the top of data SRAM.
    .section .vectors, "ax"
    .option norvc
    .global _vectors
_vectors:
    j _trap_entry            // 0: exceptions
    .rept 6
    j _trap_default
    .endr
    j _irq_timer             // 7: machine timer
    .rept 3
    j _trap_default
    .endr
    j _irq_external          // 11: machine external
    .rept 20
    j _trap_default
    .endr
    // 0x80: reset
    j _start

    .section .text.start, "ax"
    .option rvc
    .global _start
_start:
    la sp, __stack_top
    la a1, __bss_start
    la a2, __bss_end
1:  bgeu a1, a2, 2f
    sw zero, 0(a1)
    addi a1, a1, 4
    j 1b
2:  la a0, _vectors
    ori a0, a0, 1
    csrw mtvec, a0
    call main
3:  wfi
    j 3b

    .weak _irq_timer
    .weak _irq_external
    .weak _trap_entry
_irq_timer:
_irq_external:
_trap_entry:
_trap_default:
    // An unexpected trap: stop with mcause in SYS HALT.
    csrr a0, mcause
    li a1, 0x80000008
    sw a0, 0(a1)
4:  j 4b
