# CVA6 Vivado Synthesis

This document covers the complete synthesis flow for CVA6 on Vivado, from project creation through resource and timing analysis. The workflow targets four processor configurations across 32-bit and 64-bit variants, with single-issue and dual-issue pipelines.

---

## 1. Project Creation

This section covers creating a Vivado synthesis project for CVA6. Because CVA6 is 
a large and complex design, direct behavioral simulation using Vivado's built-in 
xsim on typical workstations will often fail with an out-of-memory error; a reliable 
Vivado-centric workflow is to synthesize first and then run post-synthesis functional 
simulation, which operates on an optimized netlist that requires significantly less 
RAM. Two paths are documented: using the official CVA6 repository with Bender (1.1) 
and using the project's Makefile flow (1.2). Both assume that the tools described 
in the environment setup guide are already installed.

### 1.1 Using the Official CVA6 Repository

This method generates a Vivado project directly from the CVA6 source tree using
Bender's TCL script export. All commands run from the repository root.

> **Validated on commit:** `41e30493046e7719ff59b77af5a6f0e436066a55`

#### Step 1 — Generate the source file list

Use Bender to produce a Vivado-compatible TCL script for your target configuration:
```bash
bender script vivado -t <target> > cva6_files.tcl
```

Replace `<target>` with one of the following:

| Target | Description | ISA Extensions |
|--------|-------------|----------------|
| `cv32a65x` | 32-bit RISC-V core (lightweight) | RV32IMAC |
| `cv32a6_imac_sv32` | 32-bit with virtual memory | RV32IMAC + Sv32 MMU |
| `cv64a6_imafdc_sv39` | 64-bit full-featured core (most complex) | RV64IMAFDC + Sv39 MMU |

The script collects all RTL source paths required for the selected configuration.
If Bender reports an unknown target, verify your submodule state:

```bash
git submodule status
```

Missing `common_cells` or `tech_cells_generic` will cause synthesis to fail.

#### Step 2 — Create the Vivado project

Open Vivado and source the generated script. Either use the menu:

**Tools → Run Tcl Script → select `cva6_files.tcl`**

or paste directly into the Tcl Console:

```tcl
source cva6_files.tcl
```

Vivado creates a new project with `cva6` as the top-level module in the current
working directory.

#### Step 3 — Run synthesis

In the Flow Navigator, click **Run Synthesis**. Depending on the target and host
hardware, synthesis takes roughly **10–30 minutes**.

Once complete, open **Open Synthesized Design** to inspect the schematic,
utilization report, and timing summary. Post-synthesis functional simulation is
also available from the Flow Navigator at this point.

---



### 1.2 Using the Project Makefile Flow

The repository provides a root `Makefile` that automates both GUI-based project creation and batch-mode logic synthesis, eliminating manual steps in Vivado. All synthesis targets navigate to `fpga/build/` and execute Vivado with non-interactive TCL scripts located under `fpga/vivado/`.

#### Summary of Makefile Targets

| Target | Execution Mode | Target Core Configuration | TCL Script Source |
| :--- | :--- | :--- | :--- |
| `make cva6-32` | GUI Project Generation | `cv32a6_imac_sv32` (32-bit + Sv32 MMU) | `fpga/vivado/cv32a6_imac_sv32.tcl` |
| `make cva6-64` | GUI Project Generation | `cv64a6_imafdc_sv39` (64-bit + Sv39 MMU) | `fpga/vivado/cv64a6_imafdc_sv39.tcl` |
| `make synth-32` | Non-Interactive Batch Synthesis | `cv32a6_imac_sv32` (32-bit + Sv32 MMU) | `fpga/vivado/cv32a6_imac_sv32_syn.tcl` |
| `make synth-64` | Non-Interactive Batch Synthesis | `cv64a6_imafdc_sv39` (64-bit + Sv39 MMU) | `fpga/vivado/cv64a6_imafdc_sv39.tcl` |

---

#### Out-of-Context (OOC) Synthesis Strategy

Synthesizing a processor core like CVA6 directly as a top-level design causes Vivado's place-and-route tools to fail with severe **IO Placement errors**. Because CVA6 is an IP core embedded within an SoC macro rather than a standalone FPGA chip with physical package pins, its hundreds of top-level signal lines cannot be mapped directly to physical FPGA package I/O buffers (IBUFs/OBUFs).

To bypass physical I/O buffer insertion and facilitate static timing analysis (STA), the automated scripts configure Vivado for **Out-of-Context (OOC)** synthesis:

1. **Clock Constraint Integration:** The OOC constraint file (`fpga/constraints/cva6_ooc.xdc`) is added to the active constraint set (`constrs_1`). This defines the fundamental virtual clock source (`clk_i`) necessary for timing closure analysis without requiring board-level physical pin mappings.
2. **OOC Mode Flag Insertion:** The synthesis run is configured with the `-mode out_of_context` option via Vivado TCL properties, instructing the compiler to synthesize the core in isolation:
   ```tcl
   set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
   ```
3. **Automated Reporting Pipeline:** Upon completion, the synthesized design is opened in memory, generating hardware resource utilization and static timing analysis reports directly into the build directory (`fpga/build/`).

---

#### Step-by-Step Batch Synthesis Execution

To run fully automated synthesis for a target architecture, run one of the following commands from the project root directory:

```bash
# For 32-bit RISC-V core synthesis (RV32IMAC + Sv32 MMU)
make synth-32

# For 64-bit RISC-V core synthesis (RV64IMAFDC + Sv39 MMU)
make synth-64
```

##### Automated TCL Execution Sequence

When executing `make synth-32` or `make synth-64`, Vivado executes the underlying automation flow defined in the TCL scripts:

```tcl
# 1. Attach Out-of-Context timing constraints
add_files -fileset constrs_1 -norecurse $ROOT/../fpga/constraints/cva6_ooc.xdc
set_property USED_IN {synthesis implementation out_of_context} [get_files $ROOT/../fpga/constraints/cva6_ooc.xdc]

# 2. Configure synthesis run to bypass I/O buffer allocation
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

# 3. Launch multi-threaded synthesis run
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# 4. In-memory design evaluation & report generation
open_run synth_1 -name synth_1
report_utilization -file $ROOT/../fpga/build/vivado_prj_cv32a6/utilization_report.txt
report_timing_summary -file $ROOT/../fpga/build/vivado_prj_cv32a6/timing_summary_report.txt
```

---

#### Generated Outputs & Verification

Upon successful completion of the batch synthesis flow, all generated outputs are placed in the `fpga/build/` directory structure:

