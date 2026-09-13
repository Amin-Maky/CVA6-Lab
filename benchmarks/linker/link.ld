OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
    /* Set the program start address exactly to the CVA6 boot address */
    . = 0x80000000;
    
    .text : {
        *(.text)
    }
    .data : {
        *(.data)
    }
    .bss : {
        *(.bss)
    }
}

