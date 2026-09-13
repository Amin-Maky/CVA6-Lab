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
    
    
    

    # ==========================================
    # 0. Register Initialization (Setup)
    # ==========================================
    li a0, 10					# 000
    li a1, 2					# 001
    li a2, 5					# 010
    li a3, 4040					# 011
    li a4, 15					# 100
    li a5, 0x80001000				# 101
    li a6, 0x80002000				# 110 - 010

    # ==========================================
    # 1. Normal Forwarding
    # ==========================================
    
    sd a6, 0(a5)				# 011
    ld a7, 0(a5)				# 100
    sw a3, 0(a7)				# 101
    
    # ==========================================
    # 2. Out-of-Order Execution 
    # ==========================================
						# ID
    lw  t0, 0(a7)				# 110
    
    sub t2, a4, a2	# t1 = 15 - 5 = 10	# 111 	
  # beq t2, a0, forget
    div t3, a3, t2	# t3 = 50		# 000 
    
    lw  t0, 0(a7)				# 001

    add t4, t2, t2	# t4 = 10 + 10  =  20	# 010
    add t5, t2, t4	# t5 = 10 + 20  =  30	# 011
    add t6, t2, t4	# t6 = 10 + 20  =  30	# 100
  # beq t6, t5, forget
    # add t6, t2, t6	# t6 = 10 + -30 = -10	# 101
    add t6, t2, t6	# t6 = 10 + -10 =  0	# 110
    sub t6, t2, t6	# t6 = 10 + 0   =  10	# 111
    
forget:

    add t4, t2, t2	# t4 = 10 + 10  =  20	# 010
    add t5, t2, t4	# t5 = 10 + 20  =  30	# 011
    sub t6, t2, t5	# t6 = 10 - 30  = -20	# 100
    
    # --- Finish Our Custom APK ---

    # --- Exit command for Spike ---
    la t0, tohost          
    li t1, 1
    sd t1, 0(t0)           

loop:
    j loop