* **Resource Utilization Report:** Saved to `fpga/build/vivado_prj_<target>/utilization_report.txt`. Contains detailed metrics on Look-Up Tables (LUTs), Flip-Flops (FFs), Block RAM (BRAM), and DSP slice consumption.
* **Static Timing Analysis Report:** Saved to `fpga/build/vivado_prj_<target>/timing_summary_report.txt`. Details Slack values (WNS/TNS) and maximum attainable clock frequency ($F_{max}$).

---

## 2. Processor Configuration

Unlike traditional RTL designs that expose dozens of independent parameters at the top-level entity, CVA6 relies on a centralized SystemVerilog configuration package architecture. The top-level module (`cva6.sv`) accepts a single configuration structure instance, `CVA6Cfg` (of type `config_pkg::cva6_cfg_t`). All datapath bit-widths, pipeline depths, memory interfaces, and architectural extensions are statically derived from this structure during synthesis elaboration.

The processor features two baseline reference targets:
* **CV32A6-IMAC-SV32:** 32-bit integer configuration with Sv32 MMU.
* **CV64A6-IMAFDC-SV39:** 64-bit full application-class core with double-precision FPU and Sv39 MMU.

Modifying the core's microarchitecture or ISA features requires updating the parameter assignments within the respective target package rather than modifying the core logic modules directly.

### 2.0 Locating and Modifying Configuration Packages

Configuration parameters are defined in standalone SystemVerilog packages located in the repository at:
* `core/include/cv32a6_imac_sv32_config_pkg.sv`
* `core/include/cv64a6_imafdc_sv39_config_pkg.sv`

Depending on whether you work via the Vivado GUI or the command line, locate and modify these files as follows:

#### A. Via Vivado GUI
1. In the **Sources** window, switch from the default **Hierarchy** view to the **Libraries** tab at the bottom.
2. Expand **Design Sources** $\rightarrow$ **SystemVerilog** $\rightarrow$ **xil_defaultlib**.
3. Locate the configuration package corresponding to your active design:
   * `cv32a6_imac_sv32_config_pkg.sv` (for 32-bit builds)
   * `cv64a6_imafdc_sv39_config_pkg.sv` (for 64-bit builds)
4. Double-click the file to open it in Vivado's integrated text editor, modify the targeted configuration parameters in the `cva6_cfg` struct, and save the file before launching synthesis.

#### B. Via CLI / Headless Flow
Edit the packages directly using any text editor prior to running the batch synthesis targets (`make synth-32` or `make synth-64`):

```bash
# Example: Edit 32-bit configuration directly
nano rtl/core/include/cv32a6_imac_sv32_config_pkg.sv

# Example: Edit 64-bit configuration directly
nano rtl/core/include/cv64a6_imafdc_sv39_config_pkg.sv
```

> **Note:** Whenever parameters within these packages are modified, Vivado invalidates previous out-of-context synthesis runs, requiring a full re-synthesis to update the generated netlist and timing reports.

### 2.1 Datapath Width Parameters (`XLEN` and `VLEN`)

The two parameters that define the fundamental data width of the CVA6 pipeline are `XLEN` and `VLEN`. Both are assigned directly within the target configuration package and propagate throughout the core at elaboration time.

```verilog
// cv32a6_imac_sv32_config_pkg.sv
localparam CVA6ConfigXlen = 32;
...
XLEN: unsigned'(CVA6ConfigXlen),   // → 32
VLEN: unsigned'(32),


// cv64a6_imafdc_sv39_config_pkg.sv
localparam CVA6ConfigXlen = 64;
...
XLEN: unsigned'(CVA6ConfigXlen),   // → 64
VLEN: unsigned'(64),
```

---

#### XLEN — Integer Register and Datapath Width

`XLEN` sets the width of every general-purpose register, ALU operand path, and load/store data bus inside the core. Changing this value restructures the synthesized datapath at elaboration time:

- **`XLEN = 32`**: Generates 32-bit register files, 32-bit ALU datapaths, and 32-bit load/store paths. Immediate fields, PC logic, and branch target computation all operate at 32-bit precision. This directly corresponds to the RV32I base and the smaller combinational depth seen in the 32-bit synthesis results (3.2).
- **`XLEN = 64`**: Doubles the width of every internal data register and arithmetic path. The additional bit range required for 64-bit multiply, divide, and shift operations contributes to the larger LUT footprint and increased logic-level depth seen in the 64-bit configurations.

The `FetchUserWidth` and `DataUserWidth` fields in `cva6_cfg` are also tied to `CVA6ConfigXlen`, so custom user-sideband signals on the fetch and data buses track the core width.

---

#### VLEN — Virtual Address Width

`VLEN` defines the bit width of virtual addresses presented to the MMU and TLB arrays. In both reference targets it is set equal to `XLEN`:

| Target | `XLEN` | `VLEN` | MMU Mode |
|:---|:---:|:---:|:---:|
| CV32A6-IMAC-SV32 | 32 | 32 | Sv32 |
| CV64A6-IMAFDC-SV39 | 64 | 64 | Sv39 |

For the 64-bit Sv39 target, the canonical virtual address space is 39 bits. Setting `VLEN = 64` means the pipeline carries full 64-bit pointers internally, and the Sv39 page-table walker simply ignores the upper bits. This is a deliberate design choice — it avoids conditional width logic in the fetch and memory-access stages at the cost of slightly wider internal flip-flops, a tradeoff that favors RTL simplicity over minimal area.

---

#### AXI Interface Width — Does Not Track XLEN

A common assumption is that narrowing `XLEN` to 32 also narrows the memory interface. It does not. Both targets set the AXI bus to 64-bit, as verified in both configuration files:

```
AxiAddrWidth: 64,
AxiDataWidth: 64,
AxiIdWidth:   4,
```

The external AXI4 interface is always 64-bit regardless of the core's integer datapath width. On the Genesys 2 target, the MIG memory controller and interconnect fabric operate at 64-bit in both synthesis configurations. The 32-bit build does not generate a narrower bus — it only generates a narrower core.

---

> **Configuration note:** `XLEN` and `VLEN` are not standalone `localparam`s that can be patched in isolation. They are struct fields inside `cva6_user_cfg_t`, assigned from `CVA6ConfigXlen` in the target package. Changing `CVA6ConfigXlen` in `cv32a6_imac_sv32_config_pkg.sv` or `cv64a6_imafdc_sv39_config_pkg.sv` is the correct and only supported way to modify datapath width; the core logic in `cva6.sv` and its submodules derives all widths statically from `CVA6Cfg.XLEN` at elaboration. Any change here invalidates the existing synthesis run and requires a full re-synthesis.

### 2.2 Issue Control, Scoreboard Depth, and Execution Pipeline Parameters

The parameters governing CVA6's execution bandwidth, in-flight instruction tracking, and load/store pipeline staging are distributed across both hardcoded literal assignments and `localparam`-backed fields within the configuration struct. Both reference targets carry identical values for all parameters in this group.

