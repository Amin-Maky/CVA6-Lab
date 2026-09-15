# CVA6 Simulation Flow

---

## 1. Post-Synthesis Simulation (Vivado / XSIM)

**Goal:** Run a functional simulation of the synthesized CVA6 netlist in XSIM, load a small RISC-V program into the core over its AXI instruction interface, and verify at the waveform level that the core actually fetches and executes it.

**Why this step exists.** Behavioral simulation of CVA6 does not work on a 16 GB machine. XSIM fails during elaboration with `[XSIM 43-3322] Static elaboration of top level Verilog design unit(s) in library work failed.` for every configuration, including the lightest one, because the core instantiates internal arrays whose static footprint exceeds available RAM. The workaround — and the subject of this document — is to **synthesize first**, then simulate the resulting netlist using **Post-Synthesis Functional Simulation**. This trades elaboration memory for compile time and gives a design that XSIM can actually load.

**Prerequisites.** The machine preparation and the synthesis run are already covered, and are *not* repeated here:

- **[`1-environment-setup.md`](1-environment-setup.md)** — Linux/WSL2, ext4, storage and RAM planning, swap configuration, Bender installation, and network access.
- **[`2-vivado-synthesis.md`](2-vivado-synthesis.md)** — project creation, `bender script vivado -t <cpu_version> > cva6_files.tcl`, and the full synthesis flow through the utilization report.

**What this section covers.** Three parts, in order:

- **1.1 AXI Testbench and Firmware Setup** — CVA6 has no internal program memory, so a SystemVerilog testbench is written to act as a virtual AXI RAM slave, and a minimal RISC-V program (`main.S` + `link.ld`) is compiled and converted to a memory image the testbench can preload.
- **1.2 Elaboration and Simulation in XSIM** — launching Post-Synthesis Functional Simulation, handling the flattened netlist ports (packed structs become auto-named nets), and running to the point where the core begins fetching.
- **1.3 Waveform Inspection** — reading the AXI read/write channels, confirming the FSM leaves `AR_IDLE`, and verifying the self-checking result: `noc_w_data[63:0] = 0x0000001e_0000001e` when `noc_w_valid` asserts.

**Expected cost and outcome.** Peak memory during simulation is roughly **10.8 GB**, and the initial `launch_simulation` takes about **8 minutes**. Bus activity begins at approximately **2,685,000 ns**, well after reset release. A successful run ends with an observed AXI write

---

### 1.1 AXI Testbench and Firmware Setup

Post-synthesis simulation of CVA6 introduces three interrelated challenges that do not exist in a pure RTL flow. First, Vivado's synthesis flattens every packed struct and interface into individual scalar nets, breaking the signal hierarchy that the RTL testbench depended on. Second, CVA6 has no internal instruction ROM — it is a bus-master that fetches code over AXI, so the simulation environment must supply a working AXI slave loaded with real firmware. Third, that firmware must be compiled, linked, and address-translated into a format that a SystemVerilog `$readmemh` call can consume directly.

The four subsections below address each of these problems in the order you encounter them when setting up the flow from scratch.

---

#### 1.1.1 The Flattened-Netlist Problem

**Why CVA6 uses struct types**

The CVA6 top module exposes a mix of plain-logic ports and struct-typed ports:

```systemverilog
input  logic                       clk_i,
input  logic                       rst_ni,
input  logic [CVA6Cfg.VLEN-1:0]   boot_addr_i,
// ...
output rvfi_probes_t               rvfi_probes_o,
output cvxif_req_t                 cvxif_req_o,
input  cvxif_resp_t                cvxif_resp_i,
output noc_req_t                   noc_req_o,
input  noc_resp_t                  noc_resp_i
```

Types like `noc_req_t` are `parameter type` packed structs — for example:

```systemverilog
parameter type noc_req_t = struct packed {
    axi_aw_chan_t  aw;
    logic          aw_valid;
    axi_w_chan_t   w;
    logic          w_valid;
    logic          b_ready;
    axi_ar_chan_t  ar;
    logic          ar_valid;
    logic          r_ready;
};
```

