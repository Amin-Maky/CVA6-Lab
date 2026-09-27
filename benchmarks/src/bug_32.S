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
    # 1. Register Initialization (Setup)
    # ==========================================
						# ID
    li a0, 10					# 000
    li a1, 2					# 001
    li a2, 5					# 010
    li a3, 4096					# 011
    li a4, 15					# 100



    # ==========================================
    # 2. Test
    # ==========================================
						# ID	# ID
    sub t1, a4, a2	# t1 = 15 - 5 = 10	# 101	# 101
    div t2, a3, t1	# t2 = 409		# 110	# 110 
    add t3, a0, a1	# t3 = 12		# 111	# 111
    add t4, a0, t3	# t4 = 22		# 000	# 000
    add t5, a0, t4	# t5 = 32		# 001	# 001
  # beq t1, a0, branch				# ---	# ---	# 010
    add t3, a0, t5	# t3 = 42		# 010	# 010	# ---
    beq t1, a0, branch				# ...	# 011	# ---
    add t4, a0, t3	# t4 = 52		# 011	# ---	# ---
    add t5, a0, t4	# t5 = 62		# 100	# ---	# ---
    add t3, a0, t5	# t3 = 72		# 101	# ---	# ---
branch:
    add t5, a0, t4	# t5 = 62		# 110	# 100	# 011
    add t3, a0, t5	# t3 = 72		# 111	# 101	# 100
    
    
    # --- Finish Our Custom APK ---

    # --- Exit command for Spike ---
    la t0, tohost          
    li t1, 1
    sw t1, 0(t0)           

loop:
    j loop