```verilog
// Values identical in both cv32a6_imac_sv32_config_pkg.sv and cv64a6_imafdc_sv39_config_pkg.sv

// Hardcoded literals — no backing localparam in either file:
SuperscalarEn:        bit'(0),        // cv32: line 79  | cv64: line 84
ALUBypass:            bit'(0),        // cv32: line 80  | cv64: line 85
NrCommitPorts:        unsigned'(2),   // cv32: line 81  | cv64: line 86
MaxOutstandingStores: unsigned'(7),   // cv32: line 140 | cv64: line 145

// localparam-backed fields:
localparam CVA6ConfigNrScoreboardEntries = 8;  // cv32: line 51 | cv64: line 56
localparam CVA6ConfigNrLoadPipeRegs      = 1;  // cv32: line 53 | cv64: line 58
localparam CVA6ConfigNrStorePipeRegs     = 0;  // cv32: line 54 | cv64: line 59
localparam CVA6ConfigNrLoadBufEntries    = 2;  // cv32: line 55 | cv64: line 60
```

---

#### SuperscalarEn — Issue Width and Pipeline Structure

`SuperscalarEn` is the single most structurally consequential flag in the configuration package. It is not a simple enable bit for one hardware path — setting it to `1` restructures three separate pipeline stages at elaboration time:

- **Decode stage:** A second decode lane is instantiated. The decode logic gains the combinational hazard checks required to determine whether two fetched instructions constitute a valid issue pair: structural hazard detection, WAW/WAR dependency checking across both instructions, and alignment constraints on the instruction types that can be paired.
- **Issue stage and Scoreboard:** The scoreboard must now arbitrate two simultaneous issue ports and two simultaneous write-back ports. The operand forwarding network expands from $O(N)$ comparators to $O(2N)$ comparators, where $N$ is `NrScoreboardEntries`. This growth in fan-in on the scoreboard wake-up and bypass logic is the primary reason enabling dual-issue tightens the critical timing path — the issue stage becomes the new bottleneck, as reflected in the timing analysis (3.2).
- **Commit stage:** Two results may retire per cycle, requiring the commit bus and architectural register file write ports to support concurrent updates.

**In both current reference builds, `SuperscalarEn = 0`.** CV32A6-IMAC-SV32 and CV64A6-IMAFDC-SV39 are single-issue cores. All synthesis and timing data reported in 3 reflect single-issue configurations.

---

#### NrCommitPorts — Commit Bandwidth

```verilog
NrCommitPorts: unsigned'(2),   // hardcoded literal in both files
```

`NrCommitPorts` sets how many instruction results can retire to the architectural register file per clock cycle. It is configured to `2` in both reference builds despite `SuperscalarEn = 0`. This is valid — the second port is unused under single-issue operation, but the RTL is elaborated with the wider commit bus regardless of `SuperscalarEn`.

> When planning to enable `SuperscalarEn`, `NrCommitPorts` must be consistent with the intended issue width. A single commit port paired with `SuperscalarEn = 1` creates a structural throughput bottleneck: instructions can be decoded and issued two at a time but can only retire one at a time, saturating the scoreboard and defeating the purpose of dual-issue.

---

#### ALUBypass — Result Forwarding Control

```verilog
ALUBypass: bit'(0),   // hardcoded literal in both files
```

`ALUBypass` controls whether an ALU result can be forwarded directly from the execution stage output to a dependent instruction's input operand within the same or following cycle, bypassing the register file read-back path. With `ALUBypass = 0`, all results are committed through the scoreboard before becoming visible to dependent instructions.

Disabling bypass increases stall cycles on data-dependent instruction sequences but removes the combinational forwarding multiplexer from the operand-selection path, which can ease timing closure on constrained FPGA implementations. This is the conservative choice for the Genesys 2 targets.

---

#### NrScoreboardEntries — In-Flight Instruction Window

```verilog
localparam CVA6ConfigNrScoreboardEntries = 8;
// → NrScoreboardEntries: unsigned'(CVA6ConfigNrScoreboardEntries)
```

The scoreboard tracks every instruction currently in flight between the issue stage and commit. An 8-entry window means the core can hold up to 8 outstanding instructions simultaneously. Increasing this value grows the associative lookup arrays used for hazard detection — every new issue request must be compared against all in-flight entries — directly increasing LUT consumption and deepening the critical path through the issue stage.

The 8-entry depth is shared across both reference targets. This is a conservative but appropriate setting for FPGA synthesis: deeper scoreboards yield diminishing returns under the memory-latency profile of the Genesys 2 platform, where cache miss penalties are the dominant stall cause rather than in-order issue conflicts.

---

#### NrLoadPipeRegs and NrStorePipeRegs — LSU Pipeline Staging

```verilog
localparam CVA6ConfigNrLoadPipeRegs  = 1;   // → NrLoadPipeRegs:  int'(1)
localparam CVA6ConfigNrStorePipeRegs = 0;   // → NrStorePipeRegs: int'(0)
```

These parameters insert additional registered pipeline stages into the load and store paths through the Load/Store Unit (LSU).

- **`NrLoadPipeRegs = 1`:** One pipeline register is inserted on the load return path, adding one cycle of latency to load operations in exchange for a shorter combinational arc between the D$ output and the writeback stage. On FPGA targets, the chain from data cache output through load-use bypass and into the register file write is often on or near the critical path; this register break is essential for reaching the target $F_{max}$.
- **`NrStorePipeRegs = 0`:** No additional register stage on the store path. Stores do not feed dependent instructions directly, so they are less latency-sensitive, and the store path is typically not the critical timing arc.

---

#### NrLoadBufEntries and MaxOutstandingStores — Memory Queue Depth

```verilog
localparam CVA6ConfigNrLoadBufEntries = 2;
// → NrLoadBufEntries: unsigned'(CVA6ConfigNrLoadBufEntries)

MaxOutstandingStores: unsigned'(7),   // hardcoded literal, no backing localparam
```

`NrLoadBufEntries` sets the depth of the load queue, which holds load requests that are pending a cache response or are stalled behind an unresolved store to the same address. At depth 2, the core tolerates a limited number of simultaneous outstanding cache misses before backpressure reaches the issue stage.

`MaxOutstandingStores` caps the number of stores that can be buffered in the store queue before the LSU asserts backpressure toward issue. At 7 entries, this matches a common FPGA target tuning where the store buffer is sized to absorb short bursts of consecutive stores without stalling. Unlike the load buffer depth, `MaxOutstandingStores` has no backing `localparam` in either file — the value `7` is a hardcoded literal inside the struct assignment. Any modification requires editing the literal directly at line 140 in `cv32a6_imac_sv32_config_pkg.sv` or line 145 in `cv64a6_imafdc_sv39_config_pkg.sv`.

