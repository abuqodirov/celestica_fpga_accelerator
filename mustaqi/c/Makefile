# C helpers for the host software: q4h_lib.so (bit-exact PC reference of the FPGA engines, used by fpga_llm.py) and
# mustaqi (stand-alone C model). pcie_io.so builds itself on first use (pcie_link.py).
CFLAGS = -O3 -march=native -fopenmp -I../../accel/golden

all: q4h_lib.so

q4h_lib.so: q4h_lib.c ../../accel/golden/golden.h
	gcc $(CFLAGS) -shared -fPIC q4h_lib.c -o $@

mustaqi: mustaqi.c
	gcc $(CFLAGS) mustaqi.c -o $@ -lm

clean:
	rm -f q4h_lib.so mustaqi pcie_io.so

.PHONY: all clean
