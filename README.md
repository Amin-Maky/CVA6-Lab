
# CVA6-lab

## 1. Overview



## 2. Repository Layout

**CVA6-lab/** - Main repository root

<details>
<summary><b>benchmarks/</b> - Software only (formerly firmware)</summary>

```text
├── src/                        # Source files 
│   ├── avg.c
│   ├── boot.S
│   ├── bug_32.S
│   ├── bug_64.S
│   ├── complex_32.S
│   ├── complex_64.S
│   ├── complex_avg.c
│   ├── main_.c
│   ├── main-syn.S
│   ├── main_32.S
│   ├── main_64.S
│   └── matmul.c
├── linker/                     # Linker scripts
│   └── link.ld
└── spike-checking/             # Spike simulation logs
```
</details>

<details>
<summary><b>docs/</b> - Documentation files</summary>

```text
├── 1-environment-setup.md      # Unified setup: Clone, Bender, GCC, and Spike installation
├── 2-vivado-synthesis.md       # Vivado synthesis flow and resource reports
├── 3-simulation-flow.md        # Official and manual simulation with Verilator (+ Post-Synthesis Simulation)
├── 4-arch-32b-analysis.md      # 32-bit analysis
└── 5-arch-64b-custom.md        # 64-bit dev history, FLU Write-back architecture, and results
```
</details>

<details>
<summary><b>fpga/</b> - FPGA and Synthesis files</summary>

```text
├── vivado                      # Vivado Tcl scripts
│   ├── cv32a6_imac_sv32.tcl
│   ├── cv32a6_imac_sv32_syn.tcl
│   ├── cv32a6_imac_sv32_post_syn_sim.tcl
│   ├── cv64a6_imafdc_sv39.tcl
│   ├── cv64a6_imafdc_sv39_syn.tcl
│   └── cv64a6_imafdc_sv39_post_syn_sim.tcl
├── constraints/
│   └── cva6_ooc.xdc
└── build/                      # (gitignored) All Vivado outputs generated here
├── vivado_prj_cv32a6/
└── vivado_prj_cv64a6/
```
</details>

<details>
<summary><b>scripts/</b> - Helper scripts</summary>

```text
└── f-maker                     # CVA6 File Tree Copier & .f File Updater
```
</details>

<details>
<summary><b>sim/</b> - Simulation execution environment (Workspace)</summary>

```text
├── Makefile                    # Makefile for Verilator simulation
└── filelists/                  # Bender output .f files
├── cv32a6_imac_sv32_verilator.f
└── cv64a6_imafdc_sv39_verilator.f
```
</details>

<details>
<summary><b>tb/</b> - All verification sources</summary>

```text
├── sv/                         # SystemVerilog testbenches
│   └── cva6_tb.sv
├── cpp/                        # Verilator testbenches
│   ├── tb_cva6_ww.cpp          # With waveform
│   └── tb_cva6_wow.cpp         # Without waveform
└── wrappers/                   # Simulation wrappers
└── cva6_axi_wrapper.sv
```
</details>

<details>
<summary><b>rtl/</b> & <b>Root Files</b></summary>

```text
├── rtl/                        # Processor RTL only (no testbenches)
├── README.md                   # Main README
├── Makefile                    # Main Makefile
└── .git
```
</details>

## 3. Quick Start (`Makefile`)

## 4. Documentation Index

<details>
<summary><b> 1. Environment Setup</b></summary>

* [View Full Document](docs/1-environment-setup.md)
* [1. System Requirements](docs/1-environment-setup.md#1-system-requirements)
  * [1.1 Operating System & Filesystem](docs/1-environment-setup.md#11-operating-system--filesystem)
  * [1.2 Storage & RAM](docs/1-environment-setup.md#12-storage--ram)
  * [1.3 Network](docs/1-environment-setup.md#13-network)
* [2. Repository Setup](docs/1-environment-setup.md#2-repository-setup)
  * [2.1 Cloning the Repository](docs/1-environment-setup.md#21-cloning-the-repository)
  * [2.2 Initializing Submodules](docs/1-environment-setup.md#22-initializing-submodules)
* [3. System Dependencies](docs/1-environment-setup.md#3-system-dependencies)
  * [3.1 APT Packages](docs/1-environment-setup.md#31-apt-packages)
  * [3.2 Python Virtual Environment](docs/1-environment-setup.md#32-python-virtual-environment)
* [4. RISC-V GCC Toolchain](docs/1-environment-setup.md#4-risc-v-gcc-toolchain)
  * [4.1 Build Prerequisites](docs/1-environment-setup.md#41-build-prerequisites)
  * [4.2 Setting the $RISCV Environment Variable](docs/1-environment-setup.md#42-setting-the-riscv-environment-variable)
  * [4.3 Building the Toolchain](docs/1-environment-setup.md#43-building-the-toolchain)
  * [4.4 Resource Estimates](docs/1-environment-setup.md#44-resource-estimates)
  * [4.5 Common Build Errors & Fixes](docs/1-environment-setup.md#45-common-build-errors--fixes)
  * [4.6 Verifying the Installation](docs/1-environment-setup.md#46-verifying-the-installation)
* [5. Bender (Dependency Manager)](docs/1-environment-setup.md#5-bender-dependency-manager)
  * [5.1 Installing Bender](docs/1-environment-setup.md#51-installing-bender)
  * [5.2 Verifying Bender](docs/1-environment-setup.md#52-verifying-bender)
* [6. Simulators (Verilator & Spike)](docs/1-environment-setup.md#6-simulators-verilator--spike)
  * [6.1 Configuring the Environment](docs/1-environment-setup.md#61-configuring-the-environment)
  * [6.2 Known Patches Before Build](docs/1-environment-setup.md#62-known-patches-before-build)
  * [6.3 Building Verilator & Spike](docs/1-environment-setup.md#63-building-verilator--spike)
* [7. Setup Checklist](docs/1-environment-setup.md#7-setup-checklist)
  * [7.1 Pre-Flight Checklist](docs/1-environment-setup.md#71-pre-flight-checklist)
  * [7.2 Error Quick-Reference](docs/1-environment-setup.md#72-error-quick-reference)
  * [7.3 Session Startup](docs/1-environment-setup.md#73-session-startup)

</details>

<details>
<summary><b> 2. Vivado Synthesis</b></summary>

* [View Full Document](docs/2-vivado-synthesis.md)
* [1. Project Creation](docs/2-vivado-synthesis.md#1-project-creation)
  * [1.1 Using the Official CVA6 Repository](docs/2-vivado-synthesis.md#11-using-the-official-cva6-repository)
  * [1.2 Using the Project Makefile Flow](docs/2-vivado-synthesis.md#12-using-the-project-makefile-flow)
* [2. Processor Configuration](docs/2-vivado-synthesis.md#2-processor-configuration)
  * [2.0 Locating and Modifying Configuration Packages](docs/2-vivado-synthesis.md#20-locating-and-modifying-configuration-packages)
  * [2.1 Datapath Width Parameters (XLEN and VLEN)](docs/2-vivado-synthesis.md#21-datapath-width-parameters-xlen-and-vlen)
  * [2.2 Issue Control, Scoreboard Depth, and Execution Pipeline](docs/2-vivado-synthesis.md#22-issue-control-scoreboard-depth-and-execution-pipeline-parameters)
  * [2.3 ISA Extension Flags and Functional Unit Instantiation](docs/2-vivado-synthesis.md#23-isa-extension-flags-and-functional-unit-instantiation)
  * [2.4 Memory Management Unit and TLB Configuration](docs/2-vivado-synthesis.md#24-memory-management-unit-and-tlb-configuration)
  * [2.5 Cache Subsystem](docs/2-vivado-synthesis.md#25-cache-subsystem-geometry-and-data-cache-implementation-type)
* [3. Version Comparison](docs/2-vivado-synthesis.md#3-version-comparison)
  * [3.1 Resource Utilization Comparison](docs/2-vivado-synthesis.md#31-resource-utilization-comparison)
  * [3.2 Timing Analysis & Critical Path Evaluation](docs/2-vivado-synthesis.md#32-timing-analysis--critical-path-evaluation)
* [4. Summary and Conclusions](docs/2-vivado-synthesis.md#4-summary-and-conclusions)

</details>

<details>
<summary><b> 3. Simulation Flow</b></summary>

* [View Full Document](docs/3-simulation-flow.md)
* [1. Post-Synthesis Simulation (Vivado / XSIM)](docs/3-simulation-flow.md#1-post-synthesis-simulation-vivado--xsim)
  * [1.1 AXI Testbench and Firmware Setup](docs/3-simulation-flow.md#11-axi-testbench-and-firmware-setup)
  * [1.2 Elaboration and Simulation in XSIM](docs/3-simulation-flow.md#12-elaboration-and-simulation-in-xsim)
  * [1.3 Waveform Inspection](docs/3-simulation-flow.md#13-waveform-inspection)
* [2. Developer Simulation Flow (cva6.py + Verilator + Spike)](docs/3-simulation-flow.md#2-developer-simulation-flow-cva6py--verilator--spike)
  * [2.1 Running the Default Test Suite (smoke test)](docs/3-simulation-flow.md#21-running-the-default-test-suite-smoke-test)
  * [2.2 Custom C and Assembly Programs](docs/3-simulation-flow.md#22-custom-c-and-assembly-programs)
  * [2.3 Waveform Debugging & Architectural Signal Analysis](docs/3-simulation-flow.md#23-waveform-debugging--architectural-signal-analysis)
  * [2.4 C Code Analysis & HTIF Communication Mechanism](docs/3-simulation-flow.md#24-c-code-analysis--htif-communication-mechanism)
  * [2.5 Conclusion: End-to-End Proof of Functionality](docs/3-simulation-flow.md#25-conclusion-end-to-end-proof-of-functionality)
* [3. Manual Simulation from Scratch (Standalone Verilator)](docs/3-simulation-flow.md#3-manual-simulation-from-scratch-standalone-verilator)
  * [3.0 Overview & Motivation](docs/3-simulation-flow.md#30-overview--motivation)
  * [3.1 Dependency Generation via Bender](docs/3-simulation-flow.md#31-dependency-generation-via-bender)
  * [3.2 CVA6 AXI Wrapper (cva6_axi_wrapper.sv)](docs/3-simulation-flow.md#32-cva6-axi-wrapper-cva6_axi_wrappersv)
  * [3.3 Spike as Instruction-Level Reference](docs/3-simulation-flow.md#33-spike-as-instruction-level-reference---log-commits)
  * [3.4 Firmware Suite & Linker Script](docs/3-simulation-flow.md#34-firmware-suite--linker-script)
  * [3.5 Self-Checking C++ Testbench](docs/3-simulation-flow.md#35-self-checking-c-testbench)
  * [3.6 Makefile Automation](docs/3-simulation-flow.md#36-makefile-automation)
* [4. Processor Performance Comparison](docs/3-simulation-flow.md#4-processor-performance-comparison)
  * [4.1 Executed Benchmarks](docs/3-simulation-flow.md#41-executed-benchmarks)
  * [4.2 Results](docs/3-simulation-flow.md#42-results)

</details>

<details>
<summary><b> 4. 32-bit Architecture Analysis</b></summary>

* [View Full Document](docs/4-arch-32b-analysis.md)
* [1. The Big Picture: CVA6 Top-Level Structure](docs/4-arch-32b-analysis.md#1-the-big-picture-cva6-top-level-structure)
* [2. Inside the Issue Stage: Scoreboard and Operand Read](docs/4-arch-32b-analysis.md#2-inside-the-issue-stage-scoreboard-and-operand-read)
  * [2.1 Issue Stage Overview](docs/4-arch-32b-analysis.md#21-issue-stage-overview)
  * [2.2 The Scoreboard: A Ledger for In-Flight Instructions](docs/4-arch-32b-analysis.md#22-the-scoreboard-a-ledger-for-in-flight-instructions)
  * [2.3 Issue Read Operands: The Gatekeeper of Dispatch](docs/4-arch-32b-analysis.md#23-issue-read-operands-the-gatekeeper-of-dispatch)
  * [2.4 Commit Process](docs/4-arch-32b-analysis.md#24-commit-process)
* [3. Seeing It in the Waveform](docs/4-arch-32b-analysis.md#3-seeing-it-in-the-waveform)
  * [3.1 Step 1: Designing the .S Test Program](docs/4-arch-32b-analysis.md#31-step-1-designing-the-s-test-program)
  * [3.2 Step 2: Following the Waveform](docs/4-arch-32b-analysis.md#32-step-2-following-the-waveform)
  * [3.3 Step 3: Conclusion](docs/4-arch-32b-analysis.md#33-step-3-conclusion)
* [4. Summary: It Can Be Further Developed](docs/4-arch-32b-analysis.md#4-summary-it-can-be-further-developed)

</details>

<details>
<summary><b> 5. 64-bit Custom Architecture</b></summary>

* [View Full Document](docs/5-arch-64b-custom.md)
* [Introduction](docs/5-arch-64b-custom.md#introduction)
  * [1.1 Design Space: New Channel vs. Shared Channel](docs/5-arch-64b-custom.md#11-design-space-new-channel-vs-shared-channel)
  * [1.2 Implementation Roadmap](docs/5-arch-64b-custom.md#12-implementation-roadmap-four-phase-incremental-deployment)
* [2. Prerequisite Analysis (Phase 0)](docs/5-arch-64b-custom.md#2-prerequisite-analysis-phase-0)
  * [2.1 Divider Data Safety (Latching)](docs/5-arch-64b-custom.md#21-divider-data-safety-latching)
  * [2.2 Decoupling the Ready Signals in the Issue Stage](docs/5-arch-64b-custom.md#22-decoupling-the-ready-signals-in-the-issue-stage)
* [3. Issue Decoupling (Phase 1)](docs/5-arch-64b-custom.md#3-issue-decoupling-phase-1)
  * [3.1 The Coupling Point](docs/5-arch-64b-custom.md#31-the-coupling-point)
  * [3.2 Implementation](docs/5-arch-64b-custom.md#32-implementation)
  * [3.3 Result: The Issue Path Is Free](docs/5-arch-64b-custom.md#33-result-the-issue-path-is-free)
  * [3.4 What Phase 1 Breaks](docs/5-arch-64b-custom.md#34-what-phase-1-breaks)
* [4. Write-back Collision & the Holding Buffer (Phase 2.1)](docs/5-arch-64b-custom.md#4-write-back-collision--the-holding-buffer-phase-21)
  * [4.1 Implementation](docs/5-arch-64b-custom.md#41-implementation)
  * [4.2 Operation](docs/5-arch-64b-custom.md#42-operation)
  * [4.3 Result: Collision Resolved](docs/5-arch-64b-custom.md#43-result-collision-resolved)
* [5. Back-Pressure (Phase 2.2)](docs/5-arch-64b-custom.md#5-back-pressure-phase-22)
  * [5.1 The Hypothetical Failure](docs/5-arch-64b-custom.md#51-the-hypothetical-failure)
  * [5.3 Making It Bullet-Proof Anyway](docs/5-arch-64b-custom.md#53-making-it-bullet-proof-anyway)
  * [5.4 Cost](docs/5-arch-64b-custom.md#54-cost)
* [6. Functional Verification via Forced Hazard Scenarios](docs/5-arch-64b-custom.md#6-functional-verification-via-forced-hazard-scenarios)
  * [6.1 Concurrent ALU Operation During an Active Division](docs/5-arch-64b-custom.md#61-concurrent-alu-operation-during-an-active-division)
  * [6.2 Control-Flow Redirection During an Active Division](docs/5-arch-64b-custom.md#62-control-flow-redirection-during-an-active-division)
  * [6.3 Overlapping Multi-Cycle Instructions](docs/5-arch-64b-custom.md#63-overlapping-multi-cycle-instructions-divisionmultiplication-on-divisionmultiplication)
* [7. Comparison](docs/5-arch-64b-custom.md#7-comparison)
  * [7.1 Resource Utilization](docs/5-arch-64b-custom.md#71-resource-utilization)
  * [7.2 Timing Analysis & Critical Path](docs/5-arch-64b-custom.md#72-timing-analysis--critical-path)
  * [7.3 Performance & Execution Speed (Benchmarks)](docs/5-arch-64b-custom.md#73-performance--execution-speed-benchmarks)
  * [7.4 Conclusion](docs/5-arch-64b-custom.md#74-conclusion)

</details>

## 5. Results at a Glance






## 6. References and License

### References
- [CVA6 Official Repository & Documentation](https://github.com/openhwgroup/cva6)
- [Bender: Dependency Management Tool for Hardware Projects](https://github.com/pulp-platform/bender)
- [Xilinx Vivado Design Suite Documentation](https://www.xilinx.com/support/documentation-navigation/design-hubs/dh0010-vivado-design-hub.html)
- [RISC-V Instruction Set Manual](https://github.com/riscv/riscv-isa-manual)
- [RISC-V GNU Compiler Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)
- [Spike RISC-V ISA Simulator](https://github.com/riscv-software-src/riscv-isa-sim)
- [Verilator: Open-Source SystemVerilog Simulator](https://verilator.org/)
- [Matplotlib: Visualization with Python](https://matplotlib.org/) - Used for generating performance and resource utilization plots.

### License

This project is open-source and distributed under the **Apache License 2.0**. See the [LICENSE](LICENSE) file for more details.

**Note:** The base CVA6 core RTL and some associated files remain under their original OpenHW Group licenses (Solderpad Hardware License v2.1 / Apache 2.0). The custom modifications (holding buffer, structural hazard resolution logic) and the evaluation framework (benchmarks, Python plotting scripts, Makefiles) provided in this repository are distributed under the Apache 2.0 license.