---

> **Configuration note:** `SuperscalarEn`, `ALUBypass`, `NrCommitPorts`, and `MaxOutstandingStores` are hardcoded literals inside the `cva6_user_cfg_t cva6_cfg = '{...}` struct body in both target packages — no `localparam` aliases exist for them. Modifying these requires editing the struct assignment directly. The remaining four parameters (`NrScoreboardEntries`, `NrLoadPipeRegs`, `NrStorePipeRegs`, `NrLoadBufEntries`) are defined as `localparam` values first and then referenced in the struct, making them the preferred modification points. Any change to parameters in this group invalidates the current synthesis run and requires a full re-synthesis.

---

### 2.3 ISA Extension Flags and Functional Unit Instantiation

Each extension flag in the target configuration package directly controls whether a hardware module is instantiated during synthesis elaboration. When a flag is `0`, the corresponding RTL block is excluded from the netlist entirely — not clock-gated, not tied off, absent. When `1`, the full macro is elaborated and synthesized.

---

#### Two-Tier Configuration Architecture

- **`core/include/config_pkg.sv`** defines the `cva6_cfg_t` struct type and the global default instance `cva6_default_cfg`. Every parameter the core exposes is a named struct field here. This file is shared across all targets and must not be modified for target-specific customization.

- **`cv32a6_imac_sv32_config_pkg.sv`** and **`cv64a6_imafdc_sv39_config_pkg.sv`** each declare a local `cva6_user_cfg_t cva6_cfg = '{ ... }` instance. Every field assignment within this struct body overrides the base default for that specific target. `localparam` values declared earlier in the same file are aliased into the struct here.

Editing a flag in one target package affects only that target. The base `config_pkg.sv` remains untouched, and the other target build is unaffected. Because these values are resolved during static elaboration, any change requires a full re-synthesis.

---

#### Complete Flag Map

| Flag | CV32A6-IMAC-SV32 | CV64A6-IMAFDC-SV39 | Source Type |
|:---|:---:|:---:|:---|
| `RVF` | 0 | 1 | `localparam CVA6ConfigRVF` |
| `RVD` | 0 | 1 | `localparam CVA6ConfigRVD` |
| `XF16` | 0 | 0 | `localparam CVA6ConfigF16En` |
| `XF16ALT` | 0 | 0 | `localparam CVA6ConfigF16AltEn` |
| `XF8` | 0 | 0 | `localparam CVA6ConfigF8En` |
| `XFVec` | 0 | 0 | `localparam CVA6ConfigFVecEn` |
| `RVC` | 1 | 1 | `localparam CVA6ConfigCExtEn` |
| `RVA` | 1 | 1 | `localparam CVA6ConfigAExtEn` |
| `RVB` | 1 | 1 | cv32: hardcoded `bit'(1)` / cv64: `localparam CVA6ConfigBExtEn` |
| `RVS` | 1 | 1 | hardcoded literal (both files) |
| `RVU` | 1 | 1 | hardcoded literal (both files) |
| `CvxifEn` | 0 | 1 | `localparam CVA6ConfigCvxifEn` |
| `RVZCB` | 0 | 1 | `localparam CVA6ConfigZcbExtEn` |
| `RVZiCond` | 0 | 1 | `localparam CVA6ConfigRVZiCond` |
| `FpgaEn` | 0 | 0 | hardcoded `bit'(0)` (both files) |
| `NrPMPEntries` | 8 | 8 | `localparam CVA6ConfigNrPMPEntries` |

**Flags that differ between targets:** `RVF`, `RVD`, `CvxifEn`, `RVZCB`, `RVZiCond`. All others are identical in both reference builds.

---

#### Floating-Point Unit — `RVF`, `RVD`, and the `fpnew` Macro

```verilog
// cv32a6_imac_sv32_config_pkg.sv
localparam CVA6ConfigRVF = 0;   // line 14
localparam CVA6ConfigRVD = 0;   // line 15
RVF: bit'(CVA6ConfigRVF),       // → 0
RVD: bit'(CVA6ConfigRVD),       // → 0

// cv64a6_imafdc_sv39_config_pkg.sv
localparam CVA6ConfigRVF = 1;   // line 14
localparam CVA6ConfigRVD = 1;   // line 15
RVF: bit'(CVA6ConfigRVF),       // → 1
RVD: bit'(CVA6ConfigRVD),       // → 1
```

`RVF` and `RVD` carry the largest individual synthesis footprint in this configuration set. When either is `1`, the `fpnew` macro is instantiated — including `fpnew_cast_multi` and `fpnew_fma_multi` submodules, which synthesize to a dense network of carry-save adders and DSP slices. On the Genesys 2, the FPU normalization tree becomes the dominant timing arc, which is the primary reason for the lower $F_{max}$ observed in the 64-bit results (3.2).

Setting `RVD = 1` without `RVF = 1` is not a valid RISC-V configuration. The CVA6 RTL does not enforce this at elaboration — consistency is the integrator's responsibility.

`XF16`, `XF16ALT`, `XF8`, and `XFVec` are `0` in both reference targets. These gate additional `fpnew` format pipelines (half-, alt-half-, quarter-precision, and vectorized FP). All require `RVF = 1` as a prerequisite and are not analyzed in 3.

---

#### Compressed and Atomic Extensions — `RVC`, `RVA`

```verilog
// Identical in both files:
localparam CVA6ConfigCExtEn = 1;   // cv32: line 21 | cv64: line 23
localparam CVA6ConfigAExtEn = 1;   // cv32: line 23 | cv64: line 25
RVC: bit'(CVA6ConfigCExtEn),       // → 1
RVA: bit'(CVA6ConfigAExtEn),       // → 1
```

`RVC` enables the 16-bit compressed instruction extension. The fetch stage includes a purely combinational decompressor that expands 16-bit instructions to 32-bit canonical form before decode. This adds a small but non-zero combinational delay on the fetch-to-decode path.

`RVA` enables LR/SC and AMO atomic operations, instantiating reservation logic in the LSU and extending the store queue. Both flags are identical in both targets and contribute equally to the LUT/FF baseline.

---

#### Bit Manipulation — `RVB`

```verilog
// cv32a6_imac_sv32_config_pkg.sv (line 94):
RVB: bit'(1),                    // hardcoded literal — no localparam alias

// cv64a6_imafdc_sv39_config_pkg.sv:
localparam CVA6ConfigBExtEn = 1; // line 28
RVB: bit'(CVA6ConfigBExtEn),     // → 1
```

`RVB` adds Zba/Zbb/Zbc/Zbs operations as additional subpaths in the integer ALU. The area impact is distributed rather than concentrated in a single block.

