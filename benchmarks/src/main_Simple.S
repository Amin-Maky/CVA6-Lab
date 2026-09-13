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
    li t0, 0x80001000      # Target address (to monitor in Verilator)
    li t1, 0xDEADBEEF      # Test data
    sw t1, 0(t0)           # Write data to the address
    # --- Finish Our Custom APK ---

    # --- Exit command for Spike ---
    la t0, tohost          # Get the physical address of tohost
    li t1, 1               # The value 1 means PASS (successful termination)
    sw t1, 0(t0)           # Write 1 to tohost to halt Spike

loop:
    j loop                 # Just in case (prevents crashing if another simulator ignores tohost)

