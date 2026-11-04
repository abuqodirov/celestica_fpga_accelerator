# minirv on the Celestica XC7K480T card.
#   make progs   assemble test programs + reference results (Python model)
#   make sim     run them on the RTL in Verilator and compare with the model
#   make bit     build the FPGA bitstream
#   make load    load it into the FPGA (RAM only)
#   make hw      run the programs on the FPGA and compare with simulation
#   make leds    run the endless LED counter program
TOOLS   ?= $(HOME)/tools
PART    := xc7k480tffg1156-2
DB      := $(TOOLS)/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7
PY      := $(TOOLS)/venv/bin/python
CORE    := build/minirv_core.v ../RegisterFile.v
RTL     := rtl/fpga_top.v rtl/minirv_soc.v $(CORE)
REGIONS := 30008000:32 30008100:40

.PHONY: progs sim bit load hw leds clean
build/minirv_core.v: ../top.v prep_core.py
	@mkdir -p build
	python3 prep_core.py ../top.v $@

progs:
	python3 sw/programs.py

build/sim/Vminirv_soc: rtl/minirv_soc.v $(CORE) sim/tb_soc.cpp
	verilator --cc --exe --build -O2 -Wall -Wno-fatal -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL \
		-Wno-PINCONNECTEMPTY --top-module minirv_soc -Mdir build/sim -o Vminirv_soc \
		rtl/minirv_soc.v $(CORE) sim/tb_soc.cpp

sim: progs build/sim/Vminirv_soc
	for p in hello selftest; do ./build/sim/Vminirv_soc build/progs/$$p.bin 10000000 $(REGIONS) \
		> build/progs/$$p.sim.json; done
	python3 host/compare.py sim

# -nosrl: SRL primitives are broken in this flow; -nolutram: keep the register file in flip-flops
build/minirv.json: $(RTL)
	yosys -q -l build/yosys.log -p "read_verilog -sv $(RTL); synth_xilinx -flatten -abc9 -nosrl -nolutram -arch xc7 -top fpga_top; stat; write_json $@"

build/minirv.fasm: build/minirv.json fpga.xdc
	$(TOOLS)/nextpnr-xilinx/build/nextpnr-xilinx --chipdb $(TOOLS)/chipdb/$(PART).bin --xdc fpga.xdc \
		--json $< --fasm $@ --freq 50 --log build/pnr.log

build/minirv_pn.fasm: build/minirv.fasm
	python3 ../../tools/unused_pins.py $< $@

build/minirv.frames: build/minirv_pn.fasm
	$(PY) $(TOOLS)/prjxray/utils/fasm2frames.py --part $(PART) --db-root $(DB) $< > $@

bit: build/minirv.frames
	$(TOOLS)/prjxray/build/tools/xc7frames2bit --part_file $(DB)/$(PART)/part.yaml \
		--part_name $(PART) --frm_file $< --output_file minirv.bit

load:
	$(HOME)/.local/bin/openFPGALoader -c digilent_hs3 --freq 30M minirv.bit

hw:
	for p in hello selftest; do $(PY) host/run_minirv.py build/progs/$$p.bin --regions $(REGIONS) \
		--json build/progs/$$p.hw.json; done
	python3 host/compare.py hw

leds:
	$(PY) host/run_minirv.py build/progs/ledcount.bin --no-wait

clean:
	rm -rf build minirv.bit