The inconsistency between targets is noteworthy: in the 32-bit package, `1` is hardcoded directly with no backing `localparam`. Disabling `RVB` in the 32-bit target requires editing the struct body at line 94 directly — there is no top-of-file `localparam` to change. This appears to be an oversight and should be documented before any modification attempt.

---

#### Privilege Modes — `RVS`, `RVU`

```verilog
// Identical hardcoded literals in both files:
RVS: bit'(1),   // supervisor mode
RVU: bit'(1),   // user mode
```

Both are hardcoded with no `localparam` backing. `RVS` and `RVU` are required for the MMU: Sv32 and Sv39 page-table walking are only meaningful in supervisor mode. Setting either to `0` would render the MMU inoperable. These values are not expected to be modified in the reference targets.

---

#### CVXIF Coprocessor Interface, Zcb, and ZiCond — `CvxifEn`, `RVZCB`, `RVZiCond`

```verilog
// cv32a6_imac_sv32_config_pkg.sv
localparam CVA6ConfigCvxifEn  = 0;  // line 19
localparam CVA6ConfigZcbExtEn = 0;  // line 22
localparam CVA6ConfigRVZiCond = 0;  // line 25

// cv64a6_imafdc_sv39_config_pkg.sv
localparam CVA6ConfigCvxifEn  = 1;  // line 19
localparam CVA6ConfigZcbExtEn = 1;  // line 24
localparam CVA6ConfigRVZiCond = 1;  // line 27
```

All three are enabled only in the 64-bit target.

- **`CvxifEn`** instantiates the CORE-V eXtension Interface. Additional decode-stage logic scans each instruction for a coprocessor match and, on a hit, offloads it over the CVXIF bus. This extends the decode critical path with an additional comparator layer and adds interface registers for the outbound and inbound buses.

- **`RVZCB`** extends the compressed instruction decompressor table with additional 16-bit load/store and arithmetic variants. Synthesis impact is minimal but non-zero.

- **`RVZiCond`** adds `czero.eqz` and `czero.nez` conditional-zero operations, extending the ALU decode table and adding two execution paths in the ALU output mux.

All three are `localparam`-backed. Enabling any of them in the 32-bit target requires only changing the corresponding `localparam` at the top of `cv32a6_imac_sv32_config_pkg.sv` — no struct-body edits needed.

---

#### Physical Memory Protection — `NrPMPEntries`

```verilog
// Identical in both files:
localparam CVA6ConfigNrPMPEntries = 8;   // cv32: line 66 | cv64: line 71
NrPMPEntries: unsigned'(CVA6ConfigNrPMPEntries),  // → 8
```

8 entries satisfies the RISC-V privileged specification minimum. Each additional entry adds a range comparator to the LSU address-check path and a set of CSR registers. The PMP check sits on the same combinational arc as the TLB output; increasing `NrPMPEntries` lengthens this path and can constrain $F_{max}$. At depth 8, the impact is modest in both builds.

---

#### FpgaEn — FPGA Optimization Hints

```verilog
// Hardcoded in both files:
FpgaEn: bit'(0),   // cv32: line 76 | cv64: line 81
```

`FpgaEn` controls FPGA-specific inference hints throughout the core — BRAM reset behavior, DSP mapping directives, and synchronous-reset guidance. It is `0` in both reference packages, so Vivado's default inference heuristics apply. This is a relevant detail for 2.5 and 3.1: the distributed-RAM spillover observed in the 32-bit cache results is not caused by `FpgaEn = 0`. It is driven by the cache RTL structures themselves, not by these hint flags.

---

#### Modification Summary

| Modification path | Method |
|:---|:---|
| `localparam`-backed flags | Edit the `localparam` at the top of the target package file, then re-synthesize |
| `RVB` in cv32 (line 94) | Edit the struct literal directly — no `localparam` exists |
| `RVS`, `RVU` (both files) | Edit the struct literal directly — not expected to change |
| `FpgaEn` (both files) | Edit the struct literal directly — identical in both targets |

Any change to this group invalidates the existing synthesis run and requires a full re-synthesis.

### 2.4 Memory Management Unit and TLB Configuration

#### 2.4.1 MMU Presence and Virtual-Memory Mode

Both configurations enable the MMU via `CVA6ConfigMmuPresent = 1`, which drives the struct field `MmuPresent: bit'(CVA6ConfigMmuPresent)` (cv32 line 111; cv64 line 116). Neither package declares an explicit `Sv32` or `Sv39` parameter — those names appear only in target identifiers. The virtual-memory mode is implicitly determined by the combination of the target name and the datapath width: `cv32a6_imac_sv32` with `XLEN=32`/`VLEN=32` selects Sv32, and `cv64a6_imafdc_sv39` with `XLEN=64`/`VLEN=64` selects Sv39. Derived quantities such as `PLEN`, `PageLevels`, and `PCLength` are not defined locally in either package; they are computed inside the shared `config_pkg` from `XLEN`/`VLEN`.

#### 2.4.2 TLB Sizing and Shared-TLB Strategy

The two configurations take structurally different approaches to TLB organization, driven by the area budget implied by each target.

**CV32A6-IMAC-SV32 (Sv32):** Private instruction and data TLBs are kept minimal at 2 entries each (`InstrTlbEntries: int'(2)`, `DataTlbEntries: int'(2)` — lines 162–163). To compensate, a shared second-level TLB is enabled (`UseSharedTlb: bit'(1)`, line 164) with a depth of 64 entries (`SharedTlbDepth: int'(64)`, line 166). This two-level arrangement lets the 32-bit configuration maintain reasonable reach without paying the area cost of large private structures.

**CV64A6-IMAFDC-SV39 (Sv39):** Private TLBs are substantially larger at 16 entries each (`InstrTlbEntries: int'(16)`, `DataTlbEntries: int'(16)` — lines 167–168), and the shared TLB is disabled (`UseSharedTlb: bit'(0)`, line 169). The 64-bit target relies entirely on its larger private TLBs. Notably, `SharedTlbDepth` remains set to 64 (line 171) even though the shared TLB is not used; this fieldt to 64 (line 171) even though the shared TLB is not used; this field has no functional effect when `UseSharedTlb = 0`.

