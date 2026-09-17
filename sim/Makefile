# =============================================================================
# Makefile — CVA6 Verilator Simulation & Spike Co-Simulation
# Usage:
#   make [ARCH=32|64] [TARGET]
#   Default: ARCH=64, target=run
# =============================================================================

# --- 0. Architecture Selection (32 or 64 bit) --------------------------------
ARCH ?= 64

ifeq ($(ARCH),32)
  MARCH        = rv32imac
  MABI         = ilp32
  FILE_LIST    = cv32a6_imac_sv32_verilator.f
  SPIKE_ISA    = rv32imac
else
  MARCH        = rv64imafdc
  MABI         = lp64d
  FILE_LIST    = cv64a6_imafdc_sv39_verilator.f
  SPIKE_ISA    = rv64imafdc
endif

# --- 1. Paths ----------------------------------------------------------------
# Makefile lives in sim/; project root is one level up
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

# --- 3. Build defaults (overridden by run targets) ---------------------------
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
        run_complex run_bug run_matmul run_avg run_c

all: run

# --- 6. Run modes ------------------------------------------------------------

# Playground: main_32.S or main_64.S, waveform ON
run:
	@echo "=== Playground ($(ARCH)-bit, waveform) ==="
	$(MAKE) _pipeline \
	    PROG_SRC=$(BENCH_SRC)/main_$(ARCH).S \
	    TB_CPP=$(TB_CPP_DIR)/tb_cva6_ww.cpp \
	    TRACE_FLAGS="--trace --trace-structs"

# Complex benchmark: complex_32.S or complex_64.S, waveform OFF
run_complex:
	@echo "=== Complex Benchmark ($(ARCH)-bit, no waveform) ==="
	$(MAKE) _pipeline \
	    PROG_SRC=$(BENCH_SRC)/complex_$(ARCH).S \
	    TB_CPP=$(TB_CPP_DIR)/tb_cva6_wow.cpp \
	    TRACE_FLAGS=""

# Bug hunting: Bug_32.S or Bug_64.S, waveform ON
run_bug:
	@echo "=== Bug Hunting ($(ARCH)-bit, waveform) ==="
	$(MAKE) _pipeline \
	    PROG_SRC=$(BENCH_SRC)/Bug_$(ARCH).S \
	    TB_CPP=$(TB_CPP_DIR)/tb_cva6_ww.cpp \
	    TRACE_FLAGS="--trace --trace-structs"

# Matrix multiply benchmark: no waveform
run_matmul:
	@echo "=== Matrix Multiply Benchmark ($(ARCH)-bit, no waveform) ==="
	$(MAKE) _pipeline \
	    PROG_SRC="$(BENCH_SRC)/boot.S $(BENCH_SRC)/matmul.c" \
	    TB_CPP=$(TB_CPP_DIR)/tb_cva6_wow.cpp \
	    TRACE_FLAGS=""

# Array average benchmark: no waveform
run_avg:
	@echo "=== Array Average Benchmark ($(ARCH)-bit, no waveform) ==="
	$(MAKE) _pipeline \
	    PROG_SRC="$(BENCH_SRC)/boot.S $(BENCH_SRC)/avg.c" \
	    TB_CPP=$(TB_CPP_DIR)/tb_cva6_wow.cpp \
	    TRACE_FLAGS=""

# C playground: main.c, waveform ON
run_c:
	@echo "=== C Playground ($(ARCH)-bit, waveform) ==="
	$(MAKE) _pipeline \
	    PROG_SRC="$(BENCH_SRC)/boot.S $(BENCH_SRC)/main.c" \
	    TB_CPP=$(TB_CPP_DIR)/tb_cva6_ww.cpp \
	    TRACE_FLAGS="--trace --trace-structs"

# --- 7. Internal pipeline (fw → spike → prepare → compile → exec) -----------
_pipeline: _clean _fw _spike _prepare _compile _exec