The project uses this style because it groups related signals under one named port, makes the RTL readable, and makes waveform debugging easier — you see `noc_req_o.ar_valid` instead of thirty anonymous wires.

**What synthesis does to them**

Vivado does not preserve struct types in the output netlist. Every field of every packed struct gets flattened into its own standalone wire, named by the tool. The struct hierarchy you see in RTL simply does not exist in the synthesized netlist.

**Extracting the ground truth**

Before writing any testbench code, dump the post-synthesis netlist:

```tcl
# In the Vivado Tcl console, after synthesis:
pwd                          ; # shows where the file will be written
write_verilog -force cva6_netlist.v
```

The resulting file will be large — on the order of five million lines for a full CVA6 configuration. That is normal. Open it, search for the top-level module declaration, and look at the port list.

**Understanding the names you find**

The first thing that will look strange is lines like this:

```systemverilog
output [31:0] \rvfi_probes_o[csr][jvt_q] ;
```

The `\` is Verilog's **escaped identifier** syntax. It means: everything between the backslash and the next whitespace character is the signal name, even if it contains characters — brackets, dots — that are normally illegal in an identifier. That trailing space before the `;` is part of the syntax, not a typo.

This is how Vivado encodes the flattened field names. The `noc_req_o` struct becomes a set of ports like:

```systemverilog
\noc_req_o[ar_valid]
\noc_req_o[aw_valid]
\noc_req_o[w_data][63]
\noc_req_o[w_data][62]
...
```

These escaped identifiers are the exact strings your testbench must use when wiring up the DUT. You cannot use the original struct port names — they no longer exist as ports.

**Impact on testbench instantiation**

A behavioral testbench connects struct ports cleanly:

```systemverilog
cva6_top dut (
    .clk_i      (clk),
    .noc_req_o  (axi_req),   // single struct connection — RTL sim only
    .noc_resp_i (axi_resp)
);
```

In post-synthesis simulation, that elaborates with an error because `noc_req_o` is not a port. Instead, every field must be connected individually:

```systemverilog
cva6_top dut (
    .clk_i                          (clk),
    .\noc_req_o[ar_valid]           (ar_valid_wire),
    .\noc_req_o[ar_bits_addr][31:0] (ar_addr_wire),
    // ... one line per flattened field
);
```

The practical workflow is: extract the port list from `cva6_netlist.v`, generate the connection list (a small script helps here), and drop it into the testbench. Section 1.1.4 shows how the AXI RAM testbench maps these flat ports onto its internal FSM.

---

#### 1.1.2 Firmware: `main-syn.S` and `link-syn.ld`

CVA6 has no internal ROM. When reset releases, the core immediately issues an AXI read at `PC_RESET` — it expects real, valid instructions to be waiting there. This means the simulation cannot start without a working firmware image preloaded into the testbench RAM.

The firmware has two jobs: give the core something meaningful to execute, and communicate the result back to the testbench without any dedicated signaling hardware. Both constraints are solved by the same one-line technique.

**The assembly program**

```asm
    .section .text
    .global _start

_start:
    li  x1, 10             # x1 = 0x0A
    li  x2, 20             # x2 = 0x14
    add x3, x1, x2         # x3 = 0x1E  ← expected result

    li  x4, 0x80001000     # target address
    sw  x3, 0(x4)          # write result into RAM

loop:
    j loop                 # park the core