The table below summarizes the differenInstrTlbEntries` | 2 | 16 |
|:---|:---:|:---|
| `DataTlbEntries` | 2 | 16 |
| `UseSharedTlb` | 1 | 0 |
| `SharedTlbDepth` | 64 | 64 (inactive) |

#### 2.4.3 NAPOT Page Support

Supervisor NAPOT (`SvnapotEn`) is enabled only in the 64-bit configuration (`SvnapotEn: bit'(1)`, cv64 line 170) and disabled in the 32-bit configuration (`SvnapotEn: bit'(0)`, cv32 line 165). This is consistent with NAPOT being an Sv39/Sv48 feature; it has no defined role in Sv32.

#### 2.4.4 Hypervisor Extension

The H-extension is disabled in both configurations. `CVA6ConfigHExtEn = 0` (cv32 line 24; cv64 line 26) drives `RVH: bit'(CVA6ConfigHExtEn)` (cv32 line 98; cv64 line 103). There is no separate `HypervisorEn` field; `RVH` is the sole control point, and it is sourced entirely from `CVA6ConfigHExtEn`.

### 2.5 Cache Subsystem: Geometry and Data Cache Implementation Type

Both reference targets configure identical instruction and data cache geometry. The only structural difference between them is the `DCacheType` field, which selects between two fundamentally different data cache RTL implementations. This distinction — not cache sizing — is the root cause of the divergent BRAM utilization observed between the 32-bit and 64-bit synthesis results in 3.1.

---

#### Cache Parameter Source Structure

All cache geometry parameters in both targets are `localparam`-backed. The `localparam` values are declared at the top of each target package and then referenced in the struct body. This makes cache sizing one of the cleaner modification points in the configuration files — changing the capacity or associativity requires editing only the `localparam` declarations, not the struct body directly.

```verilog
// cv32a6_imac_sv32_config_pkg.sv (lines 39–44, 46, 49, 67)
localparam CVA6ConfigIcacheByteSize    = 16384;
localparam CVA6ConfigIcacheSetAssoc    = 4;
localparam CVA6ConfigIcacheLineWidth   = 128;
localparam CVA6ConfigDcacheByteSize    = 32768;
localparam CVA6ConfigDcacheSetAssoc    = 8;
localparam CVA6ConfigDcacheLineWidth   = 128;
localparam CVA6ConfigDcacheIdWidth     = 3;
localparam CVA6ConfigWtDcacheWbufDepth = 8;
localparam config_pkg::cache_type_t CVA6ConfigDcacheType = config_pkg::HPDCACHE_WT;

// cv64a6_imafdc_sv39_config_pkg.sv (lines 40–45, 51, 54, 72)
localparam CVA6ConfigIcacheByteSize    = 16384;
localparam CVA6ConfigIcacheSetAssoc    = 4;
localparam CVA6ConfigIcacheLineWidth   = 128;
localparam CVA6ConfigDcacheByteSize    = 32768;
localparam CVA6ConfigDcacheSetAssoc    = 8;
localparam CVA6ConfigDcacheLineWidth   = 128;
localparam CVA6ConfigDcacheIdWidth     = 1;
localparam CVA6ConfigWtDcacheWbufDepth = 8;
localparam config_pkg::cache_type_t CVA6ConfigDcacheType = config_pkg::WT;
```

---

#### Instruction Cache — Identical in Both Targets

The instruction cache geometry is the same across both configurations:

| Parameter | Value | Source |
|:---|:---:|:---|
| `IcacheByteSize` | 16 KiB | `CVA6ConfigIcacheByteSize` |
| `IcacheSetAssoc` | 4-way | `CVA6ConfigIcacheSetAssoc` |
| `IcacheLineWidth` | 128 bits | `CVA6ConfigIcacheLineWidth` |

This yields a 16 KiB, 4-way set-associative instruction cache with 128-bit cache lines. The instruction cache implementation is not parameterized by a type field analogous to `DCacheType` — a single RTL implementation is used in both builds, and it infers cleanly to BRAM on the Genesys 2 target.

---

#### Data Cache Geometry — Also Identical in Both Targets

The data cache capacity parameters are the same in both packages:

| Parameter | Value | Source |
|:---|:---:|:---|
| `DcacheByteSize` | 32 KiB | `CVA6ConfigDcacheByteSize` |
| `DcacheSetAssoc` | 8-way | `CVA6ConfigDcacheSetAssoc` |
| `DcacheLineWidth` | 128 bits | `CVA6ConfigDcacheLineWidth` |

A 32 KiB, 8-way set-associative data cache with 128-bit cache lines. Both targets are configured to the same capacity. The geometry alone does not explain any synthesis difference.

---

#### `DCacheType` — The Structural Differentiator

```verilog
// cv32a6_imac_sv32_config_pkg.sv (line 67 / struct line 151):
localparam config_pkg::cache_type_t CVA6ConfigDcacheType = config_pkg::HPDCACHE_WT;
DCacheType: CVA6ConfigDcacheType,   // → HPDCACHE_WT

// cv64a6_imafdc_sv39_config_pkg.sv (line 72 / struct line 156):
localparam config_pkg::cache_type_t CVA6ConfigDcacheType = config_pkg::WT;
DCacheType: CVA6ConfigDcacheType,   // → WT
```

`DCacheType` is not a size parameter — it is an RTL module selector. The `cache_type_t` enumeration in `config_pkg.sv` maps each variant to a distinct data cache implementation:

- **`WT` (Write-Through):** The original CVA6 data cache implementation. This is a conventional, structurally regular SRAM array written to infer Block RAM on FPGA targets. Tag and data arrays are organized to match Vivado's BRAM inference rules: synchronous read/write ports, uniform access widths, and no asynchronous reset on the storage elements. On the Genesys 2, this implementation maps cleanly to BRAM primitives, and the 64-bit synthesis results reflect this — BRAM utilization is consistent with the expected capacity of a 32 KiB cache.

- **`HPDCACHE_WT` (High-Performance D-Cache, Write-Through):** A newer OpenHW Group data cache module designed for higher throughput, with support for multiple in-flight misses and a more complex internal pipeline. Its internal memory structures use access patterns and reset behavior that do not universally satisfy Vivado's BRAM inference heuristics. When inference fails, Vivado falls back to mapping the cache arrays to distributed RAM — synthesized from LUT6 primitives and flip-flops rather than dedicated BRAM tiles. This is responsible for the elevated LUT and FF counts and the reduced BRAM count observed in the 32-bit synthesis results (3.1). The resource footprint looks inflated compared to the 64-bit build not because the 32-bit design is inherently larger, but because a 32 KiB cache synthesized into distributed RAM consumes far more LUTs than the same capacity mapped to BRAMs.

The consequence is significant for resource budgeting: two builds with identical cache capacity and comparable core size can produce BRAM numbers that differ by the entire 32 KiB D$ allocation, depending solely on whether `DCacheType` resolves to `WT` or `HPDCACHE_WT`.

---

#### `DcacheIdWidth` — Request Tracking Width

```verilog
// cv32a6_imac_sv32_config_pkg.sv (line 46):
localparam CVA6ConfigDcacheIdWidth = 3;

// cv64a6_imafdc_sv39_config_pkg.sv (line 51):
localparam CVA6ConfigDcacheIdWidth = 1;
```

