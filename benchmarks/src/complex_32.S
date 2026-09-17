.section .data
.align 6
.global tohost
tohost: .dword 0

.global fromhost
fromhost: .dword 0


.section .bss
.align 6
.global custom_scratch
custom_scratch:
    .zero 512


.section .text
.global _start
_start:
    # ---  Start Our Custom APK ---

    # RV64IM computational stress workload
    # t6      : base address of scratchpad
    # s0      : outer-loop counter
    # s1      : inner-loop counter
    # s2-s11  : computational state
    # a0-a7   : temporary arithmetic values

    la      t6, custom_scratch

    # ------------------------------------------------------------
    # Phase 1: Initialize scratchpad with ALU and MUL operations
    # ------------------------------------------------------------

    li      s0, 0
    li      s2, 0x13579bdf2468ace1
    li      s3, 0x0f1e2d3c4b5a6978
    li      s4, 0x1122334455667788
    li      s5, 0x8877665544332211
    li      s6, 0xdeadbeefcafebabe
    li      s7, 0x0123456789abcdef

init_loop:
    slli    t0, s0, 3
    add     t1, t6, t0

    xor     s2, s2, s3
    add     s2, s2, s4
    sub     s3, s3, s5
    and     s4, s4, s6
    or      s5, s5, s7
    
    # xnor requires Zbb extension, replacing with xor + not
    xor     s6, s6, s2
    not     s6, s6

    mul     a0, s2, s3
    mulh    a1, s4, s5
    add     a0, a0, a1
    xor     a0, a0, s6

    sw      a0, 0(t1)

    addi    s0, s0, 1
    slti    t2, s0, 64
    bnez    t2, init_loop


    # ------------------------------------------------------------
    # Phase 2: Main mixed memory / ALU / MUL / DIV workload
    # ------------------------------------------------------------

    li      s0, 0                  # outer-loop counter
    li      s8, 64                 # number of outer iterations
    li      s9, 512                # number of inner iterations

    li      s2, 0x1020304050607080
    li      s3, 0x8877665544332211
    li      s4, 0x7fffffffffffffff
    li      s5, 0x03141596
    li      s6, 0x08459045
    li      s7, 0xaaaaaaaa55555555

outer_loop:
    li      s1, 0                  # inner-loop counter
    add     s10, s2, s0
    xor     s11, s3, s0

inner_loop:
    # Generate an address in the 512-byte scratchpad.
    # The mask keeps the offset in the range 0..504.
    add     t0, s1, s0
    slli    t0, t0, 3
    andi    t0, t0, 504
    add     t1, t6, t0

    # Memory dependency chain
    lw      a0, 0(t1)
    lw      a1, 8(t1)
    add     a2, a0, a1
    xor     a3, a0, a1
    sub     a4, a2, a3

    # Heavy ALU mixing
    slli    a5, a2, 7
    srli    a6, a3, 11
    srai    a7, a4, 5
    or      a5, a5, a6
    and     a6, a5, a7
    
    # xnor requires Zbb extension, replacing with xor + not
    xor     a7, a6, a4
    not     a7, a7

    add     s2, s2, a5
    sub     s3, s3, a6
    xor     s4, s4, a7
    or      s5, s5, s2
    and     s6, s6, s3
    
    # xnor requires Zbb extension, replacing with xor + not
    xor     s7, s7, s4
    not     s7, s7

    # Multiply and multiply-high pressure
    mul     t2, s2, s3
    mulh    t3, s4, s5
    mulhu   t4, s6, s7
    mulhsu  t5, t2, t3

    add     t2, t2, t3
    xor     t2, t2, t4
    sub     t2, t2, t5

    # Ensure non-zero divisors using OR with one
    ori     a0, s3, 1
    ori     a1, s5, 1
    ori     a2, s7, 1

    # Division and remainder pressure
    div     a3, t2, a0
    rem     a4, t2, a1
    divu    a5, t3, a2
    remu    a6, t4, a0

    # More dependent arithmetic after division
    add     a3, a3, a4
    xor     a5, a5, a6
    mul     a7, a3, a5
    add     a7, a7, t2

    # Store results back to the scratchpad
    sw      a7, 0(t1)
    sw      t2, 8(t1)

    # Additional memory traffic with another computed address
    xor     t0, s1, s0
    slli    t0, t0, 3
    andi    t0, t0, 504
    add     t1, t6, t0

    lw      t2, 0(t1)
    add     t2, t2, a7
    xor     t2, t2, s4
    sw      t2, 0(t1)

    # Branch-heavy control flow
    andi    t3, s1, 7
    beqz    t3, branch_path_a

branch_path_b:
    add     s10, s10, t2
    xor     s11, s11, a3
    j       branch_path_join

branch_path_a:
    sub     s10, s10, t2
    add     s11, s11, a5

branch_path_join:
    andi    t3, s1, 3
    bnez    t3, skip_extra_mix

    mul     t4, s10, s11
    div     t5, t4, a0
    add     s2, s2, t5
    xor     s3, s3, t4

skip_extra_mix:
    addi    s1, s1, 1
    bltu    s1, s9, inner_loop

    # Outer-loop state update
    add     s2, s2, s10
    xor     s3, s3, s4
    xor     s3, s3, s2
    div     s5, s5, s3

    addi    s0, s0, 1
    bltu    s0, s8, outer_loop


    # ------------------------------------------------------------
    # Phase 3: Final reduction over scratchpad
    # ------------------------------------------------------------

    li      s0, 0
    li      s2, 0
    li      s3, 0
    li      s4, 1
    li      s5, 0x123456789abcdef0

reduce_loop:
    slli    t0, s0, 3
    add     t1, t6, t0
    lw      a0, 0(t1)

    add     s2, s2, a0
    xor     s3, s3, a0
    mul     s4, s4, a0

    ori     a1, a0, 1
    div     a2, s5, a1
    rem     a3, s5, a1

    add     s5, s5, a2
    xor     s5, s5, a3

    addi    s0, s0, 1
    
    # Replaced pseudo bltu instruction with slti + bnez
    slti    t2, s0, 64
    bnez    t2, reduce_loop


    # Prevent the compiler/simulator from treating the result as unused.
    # The final signature is written to the last scratchpad entry.
    sw      s2, 496(t6)
    sw      s3, 504(t6)

    # --- Finish Our Custom APK ---

    # --- Exit command for Spike ---
    la      t0, tohost
    li      t1, 1
    sw      t1, 0(t0)

loop:
    j       loop

