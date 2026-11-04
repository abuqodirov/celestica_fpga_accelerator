# Verilator builds of the matvec engine testbench: B=1 (obj_b1/tb) and B=4 (obj_b4/tb)
RTL = ../rtl/mv_engine.v
all: obj_b1/tb obj_b4/tb
obj_b%/tb: $(RTL) tb_mv_engine.cpp ../golden/golden.h
	verilator --cc $(RTL) --exe tb_mv_engine.cpp -GB=$* --Mdir obj_b$* -o tb --build -j 4 -O3 \
	    -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -CFLAGS "-I$(CURDIR)/../golden -O2 -DNVEC=$*" > obj_b$*.log 2>&1 || (tail -30 obj_b$*.log; false)
clean:
	rm -rf obj_b1 obj_b4 *.log