`DcacheIdWidth` sets the bit width of the transaction ID used internally by the data cache to track outstanding memory requests. The HPDCACHE_WT implementation requires a wider ID field to tag multiple in-flight misses (width 3 → up to 8 outstanding transactions); the simpler WT implementation needs only a single-bit ID (width 1 → 2 entries). This difference is structurally consistent with the capability gap between the two cache types: HPDCACHE_WT is built to handle more concurrent misses, and the wider ID field is the bookkeeping cost.

---

#### Write Buffer and Fence Behavior

```verilog
// Identical in both files:
WtDcacheWbufDepth: int'(CVA6ConfigWtDcacheWbufDepth),  // → 8
```

`WtDcacheWbufDepth` controls the number of entries in the write-through cache's write buffer — the queue that absorbs store traffic before it is committed to the AXI bus. At depth 8, both configurations can absorb short write bursts without immediately stalling the store path. This parameter is meaningful in both `WT` and `HPDCACHE_WT` modes; the write buffer is present in both implementations.

The 64-bit package additionally declares three cache flush control parameters that are absent from the 32-bit package entirely:

```verilog
// cv64a6_imafdc_sv39_config_pkg.sv only (lines 47–49):
localparam CVA6ConfigDcacheFlushOnFence   = 1'b0;
localparam CVA6ConfigDcacheFlushOnFenceI  = 1'b0;
localparam CVA6ConfigDcacheInvalidateOnFlush = 1'b0;
```

All three are `0`, meaning neither `FENCE` nor `FENCE.I` instructions trigger a full D$ flush, and a flush does not invalidate cached lines. These parameters are part of the HPDCACHE_WT → WT migration surface: they expose coherence behaviors specific to the `WT` implementation family that the HPDCACHE_WT module handles differently internally. Their absence from `cv32a6_imac_sv32_config_pkg.sv` is consistent with `HPDCACHE_WT` not consuming these fields.

---

#### NOC Interface and AXI Burst Mode

```verilog
// Identical in both files:
NOCType:         config_pkg::NOC_TYPE_AXI4_ATOP,   // cv32 line 130 | cv64 line 135
AxiBurstWriteEn: bit'(0),                           // cv32 line 147 | cv64 line 152
```

Both targets use `NOC_TYPE_AXI4_ATOP`, which selects the AXI4 interconnect with atomic operation support — required by `RVA = 1` in both configurations. `AxiBurstWriteEn = 0` disables AXI burst write transactions; stores are issued as individual AXI write beats rather than burst sequences. This is the conservative setting for Genesys 2 where the MIG memory controller adds latency variability that burst sequencing could complicate.

---

#### Complete Cache Parameter Summary

| Parameter | CV32A6-IMAC-SV32 | CV64A6-IMAFDC-SV39 | Source |
|:---|:---:|:---:|:---|
| `IcacheByteSize` | 16 KiB | 16 KiB | `localparam` |
| `IcacheSetAssoc` | 4 | 4 | `localparam` |
| `IcacheLineWidth` | 128 bits | 128 bits | `localparam` |
| `DcacheByteSize` | 32 KiB | 32 KiB | `localparam` |
| `DcacheSetAssoc` | 8 | 8 | `localparam` |
| `DcacheLineWidth` | 128 bits | 128 bits | `localparam` |
| **`DCacheType`** | **HPDCACHE_WT** | **WT** | `localparam` (enum) |
| `DcacheIdWidth` | 3 | 1 | `localparam` |
| `WtDcacheWbufDepth` | 8 | 8 | `localparam` |
| `AxiBurstWriteEn` | 0 | 0 | hardcoded literal |
| `NOCType` | AXI4_ATOP | AXI4_ATOP | hardcoded literal |
| `FlushOnFence` | — (absent) | 0 | `localparam` (cv64 only) |
| `FlushOnFenceI` | — (absent) | 0 | `localparam` (cv64 only) |
| `InvalidateOnFlush` | — (absent) | 0 | `localparam` (cv64 only) |

---

> **Configuration note:** All cache geometry parameters are `localparam`-backed and can be modified at the top of either target package without touching the struct body. `DCacheType` is also `localparam`-backed but changing it is not a routine capacity adjustment — switching between `WT` and `HPDCACHE_WT` changes the instantiated RTL module and its interface requirements, including `DcacheIdWidth`. Changing `DCacheType` in isolation without adjusting `DcacheIdWidth` and verifying the presence of the associated flush parameters will produce an inconsistent configuration. Any modification to this group requires a full re-synthesis.
---

## 3. Version Comparison

This section compares four synthesis configurations across two axes: bitwidth (32-bit
vs. 64-bit) and superscalar mode. Both bitwidth variants are based on their respective
official Bender targets — `cv32a6_imac_sv32` and `cv64a6_imafdc_sv39` — and each is
evaluated with superscalar support disabled (`SuperscalarEn = 0`) and enabled
(`SuperscalarEn = 1`). The `SuperscalarEn` flag is defined in the corresponding
configuration package files (`cv32a6_imac_sv32_config_pkg.sv` and
`cv64a6_imafdc_sv39_config_pkg.sv`) under the Libraries section of the project; toggling
it between builds is the only change made to produce the dual-issue variants. The four
resulting configurations are compared in terms of resource utilization, timing, and
critical path characteristics below.

### 3.1 Resource Utilization Comparison

| Configuration (Core) | Superscalar | LUT | FF | BRAM | DSP | IO |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **32-bit** (`cv32a6_imac_sv32`) | OFF | 135,074 | 327,292 | 16 | 4 | 4,979 |
| **32-bit** (`cv32a6_imac_sv32`) | ON | 140,181 | 328,223 | 16 | 4 | 5,083 |
| **64-bit** (`cv64a6_imafdc_sv39`) | OFF | 54,326 | 23,728 | 36 | 27 | 0 |
| **64-bit** (`cv64a6_imafdc_sv39`) | ON | 63,685 | 25,108 | 36 | 27 | 0 |

> *Note: The 64-bit configurations correctly report 0 I/O pins because the synthesis was successfully constrained as strict Out-of-Context (OOC).*

#### Visualization

