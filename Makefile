# =============================================================================
# CVA6-lab — Root Makefile
#
# FPGA Synthesis (Vivado):
#   make synth-32
#   make synth-64
#
# Post-Synthesis Simulation (delegates to sim/Makefile):
#   make post-syn-sim-32
#   make post-syn-sim-64
#
# RTL Simulation (delegates to sim/Makefile):
#   make sim                          # playground, 64-bit, waveform ON
#   make sim ARCH=32                  # same, 32-bit
#   make sim CMD=run_bug              # bug-hunt mode
#   make sim CMD=run_matmul ARCH=32   # matmul benchmark, 32-bit
#   make clean-sim
# =============================================================================

.PHONY: all synth-32 synth-64 cva6-32 cva6-64 sim clean-sim post-syn-sim-32 post-syn-sim-64 help

all: help

# --- FPGA Synthesis ----------------------------------------------------------

synth-32:
	cd fpga/build && vivado -mode batch -source ../vivado/cv32a6_imac_sv32_syn.tcl
	
synth-64:
	cd fpga/build && vivado -mode batch -source ../vivado/cv64a6_imafdc_sv39_syn.tcl
	
# --- vivado Prj     ----------------------------------------------------------

cva6-32:
	cd fpga/build && vivado -mode batch -source ../vivado/cv32a6_imac_sv32.tcl
	
cva6-64:
	cd fpga/build && vivado -mode batch -source ../vivado/cv64a6_imafdc_sv39.tcl
	
# --- Simulation --------------------------------------------------------------

CMD  ?= run
ARCH ?= 64

sim:
	$(MAKE) -C sim $(CMD) ARCH=$(ARCH)

clean-sim:
	$(MAKE) -C sim clean

# --- Post-Synthesis Simulation -----------------------------------------------

post-syn-sim-32:
	$(MAKE) -C sim post-syn-sim-32

post-syn-sim-64:
	$(MAKE) -C sim post-syn-sim-64

# --- Help --------------------------------------------------------------------

help:
	@echo "====================================================================="
	@echo "                      CVA6-lab - Makefile Help                       "
	@echo "====================================================================="
	@echo "Usage: make <target> [VARIABLE=value]"
	@echo ""
	@echo "--- FPGA Vivado Project Creation ---"
	@echo "  make cva6-32          : Generate Vivado GUI project for cv32a6_imac_sv32"
	@echo "  make cva6-64          : Generate Vivado GUI project for cv64a6_imafdc_sv39"
	@echo ""
	@echo "--- FPGA Synthesis (Batch Mode) ---"
	@echo "  make synth-32         : Run logic synthesis for 32-bit (cv32a6_imac_sv32)"
	@echo "  make synth-64         : Run logic synthesis for 64-bit (cv64a6_imafdc_sv39)"
	@echo ""
	@echo "--- Post-Synthesis Simulation ---"
	@echo "  make post-syn-sim-32  : Run post-synthesis simulation for 32-bit"
	@echo "  make post-syn-sim-64  : Run post-synthesis simulation for 64-bit"
	@echo ""
	@echo "--- RTL Simulation ---"
	@echo "  make sim              : Run simulation (Default: ARCH=64, CMD=run)"
	@echo "  make clean-sim        : Remove simulation build files and artifacts"
	@echo ""
	@echo "  Simulation Variables:"
	@echo "    ARCH=32|64          : Set Target architecture (Default: 64)"
	@echo "    CMD=<command>       : Set Simulation test/mode (Default: run)"
	@echo ""
	@echo "  Available Commands (CMD):"
	@echo "    run                 : Assembly playground, waveform ON"
	@echo "    run_c               : C code playground, waveform ON"
	@echo "    run_complex         : Speed benchmark test, no waveform"
	@echo "    run_bug             : Bug hunt test mode, waveform ON"
	@echo "    run_matmul          : Matrix multiplication benchmark"
	@echo "    run_avg             : Array average benchmark"
	@echo ""
	@echo "  Examples:"
	@echo "    make sim                             # Run default 64-bit playground"
	@echo "    make sim ARCH=32 CMD=run_matmul      # Run 32-bit matmul benchmark"
	@echo "    make sim CMD=run_bug                 # Run 64-bit bug hunt"
	@echo "====================================================================="
	@echo ""