_fw:
	@echo "--- Building firmware ($(MARCH)) ---"
	$(CC) -march=$(MARCH) -mabi=$(MABI) -mcmodel=medany \
	    -T $(BENCH_LINK)/link.ld -nostdlib \
	    $(PROG_SRC) -o firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

_spike: _fw
	@echo "--- Running Spike ($(SPIKE_ISA)) ---"
	mkdir -p $(SPIKE_DIR)
	cp firmware.elf $(SPIKE_DIR)/firmware.elf
	$(SPIKE) --isa=$(SPIKE_ISA) -l --log-commits \
	    $(SPIKE_DIR)/firmware.elf 2> spike_trace.log

_prepare: _spike
	@echo "--- Preparing simulation files ---"
	# firmware.bin already in sim/ (built here); nothing to copy

_compile: _prepare
	@echo "--- Compiling Verilator model ---"
	$(VERILATOR) $(VERILATOR_FLAGS) \
	    -f $(FILELIST_DIR)/$(FILE_LIST) \
	    $(WRAPPER_SV) \
	    --top-module $(TOP_MODULE) \
	    $(TB_CPP)

_exec: _compile
	@echo "--- Running simulation ---"
	./obj_dir/V$(TOP_MODULE)
	@echo "--- Done ---"

# --- 8. Utilities ------------------------------------------------------------
wave:
	gtkwave waveform.vcd

_clean:
	@echo "--- Cleaning ---"
	rm -rf obj_dir waveform.vcd trace_hart_0.dasm
	rm -f firmware.bin firmware.elf spike_trace.log firmware_syn.hex firmware_syn.elf
	rm -f $(SPIKE_DIR)/firmware.elf

clean: _clean

# ==============================================================================
# Post-Synthesis Simulation Targets
# ==============================================================================

.PHONY: post-syn-sim-32 post-syn-sim-64

post-syn-sim-32:
	@echo "========================================================="
	@echo "1. Compiling firmware for 32-bit post-synthesis..."
	@echo "========================================================="
	riscv-none-elf-gcc -march=rv32imac -mabi=ilp32 -nostdlib \
		-T $(BENCH_LINK)/link-syn.ld $(BENCH_SRC)/main-syn.S -o firmware_syn.elf
	
	@echo "========================================================="
	@echo "2. Generating Hex File (firmware_syn.hex)..."
	@echo "========================================================="
	riscv-none-elf-objcopy -O verilog --verilog-data-width=4 \
		--change-addresses -0x80000000 firmware_syn.elf firmware_syn.hex
	
	@echo "========================================================="
	@echo "3. Running Vivado Post-Synthesis Simulation (32-bit)..."
	@echo "========================================================="
	mkdir -p ../fpga/build
	cd ../fpga/build && vivado -mode batch -source ../vivado/cv32a6_imac_sv32_post_syn_sim.tcl


post-syn-sim-64:
	@echo "========================================================="
	@echo "1. Compiling firmware for 64-bit post-synthesis..."
	@echo "========================================================="
	riscv-none-elf-gcc -march=rv64imafdc -mabi=lp64d -nostdlib \
		-T $(BENCH_LINK)/link-syn.ld $(BENCH_SRC)/main-syn.S -o firmware_syn.elf
	
	@echo "========================================================="
	@echo "2. Generating Hex File (firmware_syn.hex)..."
	@echo "========================================================="
	riscv-none-elf-objcopy -O verilog --verilog-data-width=4 \
		--change-addresses -0x80000000 firmware_syn.elf firmware_syn.hex
	
	@echo "========================================================="
	@echo "3. Running Vivado Post-Synthesis Simulation (64-bit)..."
	@echo "========================================================="
	mkdir -p ../fpga/build
	cd ../fpga/build && vivado -mode batch -source ../vivado/cv64a6_imafdc_sv39_post_syn_sim.tcl

