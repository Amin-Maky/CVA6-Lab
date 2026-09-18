.global _start
.section .text

_start:
    # Initialize a simple stack with 4KB size
    la sp, stack_top
    
    # Jump to the main function in the C code
    call main

    # Infinite loop to prevent crashing after main returns
end_loop:
    j end_loop

.section .bss
.align 4
stack_bottom:
    .space 4096
stack_top:

