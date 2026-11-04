# JTAG calculator: simulate with Verilator, build with the openXC7 flow, run on the board.
#   make sim      - Verilator C++ testbench (writes build/calc.vcd, build/vectors.csv)
#   make bit      - synthesize, place & route, generate build/calc.bit
#   make load     - load the bitstream into FPGA RAM (flash is not touched)
#   make run      - run build/vectors.csv on the hardware and compare
#   make sim-big  - Verilator testbench for the big-integer multiplier
#   make run-big  - multiply two 200-digit numbers on the FPGA (A=... B=... for your own)
#   make restore  - reload the factory design from flash

TOOLS   ?= $(HOME)/tools
PART    := xc7k480tffg1156-2
DB      := $(TOOLS)/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7
CHIPDB  := $(TOOLS)/chipdb/$(PART).bin
NEXTPNR := $(TOOLS)/nextpnr-xilinx/build/nextpnr-xilinx
PY      := $(TOOLS)/venv/bin/python
OFL     := $(HOME)/.local/bin/openFPGALoader -c digilent_hs3 --freq 30M
RTL     := rtl/top.v rtl/calc_core.v rtl/bigmul.v

.PHONY: all sim sim-big bit load run run-big restore clean
all: sim bit

sim: build/sim/Vcalc_core
	cd build && ./sim/Vcalc_core

build/sim/Vcalc_core: rtl/calc_core.v sim/tb_calc.cpp
	verilator --cc --exe --build -O2 --trace -Wall -Wno-fatal --top-module calc_core \
		-Mdir build/sim -o Vcalc_core rtl/calc_core.v sim/tb_calc.cpp

sim-big: build/simbig/Vbigmul
	cd build && ./simbig/Vbigmul

build/simbig/Vbigmul: rtl/bigmul.v sim/tb_bigmul.cpp
	verilator --cc --exe --build -O2 -Wall -Wno-fatal --top-module bigmul \
		-Mdir build/simbig -o Vbigmul rtl/bigmul.v sim/tb_bigmul.cpp

bit: build/calc.bit

build/calc.json: $(RTL)
	@mkdir -p build
	yosys -q -l build/yosys.log -p "synth_xilinx -flatten -abc9 -nosrl -arch xc7 -top top; stat; write_json $@" $(RTL)

build/calc.fasm: build/calc.json calc.xdc
	$(NEXTPNR) --chipdb $(CHIPDB) --xdc calc.xdc --json $< --fasm $@ --freq 100 --log build/pnr.log

# Unused pins must be PULLNONE: the all-zero default (pulldown) aborts startup on this board.
build/calc_pn.fasm: build/calc.fasm
	python3 ../tools/unused_pins.py $< $@

build/calc.frames: build/calc_pn.fasm
	$(PY) $(TOOLS)/prjxray/utils/fasm2frames.py --part $(PART) --db-root $(DB) $< > $@

build/calc.bit: build/calc.frames
	$(TOOLS)/prjxray/build/tools/xc7frames2bit --part_file $(DB)/$(PART)/part.yaml \
		--part_name $(PART) --frm_file $< --output_file $@

load: build/calc.bit
	$(OFL) $<

run:
	$(PY) host/run_hw.py build/vectors.csv

run-big:
	$(PY) host/run_bigmul.py $(A) $(B)

restore:
	$(OFL) -r

clean:
	rm -rf build