```

The arithmetic is intentionally trivial — the interesting part is the `sw`. Because the testbench acts as the AXI RAM slave, it sees every write transaction on the bus. Writing a known value (`0x1E`) to a known address (`0x80001000`) is the handshake: when the testbench's FSM observes that write, it knows the core has finished executing and the result is correct. No interrupt lines, no extra ports, no out-of-band signaling — just a store that the AXI slave was always going to handle anyway.

The trailing `j loop` prevents the core from fetching past the end of the `.text` section into unmapped memory, which would generate bus errors and pollute the waveform.

**The linker script**

```ld
OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
    . = 0x80000000;    /* CVA6 boot address */

    .text : { *(.text) }
    .data : { *(.data) }
    .bss  : { *(.bss)  }
}
```

The only non-obvious line is `. = 0x80000000`. This sets the load address of `.text` to match `PC_RESET` in the CVA6 configuration. If this address does not match, the core's first fetch hits the right physical location in the testbench RAM but the ELF symbol table disagrees with the actual instruction layout — the core executes garbage. Getting this address right is the entire purpose of the linker script.

**you can view the files in these directories:**

    CVA6-lab/                     # Main repository root
    └── benchmarks/               # Software only (formerly firmware)
        ├── src/                  # Source files (main-syn.S)
        └── linker/               # Linker scripts (link.ld, link-syn.ld)

---

#### 1.1.3 Building the Hex Image

Two source files exist at this point — `benchmarks/src/main-syn.S` and `benchmarks/linker/link-syn.ld`. The simulation testbench cannot consume either of them directly. It needs a Verilog hex file, loaded via `$readmemh`, with addresses that match its internal RAM layout. Getting there requires two commands.

---

**Method 1: Manual build**

**Compile and link**

```bash
riscv-none-elf-gcc \
    -march=rv32imac \
    -mabi=ilp32 \
    -nostdlib \
    -T benchmarks/linker/link-syn.ld \
    benchmarks/src/main-syn.S \
    -o firmware.elf
```

- `-march=rv32imac` and `-mabi=ilp32` match the CVA6 configuration being simulated.
- `-nostdlib` suppresses any C runtime startup; the linker script is the complete memory map.

**Extract the hex image**

```bash
riscv-none-elf-objcopy \
    -O verilog \
    --verilog-data-width=4 \
    --change-addresses -0x80000000 \
    firmware.elf \
    firmware_syn.hex
```

The flag that requires explanation is `--change-addresses -0x80000000`. The linker placed `.text` at `0x80000000` to satisfy `PC_RESET`. The testbench's `ram` array, however, is indexed from `0` — `ram[0]` holds the first instruction word, not `ram[0x20000000]`. Without the address shift, `$readmemh` either writes into an impossibly large index or produces an elaboration error. Subtracting `0x80000000` from every address before writing the hex file relocates the first instruction to offset `0x0`, which is exactly where `ram[0]` sits.

`--verilog-data-width=4` sets each hex record to four bytes, matching the 32-bit word layout of the testbench RAM.

After both commands:

firmware.elf   ← ELF binary; usable for Spike verification (see benchmarks/spike-checking/)

firmware_syn.hex   ← Verilog hex file, addresses shifted to start at 0x0


The testbench loads it with:

```systemverilog
$readmemh("path/to/firmware_syn.hex", ram);
```

Because addresses now start at `0`, `ram[0]` through `ram[N]` initialize exactly as expected, and the core's first fetch at `0x80000000` maps straight to `ram[0]`.

---

**Method 2: Automated Build via Makefile**

Both steps above are wrapped in the project's Makefiles. You can run the simulation from the repository root:

```bash
# From CVA6-lab/
make <sim-target>
```

Or equivalently, directly from the simulation workspace:

```bash
# From CVA6-lab/sim/
make <sim-target>
```

Where `<sim-target>` can be:
* `post-syn-sim-32`: Runs post-synthesis simulation for CV32A6.
* `post-syn-sim-64`: Runs post-synthesis simulation for CV64A6.

Exact target names are defined in `CVA6-lab/Makefile` and `CVA6-lab/sim/Makefile`. Running `make help` from either directory will list available targets if a help rule is present.

The practical value of this path is **substitutability**. The only file you ever need to touch to simulate a different program is `benchmarks/src/main-syn.S`. Replace its contents with any valid RV32IMAC assembly — a multiply sequence, a CSR read, a branch-heavy loop — keep `link-syn.ld` and the output filename unchanged, and the rest of the flow runs without modification. The Makefile recompiles, re-extracts, and the testbench picks up the new hex on the next simulation launch. The handshake mechanism from section 1.1.2 still applies: whatever the program computes, a `sw` to a known address at the end is the signal the testbench FSM waits for.

---

#### 1.1.4 The AXI RAM Testbench

The testbench (`cva6_tb.sv`) has one job: act as a fully-functional AXI subordinate so that the synthesized CVA6 netlist can boot, fetch instructions, and write a result back, all without any real hardware. Everything else in the file — clock generation, reset sequencing, memory initialization — exists in service of that one goal.

---

**Module-level parameters**

```systemverilog
`timescale 1ns / 1ps
```

