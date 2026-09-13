.global _start
.section .text

_start:
    # تنظیم یک استک ساده با حجم ۴ کیلوبایت
    la sp, stack_top
    
    # پرش به تابع main در کد C
    call main

    # حلقه بی‌نهایت برای جلوگیری از کرش بعد از اتمام main
end_loop:
    j end_loop

.section .bss
.align 4
stack_bottom:
    .space 4096
stack_top:
