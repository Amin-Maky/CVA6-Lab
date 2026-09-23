# =============================================================================
# Makefile — CVA6 Verilator Simulation & Spike Co-Simulation
# =============================================================================

# --- 0. Architecture Selection -----------------------------------------------
ARCH ?= 64

ifeq ($(ARCH),32)
  MARCH            = rv32imac
  MABI             = ilp32
  FILE_LIST        = cv32a6_imac_sv32_verilator.f
  SPIKE_ISA        = rv32imac
  VERILATOR_CFLAGS = -CFLAGS "-DRV32"
else
  MARCH            = rv64imafdc
  MABI             = lp64d
  FILE_LIST        = cv64a6_imafdc_sv39_verilator.f
  SPIKE_ISA        = rv64imafdc
  VERILATOR_CFLAGS = 
endif

# --- 1. Paths ----------------------------------------------------------------
ROOT         := $(abspath ..)
BENCH_SRC    := $(ROOT)/benchmarks/src
BENCH_LINK   := $(ROOT)/benchmarks/linker
SPIKE_DIR    := $(ROOT)/benchmarks/spike-checking
TB_CPP_DIR   := $(ROOT)/tb/cpp
RTL_DIR      := $(ROOT)/rtl
SIM_DIR      := $(ROOT)/sim
FILELIST_DIR := $(SIM_DIR)/filelists
CVA6_ROOT    := $(RTL_DIR)
export CVA6_ROOT

# --- 2. Toolchain ------------------------------------------------------------
CC       = riscv-none-elf-gcc
OBJCOPY  = riscv-none-elf-objcopy
SPIKE    = spike

# --- 3. Build defaults -------------------------------------------------------
PROG_SRC    ?= $(BENCH_SRC)/main_$(ARCH).S
TB_CPP      ?= tb_cva6_ww.cpp
TRACE_FLAGS ?= --trace --trace-structs

# --- 4. Verilator ------------------------------------------------------------
VERILATOR       = verilator
TOP_MODULE      = cva6_axi_wrapper
WRAPPER_SV      = $(ROOT)/tb/wrappers/cva6_axi_wrapper.sv

VERILATOR_FLAGS = \
    --cc \
    --exe \
    --build \
    -j 0 \
    $(TRACE_FLAGS) \
    -Wno-PINMISSING \
    -Wno-BLKANDNBLK \
    -Wno-fatal \
    -O1

# --- 5. Phony targets --------------------------------------------------------
.PHONY: all fw spike prepare compile run wave clean \
        run_complex run_bug run_matmul run_avg run_c post-syn-sim-32 post-syn-sim-64

all: run

# --- 6. Run modes ------------------------------------------------------------

run:
	@echo "=== Playground ($(ARCH)-bit, waveform ON) ==="
	$(MAKE) _pipeline PROG_SRC=$(BENCH_SRC)/main_$(ARCH).S TB_CPP=$(TB_CPP_DIR)/tb_cva6_ww.cpp TRACE_FLAGS="--trace --trace-structs"

run_complex:
	@echo "=== Complex Benchmark ($(ARCH)-bit, waveform OFF) ==="
	$(MAKE) _pipeline PROG_SRC=$(BENCH_SRC)/complex_$(ARCH).S TB_CPP=$(TB_CPP_DIR)/tb_cva6_wow.cpp TRACE_FLAGS=""

run_bug:
	@echo "=== Bug Hunting ($(ARCH)-bit, waveform ON) ==="
	$(MAKE) _pipeline PROG_SRC=$(BENCH_SRC)/bug_$(ARCH).S TB_CPP=$(TB_CPP_DIR)/tb_cva6_ww.cpp TRACE_FLAGS="--trace --trace-structs"

run_matmul:
	@echo "=== Matrix Multiply Benchmark ($(ARCH)-bit, waveform OFF) ==="
	$(MAKE) _pipeline PROG_SRC="$(BENCH_SRC)/boot.S $(BENCH_SRC)/matmul.c" TB_CPP=$(TB_CPP_DIR)/tb_cva6_wow.cpp TRACE_FLAGS=""

run_avg:
	@echo "=== Array Average Benchmark ($(ARCH)-bit, waveform OFF) ==="
	$(MAKE) _pipeline PROG_SRC="$(BENCH_SRC)/boot.S $(BENCH_SRC)/avg.c" TB_CPP=$(TB_CPP_DIR)/tb_cva6_wow.cpp TRACE_FLAGS=""

run_c:
	@echo "=== C Playground ($(ARCH)-bit, waveform ON) ==="
	$(MAKE) _pipeline PROG_SRC="$(BENCH_SRC)/boot.S $(BENCH_SRC)/main.c" TB_CPP=$(TB_CPP_DIR)/tb_cva6_ww.cpp TRACE_FLAGS="--trace --trace-structs"

# --- 7. Internal pipeline ----------------------------------------------------
_pipeline: _clean _fw _spike _prepare _compile _exec

_fw:
	@echo "--- Building firmware ($(MARCH)) ---"
	$(CC) -march=$(MARCH) -mabi=$(MABI) -mcmodel=medany -T $(BENCH_LINK)/link.ld -nostdlib $(PROG_SRC) -o firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

_spike: _fw
	@echo "--- Running Spike ($(SPIKE_ISA)) ---"
	mkdir -p $(SPIKE_DIR)
	cp firmware.elf $(SPIKE_DIR)/firmware.elf
	$(SPIKE) --isa=$(SPIKE_ISA) -l --log-commits $(SPIKE_DIR)/firmware.elf 2> spike_trace.log

_prepare: _spike
	@echo "--- Preparing simulation files ---"

_compile: _prepare
	@echo "--- Compiling Verilator model ---"
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_CFLAGS) -f $(FILELIST_DIR)/$(FILE_LIST) $(WRAPPER_SV) --top-module $(TOP_MODULE) $(TB_CPP)

_exec: _compile
	@echo "--- Running simulation ---"
	./obj_dir/V$(TOP_MODULE)
	@echo "--- Done ---"

# --- 8. Post-Synthesis Simulation --------------------------------------------

post-syn-sim-32: _clean
	@echo "=== Compiling firmware for 32-bit post-synthesis ==="
	$(CC) -march=rv32imac -mabi=ilp32 -nostdlib -T $(BENCH_LINK)/link.ld $(BENCH_SRC)/main-syn.S -o firmware_syn.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 --change-addresses -0x80000000 firmware_syn.elf firmware_syn.hex
	@echo "=== Running Vivado Post-Synthesis Simulation (32-bit) ==="
	mkdir -p ../fpga/build
	cd ../fpga/build && vivado -mode batch -source ../vivado/cv32a6_imac_sv32_post_syn_sim.tcl

post-syn-sim-64: _clean
	@echo "=== Compiling firmware for 64-bit post-synthesis ==="
	$(CC) -march=rv64imafdc -mabi=lp64d -nostdlib -T $(BENCH_LINK)/link.ld $(BENCH_SRC)/main-syn.S -o firmware_syn.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 --change-addresses -0x80000000 firmware_syn.elf firmware_syn.hex
	@echo "=== Running Vivado Post-Synthesis Simulation (64-bit) ==="
	mkdir -p ../fpga/build
	cd ../fpga/build && vivado -mode batch -source ../vivado/cv64a6_imafdc_sv39_post_syn_sim.tcl

# --- 9. Utilities & Cleanup --------------------------------------------------
wave:
	gtkwave waveform.vcd

_clean:
	@echo "--- Cleaning Sim Directory ---"
	rm -rf obj_dir waveform.vcd trace_hart_0.dasm
	rm -f firmware.bin firmware.elf spike_trace.log firmware_syn.hex firmware_syn.elf
	rm -f $(SPIKE_DIR)/firmware.elf

clean: _clean