The testbench runs at 1 ns resolution. The clock period is 10 ns, giving a 100 MHz simulation frequency. All timing discussions below use nanoseconds.

---

**Clock and reset**

```systemverilog
initial clk = 0;
always #5 clk = ~clk;          // 100 MHz

initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
end
```

`rst_n` is active-low. The core is held in reset for 100 ns — ten clock cycles — then released. CVA6 begins its AXI fetch sequence shortly after `rst_n` goes high. Bus activity in practice starts around **2,685,000 ns**, which reflects the number of cycles the core needs to flush its pipeline from reset and issue its first read transaction.

---

**Memory model**

```systemverilog
logic [31:0] ram [0:16383];    // 64 KB, word-addressed
```

The RAM is 16,384 words of 32 bits each, giving 64 KB total. It is word-addressed: index `0` holds bytes `[3:0]` of the firmware image, index `1` holds bytes `[7:4]`, and so on.

Initialization happens in two steps:

```systemverilog
initial begin
    for (int i = 0; i < 16384; i++) ram[i] = 32'h0;
    $readmemh("../../sim/firmware_syn.hex", ram);
end
```

The explicit zero-fill before `$readmemh` matters. Any word not written by the hex file remains zero, which is a valid (though useless) instruction — `addi x0, x0, 0`. This prevents undefined-value propagation into the instruction decoder.

The path `../../sim/firmware_syn.hex` is relative to wherever Vivado launches simulation. Section 1.1.3 explains how the address-shifted hex file is produced so that `ram[0]` correctly holds the first instruction at `0x80000000`.

The addressing logic used everywhere in the FSMs below is `ram[addr[15:2]]`. Bits `[1:0]` are the byte offset within a word (dropped because the RAM is word-aligned) and bits `[15:2]` are the 14-bit word index into the 16 K-word array.

---

**AXI read channel — the fetch path**

CVA6 issues AXI read transactions to fetch instructions. The testbench handles them with a two-state FSM:

AR_IDLE  ──(ar_valid && ar_ready)──►  R_DATA
R_DATA   ──(r_valid && r_ready && r_last)──►  AR_IDLE


**`AR_IDLE`**

The testbench holds `ar_ready = 1` continuously in this state, meaning it accepts address requests immediately with no latency. When `ar_valid` asserts and the handshake completes, it captures:

- `r_addr ← ar_addr` — the starting address
- `r_len  ← ar_len`  — the burst length (`ARLEN`; 0 means one beat)
- `r_id   ← ar_id`   — the transaction ID, echoed back on the R channel
- `r_cnt  ← 0`       — beat counter reset

It then moves to `R_DATA`, drives `r_valid = 1`, and sets `r_last = (r_len == 0)` — if the burst is a single beat, the first beat is also the last.

**`R_DATA`**

Each cycle where `r_valid && r_ready` both assert, a beat is consumed. The testbench checks `r_last`:

- If `r_last` is set: the burst is complete. FSM returns to `AR_IDLE`, `ar_ready` returns to 1.
- Otherwise: `r_addr += 8` (AXI data width is 64 bits, so the address advances by 8 bytes per beat), `r_cnt` increments, and `r_last` is re-evaluated as `(r_cnt + 1 == r_len)`.

**Read data assembly**

