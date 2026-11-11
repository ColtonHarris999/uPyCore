/* I/O core memory map (upycore/docs/mpy_io_core.md).
 * Code SRAM holds .vectors and .text only: the data port cannot read it.
 * Data SRAM holds .rodata and .data (loaded at their run addresses by
 * mpy_boot from the boot stream's IOCB section), .bss, and the stack at
 * its top. CODE_SIZE and DATA_SIZE are the SRAM sizes the build is
 * checked against; CODE_BUDGET and DATA_BUDGET are the plan's size gate
 * (14 KB code, 7 KB data). A link that does not fit fails here. */
CODE_SIZE = DEFINED(CODE_SIZE) ? CODE_SIZE : 16K;
DATA_SIZE = DEFINED(DATA_SIZE) ? DATA_SIZE : 7680;
CODE_BUDGET = DEFINED(CODE_BUDGET) ? CODE_BUDGET : 14K;
DATA_BUDGET = DEFINED(DATA_BUDGET) ? DATA_BUDGET : 7K;
STACK_SIZE = DEFINED(STACK_SIZE) ? STACK_SIZE : 1K;

MEMORY {
    code (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    data (rw)  : ORIGIN = 0x00010000, LENGTH = 32K
}

ENTRY(_start)

SECTIONS {
    .vectors : {
        KEEP(*(.vectors))
    } > code

    .text : {
        *(.text.start)
        *(.text .text.*)
        . = ALIGN(4);
        __code_end = .;
    } > code

    .rodata : {
        *(.rodata .rodata.* .srodata .srodata.*)
        . = ALIGN(4);
    } > data

    .data : {
        __data_start = .;
        *(.data .data.* .sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > data

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > data

    __stack_top = ORIGIN(data) + DATA_SIZE;

    ASSERT(__code_end <= ORIGIN(code) + CODE_SIZE, "code SRAM overflow")
    ASSERT(__code_end <= ORIGIN(code) + CODE_BUDGET, "code over the 14 KB budget")
    ASSERT(__bss_end + STACK_SIZE <= __stack_top, "data SRAM overflow")
    ASSERT(__bss_end + STACK_SIZE <= ORIGIN(data) + DATA_BUDGET, "data over the 7 KB budget")

    /DISCARD/ : { *(.comment) *(.riscv.attributes) }
}
