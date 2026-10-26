/* Coprocessor memory map (upycore/docs/mpy_coproc.md).
 * Code SRAM holds .vectors, .text and .rodata, plus the load image of
 * .data. Data SRAM holds .data, .bss, and the stack at its top.
 * CODE_SIZE and DATA_SIZE are the SRAM sizes the build is checked
 * against; a link that does not fit fails here. */
CODE_SIZE = DEFINED(CODE_SIZE) ? CODE_SIZE : 16K;
DATA_SIZE = DEFINED(DATA_SIZE) ? DATA_SIZE : 8K;

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
    } > code

    .rodata : {
        *(.rodata .rodata.* .srodata .srodata.*)
        . = ALIGN(4);
    } > code

    .data : {
        __data_start = .;
        *(.data .data.* .sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > data AT > code
    __data_lma = LOADADDR(.data);

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > data

    __code_end = __data_lma + SIZEOF(.data);
    __stack_top = ORIGIN(data) + DATA_SIZE;

    ASSERT(__code_end <= ORIGIN(code) + CODE_SIZE, "code SRAM overflow")
    ASSERT(__bss_end <= __stack_top, "data SRAM overflow")

    /DISCARD/ : { *(.comment) *(.riscv.attributes) }
}