The data path is a combinational assign:

```systemverilog
assign noc_r_data = (r_state == R_DATA)
    ? {ram[r_addr[15:2] + 1], ram[r_addr[15:2]]}
    : 64'b0;
```

Because the AXI data bus is 64 bits wide and the RAM words are 32 bits, each beat concatenates two adjacent words. `ram[r_addr[15:2]]` provides the low 32 bits; `ram[r_addr[15:2] + 1]` provides the high 32 bits. This gives a little-endian 64-bit word aligned to the AXI bus width.

When not in `R_DATA`, the output drives zero rather than X, which keeps the waveform readable.

---

**AXI write channel — the result path**

CVA6 issues AXI write transactions when the firmware executes `sw`. The testbench handles them with a three-state FSM:

AW_IDLE  ──(aw_valid && aw_ready)──►  W_DATA
W_DATA   ──(w_valid && w_ready && w_last)──►  B_RESP
B_RESP   ──(b_valid && b_ready)──►  AW_IDLE


**`AW_IDLE`**

`aw_ready = 1`. On address handshake, captures `w_addr ← aw_addr` and `w_id ← aw_id`, then moves to `W_DATA` with `w_ready = 1`.

**`W_DATA`**

This state performs the actual write, with byte-granularity support via `WSTRB`:

```systemverilog
if (w_strb[0]) ram[w_addr[15:2]][7:0]   <= w_data[7:0];
if (w_strb[1]) ram[w_addr[15:2]][15:8]  <= w_data[15:8];
if (w_strb[2]) ram[w_addr[15:2]][23:16] <= w_data[23:16];
if (w_strb[3]) ram[w_addr[15:2]][31:24] <= w_data[31:24];
// strobes [4..7] write ram[w_addr[15:2] + 1] similarly
```

The byte-enable logic is there to correctly handle `sb` and `sh` instructions, not just `sw`. For the full 32-bit store the firmware executes (`sw x3, 0(x4)`), `w_strb` will be `8'hFF` (all eight bytes enabled) and both adjacent RAM words are updated.

When `w_last` asserts on the same handshake, the FSM moves to `B_RESP`, clears `w_ready`, and raises `b_valid`. For burst writes, `w_addr += 8` and the beat counter advances before the last beat arrives.

**`B_RESP`**

The write response channel. `b_valid = 1` with `b_id = w_id` (the same transaction ID that arrived on the AW channel). When the manager asserts `b_ready` and the handshake completes, the FSM returns to `AW_IDLE`.

`b_resp = 2'b00` is hardwired to OKAY — the testbench never generates SLVERR or DECERR.

---

**The handshake in practice**

The firmware's `sw x3, 0(x4)` targets `0x80001000`. After the address shift, that maps to RAM word index `0x400` (word 1024 out of 16384). After the write FSM processes the transaction, `ram[0x400]` will hold `0x0000_001E`. The AXI write channel is the only observable output from the firmware — inspecting `ram[0x400]` in the waveform, or watching `noc_w_data[31:0]` when `noc_w_valid` asserts, is how you confirm the core executed correctly.

---

**CVA6 instantiation**

The DUT is instantiated at the bottom of the file:

```systemverilog
cva6 u_cva6 (
    .clk_i         (clk),
    .rst_ni        (rst_n),
    .boot_addr_i   (32'h8000_0000),
    .hart_id_i     (64'h0),
    .irq_i         (2'b0),
    .ipi_i         (1'b0),
    .time_irq_i    (1'b0),
    .debug_req_i   (1'b0),
    // AXI channels via escaped identifiers:
    .\noc_req_o[ar_valid]     (ar_valid),
    .\noc_req_o[ar_bits_addr] (ar_addr),
    // ...
    .\noc_resp_i[r][data]     (noc_r_data),
    .\noc_resp_i[r][valid]    (r_valid),
    // ...
);
```

