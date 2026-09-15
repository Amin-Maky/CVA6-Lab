OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
    /* تنظیم آدرس شروع برنامه دقیقاً روی آدرس بوت CVA6 */
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

