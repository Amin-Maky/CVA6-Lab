# =============================================================================
# CVA6-lab — Root Makefile
# =============================================================================

.PHONY: all cva6-32 cva6-64 synth-32 synth-64 sim clean clean-sim post-syn-sim-32 post-syn-sim-64 help

all: help

# --- Vivado Prj --------------------------------------------------------------

cva6-32:
	cd fpga/build && vivado -mode batch -source ../vivado/cv32a6_imac_sv32.tcl
	
cva6-64:
	cd fpga/build && vivado -mode batch -source ../vivado/cv64a6_imafdc_sv39.tcl
	
# --- FPGA Synthesis ----------------------------------------------------------

synth-32:
	@echo "====================================================================="
	@echo " WARNING: Synthesis process is starting. This may take a LONG TIME!"
	@echo "====================================================================="
	cd fpga/build && vivado -mode batch -source ../vivado/cv32a6_imac_sv32_syn.tcl
	
synth-64:
	@echo "====================================================================="
	@echo " WARNING: Synthesis process is starting. This may take a LONG TIME!"
	@echo "====================================================================="
	cd fpga/build && vivado -mode batch -source ../vivado/cv64a6_imafdc_sv39_syn.tcl
	
# --- RTL Simulation ----------------------------------------------------------

CMD  ?= run
ARCH ?= 64

sim:
	$(MAKE) -C sim $(CMD) ARCH=$(ARCH)

clean-sim:
	$(MAKE) -C sim clean

clean: clean-sim
	@echo "--- Cleaning FPGA build artifacts ---"
	rm -rf fpga/build
	mkdir -p fpga/build

# --- Post-Synthesis Simulation -----------------------------------------------

post-syn-sim-32:
	@echo "====================================================================="
	@echo " WARNING: Post-Synthesis Simulation takes a VERY LONG TIME!"
	@echo "====================================================================="
	$(MAKE) -C sim post-syn-sim-32

post-syn-sim-64:
	@echo "====================================================================="
	@echo " WARNING: Post-Synthesis Simulation takes a VERY LONG TIME!"
	@echo "====================================================================="
	$(MAKE) -C sim post-syn-sim-64

# --- Help --------------------------------------------------------------------

help:
	@echo "====================================================================="
	@echo "                      CVA6-lab - Makefile Help                       "
	@echo "====================================================================="
	@echo "Usage: make <target> [VARIABLE=value]"
	@echo ""
	@echo "--- FPGA Vivado Project Creation ---"
	@echo "  make cva6-32          : Generate Vivado GUI project (32-bit)"
	@echo "  make cva6-64          : Generate Vivado GUI project (64-bit)"
	@echo ""
	@echo "--- FPGA Synthesis (Batch Mode) ---"
	@echo "  make synth-32         : Run logic synthesis for 32-bit (LONG RUN)"
	@echo "  make synth-64         : Run logic synthesis for 64-bit (LONG RUN)"
	@echo ""
	@echo "--- Post-Synthesis Simulation ---"
	@echo "  make post-syn-sim-32  : Run post-synthesis sim for 32-bit (LONG RUN)"
	@echo "  make post-syn-sim-64  : Run post-synthesis sim for 64-bit (LONG RUN)"
	@echo ""
	@echo "--- RTL Simulation ---"
	@echo "  make sim              : Run simulation (Default: ARCH=64, CMD=run)"
	@echo "  make clean            : Clean ALL repo artifacts (sim + fpga)"
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
	@echo "    make sim ARCH=32 CMD=run_complex     # 32-bit complex sim"
	@echo "    make sim ARCH=64 CMD=run_bug         # 64-bit bug hunt"
	@echo "====================================================================="
	@echo ""