`boot_addr_i = 0x80000000` is what sends the core's first fetch to `ram[0]`. All interrupt lines are tied off. The CVXIF coprocessor interface is fully disabled — `compressed_ready`, `issue_ready`, `accept`, and `result_valid` are all driven zero, telling the core that no coprocessor exists and it should handle every instruction itself.

The escaped-identifier connections (`.\noc_req_o[ar_valid]`, `.\noc_resp_i[r][data]`) are exactly the flattened port names extracted from the synthesized netlist, as described in section 1.1.1. Each one maps a scalar net from the flat netlist onto a named wire in the testbench.

---

**Termination**

There is no `$finish`, no timeout counter, and no self-checking assertion in the testbench. The simulation runs until you stop it. This is intentional: the firmware parks in `j loop` after writing the result, and the testbench has nothing to react to. The expected workflow is to run the simulation, observe the AXI write transaction in the waveform viewer, confirm `noc_w_data[31:0] = 0x0000_001E` when `noc_w_valid` asserts, then stop manually. Section 1.3 covers reading those waveforms in detail.

---

### 1.2 Elaboration and Simulation in XSIM

#### Vivado GUI Flow

In the **Flow Navigator** (left panel), click **Run Simulation → Run Post-Synthesis Functional Simulation**. Vivado elaborates the synthesized netlist and opens the simulator window. Add signals from the **Scope/Objects** panel to the waveform viewer, then click **Run All** (or press `F3`).

The testbench has no `$finish` — the simulation runs indefinitely. Stop it manually once you have seen what you need in the waveform.

#### Makefile (Batch Mode)

Running `make post-syn-sim-32` or `make post-syn-sim-64` launches Vivado in batch mode with no GUI. The waveform database is written to:

<project_root>/<project_name>.sim/sim_1/synth/func/xsim/


To inspect it, open Vivado separately and use **File → Open Waveform Database**, then load the `.wdb` file from that path.

---

### 1.3 Waveform Inspection

The simulation is only as useful as your ability to read its output. This section walks through the waveform in the order events actually occur: a long quiet boot phase, a burst of AXI read activity as the core fetches the firmware, and finally a single AXI write transaction that carries the computed result. That write is the pass/fail signal for the entire flow.

---

#### Optional sanity check: the schematic view

Before diving into waveforms, the synthesized design itself can be inspected. With the synthesized design open, the **Schematic** view shows the flattened netlist structure — a useful confirmation that synthesis actually produced a populated design rather than an optimized-away shell:

![Synthesized Design - Schematic View](schematic-synthesized-design.png)

*Figure 1: Schematic view of the synthesized CVA6 netlist. The cell/net counts in the toolbar (98 cells, 5,320 nets on the first page of 12) confirm a real, populated design.*

This step is not required for simulation; skip it if you only care about functional verification.

---

#### Signals worth adding

The flattened netlist exposes thousands of nets, but only a handful matter for this test. From the **Objects** panel, add the testbench-level signals — they are already named cleanly because they live in `cva6_tb.sv`, not in the flattened DUT:

| Group | Signals | What they tell you |
|---|---|---|
| Control | `clk`, `rst_n` | Reset release at 100 ns |
| AXI read address | `noc_ar_valid`, `noc_ar_addr`, `noc_ar_len`, `noc_ar_ready` | Fetch requests from the core |
| AXI read data | `noc_r_valid`, `noc_r_data`, `noc_r_last`, `noc_r_ready` | Instructions returned by the RAM |
| Read FSM | `r_state`, `r_addr`, `r_cnt` | Testbench-side view of each burst |
| AXI write | `noc_aw_valid`, `noc_aw_addr`, `noc_w_valid`, `noc_w_data`, `noc_w_last` | The result write — the signal that matters |

Adding the testbench FSM state (`r_state`) is the single most useful debugging aid: it renders as a named enum (`AR_IDLE`, `R_DATA`) in the viewer, so you can see burst boundaries without decoding handshakes by eye.

---

#### Phase 1: The quiet boot window

Do not expect activity immediately after reset. `rst_n` releases at 100 ns, but the first AXI read transaction does not appear until approximately **2,685,100 ns**:

