.section .data
.align 6
.global tohost
tohost: .dword 0

.global fromhost
fromhost: .dword 0

.section .text
.global _start
_start:
    # ---  Start Our Custom APK ---
    
    # ==========================================================
    # Block 0: Register Initialization                          # ID
    # ==========================================================
    # Plain ALU setup. Each instruction occupies one Scoreboard
    # entry; trans_ids are handed out sequentially, 000..110.
    li a0, 10               # operand for the add below         # 000
    li a1, 2                #                                   # 001
    li a2, 5                # subtrahend for the sub below      # 010
    li a3, 2040             # value stored to memory in Block 1 # 011
    li a4, 15               # minuend for the sub below         # 100
    li a5, 0x80001000       # memory region A base address      # 101
    li a6, 0x80002000       # memory region B base address      # 110

    # ==========================================================
    # Block 1: Store->Load Forwarding (channels 1 and 2)
    # ==========================================================
    sd a6, 0(a5)            # store: accepted by the store      # 111
                            # buffer quickly (channel 1)
    ld a7, 0(a5)            # a7 = a6; reads the address just   # 000 (wrap)
                            # written -> store-to-load
                            # forwarding path is exercised
    sw a3, 0(a7)            # stores through the freshly loaded # 001
                            # pointer; a forwarding event was
                            # observed here in simulation

    # ==========================================================
    # Block 2: The Out-of-Order Race (channel 2 vs channel 0)
    # ==========================================================
    # The lw is OLDER but slow (memory round-trip on channel 2).
    # The div is YOUNGER, but its operands come from independent
    # single-cycle ALU ops, so the serial divider starts while
    # the load is still outstanding. Expected result: div writes
    # back BEFORE lw -- yet both retire in program order.
    lw  t0, 0(a7)           # t0 = MEM[a7] = 2040 (slow)        # 010
    add t1, a3, a0          # t1 = 2040 + 10 = 2050 (fast ALU)  # 011
    sub t2, a4, a2          # t2 = 15 - 5  = 10   (fast ALU)    # 100
    div t3, t1, t2          # t3 = 2050 / 10 = 205              # 101
                            # younger than lw, finishes first

    # --- Finish Our Custom APK ---

    # --- Exit command for Spike ---
    la t0, tohost          
    li t1, 1               
    sd t1, 0(t0)           

loop:
    j loop