<!-- Dark theme -->
![Resource Utilization — Dark](cva6_resource_github_dark.png#gh-dark-mode-only)
<!-- Light theme -->
![Resource Utilization — Light](cva6_resource_github_light.png#gh-light-mode-only)

> The charts above show LUT/FF utilization (left) and BRAM/DSP utilization (right)
> across all four configurations. SS OFF = Superscalar disabled; SS ON = Superscalar enabled.

#### Key Observation: Why Does the 32-bit Core Consume More LUTs and FFs?

At first glance the numbers appear contradictory: the 32-bit core uses roughly
**13.5× more flip-flops** than the 64-bit core (327 K vs. 23 K). This is not an
architectural anomaly — it is a **cache-mapping artifact** introduced by Vivado
during synthesis.

1. **32-bit (`cv32a6_imac_sv32`) — cache spills into Distributed RAM.**
   Vivado failed to infer the instruction and data caches as Block RAM (only 16 BRAM tiles were allocated). As a result, all cache storage was implemented using flip-flops and LUTs. This inflates both FF and LUT counts dramatically and does not reflect the actual combinational logic complexity of the
   core itself.

2. **64-bit (`cv64a6_imafdc_sv39`) — cache maps correctly to BRAM.**
   Vivado successfully inferred the caches onto hard memory primitives (36 BRAM
   tiles), keeping FF and LUT counts representative of the core's real logic footprint.

3. **DSP difference is architectural, not a tool artifact.**
   The 32-bit `imac` configuration has no FPU and requires only 4 DSP blocks for its
   integer multiplier. The 64-bit `imafdc` configuration includes a full FPU
   (`fpnew`) and accordingly consumes 27 DSP blocks.

4. **The isolated cost of Superscalar execution.**
   Because the 64-bit variant synthesized cleanly, we can precisely observe the dual-issue overhead. Enabling superscalar in the 64-bit core adds **9,359 LUTs (+17.2%)** and **1,380 FFs**. This increase is entirely logical (with 0 extra DSPs or BRAMs) and directly reflects the added hazard detection logic, operand-forwarding pathways, and expanded multiplexers required inside the Scoreboard to issue two instructions simultaneously.

### 3.2 Timing Analysis & Critical Path Evaluation

**Methodology:**
All four configurations were synthesized using an Out-of-Context (OOC) constraint
targeting a $100\text{ MHz}$ clock ($T_{clk} = 10\text{ ns}$). The theoretical
maximum operating frequency is derived from Vivado's Worst Negative Slack (WNS):

$$F_{max} = \frac{1000}{T_{clk} - WNS} \text{ MHz}$$

> **OOC constraint visibility bug:**
> The synthesis script originally registered the XDC file as:
> ```tcl
> set_property USED_IN {synthesis implementation} [get_files cva6_ooc.xdc]
> ```
> When Vivado runs in `-mode out_of_context`, it silently ignores the XDC unless
> `out_of_context` is explicitly listed in `USED_IN`. Without this, Vivado reports
> `There are no user specified timing constraints` and WNS is unavailable.
> The corrected form:
> ```tcl
> set_property USED_IN {synthesis implementation out_of_context} \
>     [get_files cva6_ooc.xdc]
> ```
> All figures below were obtained after applying this fix.

#### Results

| Configuration (Core) | Superscalar | WNS (ns) | $F_{max}$ (MHz) | Logic Levels | Routing Share |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **32-bit** (`cv32a6_imac_sv32`) | OFF | −3.729 | 72.84 | 28 | 85.1 % |
| **32-bit** (`cv32a6_imac_sv32`) | ON | −5.282 | 65.43 | 34 | 77.3 % |
| **64-bit** (`cv64a6_imafdc_sv39`) | OFF | −9.118 | 52.31 | 45 | 72.0 % |
| **64-bit** (`cv64a6_imafdc_sv39`) | ON | −9.968 | 50.08 | 47 | 71.8 % |

> WHS (Worst Hold Slack) is $+0.182\text{ ns}$ across all four configurations — no hold violations.

#### Visualization

<!-- Dark theme -->
![Timing Utilization — Dark](cva6_timing_github_dark.png#gh-dark-mode-only)
<!-- Light theme -->
![Timing Utilization — Light](cva6_timing_github_light.png#gh-light-mode-only)

Each configuration shows a pair of bars: $|WNS|$ (red, left axis) and estimated
$F_{max}$ (blue, right axis). Higher $|WNS|$ means a larger timing violation;
lower $F_{max}$ means the design closes timing at a lower frequency.

#### Critical Path Analysis

- **CVA6 (32-bit, Single-Issue):** Critical path originates in the CSR/PMP
  register file and terminates in the `Scoreboard` inside the Issue Stage, traversing
  28 logic levels (including 13 LUT6 stages). Routing accounts for 85.1 % of total
  delay — expected for OOC synthesis without physical placement.

- **CVA6 (32-bit, Dual-Issue):** Enabling dual-issue adds hazard-detection and
  operand-forwarding logic to the Scoreboard. The critical path migrates from the
  CSR block to the `lsu_valid` control path through the Data Cache interface, growing
  to 34 logic levels. $F_{max}$ drops by $\approx 7.4\text{ MHz}$ relative to the
  single-issue variant.

- **CVA6 (64-bit, both variants):** The critical path shifts entirely
  away from the Issue Stage into the Floating-Point Unit. The bottleneck is
  `fpnew_cast_multi` — the format-casting pipeline inside the FPU — originating
  there and terminating at the `vaddr_to_be_flushed` register in the execute stage.
  Logic levels jump to 45 and 47 respectively. Enabling superscalar in the 64-bit 
  variant adds 2 extra logic levels because the FPU cast path remains the dominant
  constraint, masking the Issue Stage overhead.

#### Key Observations

1. **Superscalar cost is bitwidth-dependent.** In the 32-bit core, dual-issue costs
   $\approx 7.4\text{ MHz}$ (28 → 34 logic levels). In the 64-bit core the same
   change costs less than $2.3\text{ MHz}$ (45 → 47), because the FPU already owns
   the critical path and the dual-issue overhead is buried beneath it.

2. **The ISA extension, not the datapath width, drives the 32→64 bit timing penalty.**
   Moving from `cv32a6_imac_sv32` to `cv64a6_imafdc_sv39` (both single-issue) drops
   $F_{max}$ from 72.84 to 52.31 MHz — a loss of over 20 MHz — because `imafdc`
   adds the deep FPU combinational chains absent in `imac`.

3. **OOC routing bias.** Statistical wire-delay models inflate routing's share to
   71–85 % of total delay. The logic delay component is placement-independent and
   scales cleanly with architectural complexity; it is the reliable signal here.
   Post-implementation timing will redistribute these numbers but is unlikely to
   change the relative ranking of the four configurations.

---

## 4. Summary and Conclusions

> To be written after all four synthesis and implementation runs are complete.

Key questions this section will answer:
- What is the LUT and register overhead of moving from single-issue to dual-issue at each bitwidth?
- Does the 64-bit ISA extension (IMAFDC vs IMAC) meaningfully impact the critical path?
- Which configuration offers the best frequency–area trade-off for the target FPGA part (`xc7a100tcsg324-1`)?