![Post-Synthesis Simulation - Boot Activity](post-synthesis-simulation-1.png)

*Figure 2: Full simulation window. The bus stays idle for the first ~2.68 ms of simulated time; the burst of transitions on the `noc_ar_*` / `noc_r_*` channels and `r_state` leaving `AR_IDLE` marks the start of instruction fetch.*

This is the point where an impatient user concludes the simulation is broken and kills it. It is not broken. Run for at least **3,000,000 ns** (`run 3000000 ns` in the Tcl console, or several presses of `F3` with the default 6,500 ns step increased) before drawing any conclusions. If the bus is still flat after 3 ms of simulated time, *then* something is wrong — the usual suspects are a missing or mis-pathed `firmware_syn.hex` (all-zero RAM) or a `boot_addr_i` mismatch.

---

#### Phase 2: Instruction fetch

Once fetch begins, the read channel shows a repeating pattern that maps directly onto the testbench FSM from section 1.1.4:

1. `noc_ar_valid` pulses with an address in the `0x8000_00xx` range — the core requesting instructions.
2. `r_state` transitions `AR_IDLE → R_DATA`.
3. `noc_r_data` presents concatenated 64-bit words (two adjacent RAM entries per beat) while `noc_r_valid` is high.
4. `noc_r_last` closes the burst; `r_state` returns to `AR_IDLE`.

The addresses on `noc_ar_addr` should walk through the firmware image. Given how short the program is, only a few fetch bursts occur before the core reaches the `j loop` parking instruction — after which fetch activity becomes a tight repeating pattern (or stops entirely if the loop is served from the instruction cache).

---

#### Phase 3: The result write — pass/fail

The verification criterion is a single AXI write transaction. Scroll (or search for a transition on `noc_w_valid`) past the fetch activity:

![Post-Synthesis Simulation - Result Write](post-synthesis-simulation-2.png)

*Figure 3: The result write. When `noc_w_valid` asserts, `noc_w_data[63:0]` carries `0x0000001e_0000001e` — the value 30 (0x1E) produced by `add x3, x1, x2` and stored by `sw x3, 0(x4)` to address `0x80001000`.*

Three things to check on this transaction:

- **`noc_aw_addr` = `0x0000_0000_8000_1000`** — the store target from the firmware. Any other address means the core executed something unexpected.
- **`noc_w_data` = `0x0000001e_0000001e`** — the expected value `0x1E` appears in both halves because the testbench RAM assembles 64-bit beats from two adjacent 32-bit words; the low 32 bits are the ones the `sw` actually wrote and the strobes select.
- **`noc_w_last` high on the same beat** — a single-beat burst, matching a lone `sw`.

Seeing this transaction is the definition of success for the entire flow: the synthesized netlist booted, fetched real instructions over AXI, executed them, and wrote the correct arithmetic result back over the bus. Once observed, stop the simulation manually — the firmware is parked in `j loop` and nothing further will happen.

---

## 2. Developer Simulation Flow (cva6.py + Verilator + Spike)

### 2.1 Running the Default Test Suite
### 2.2 Custom C and Assembly Programs
### 2.3 Waveform Generation (`.vcd` / `.fst`)
### 2.4 GTKWave Debugging
### 2.5 HTIF Protocol (`tohost` / `fromhost`)

---

## 3. Manual Simulation from Scratch (Standalone Verilator)
### 3.1 Dependency Generation via Bender
### 3.2 CVA6 AXI Wrapper (`cva6_axi_wrapper.sv`)
### 3.3 Spike as Instruction-Level Reference (`--log-commits`)
### 3.4 Firmware and Linker Script (`main.S`, `link.ld`)
### 3.5 Self-Checking C++ Testbench (`tb_cva6.cpp`)
### 3.6 Makefile Automation
### 3.7 Issue Stage Deep Dive (Scoreboard, RAW Hazards, Dual-Issue, Waveform Tracing)
