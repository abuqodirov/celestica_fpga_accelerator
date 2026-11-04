# Source this before LiteX builds: puts the open toolchain and RISC-V GCC on PATH.
# yosys-fix: private yosys 0.52 copy whose share/xilinx/brams_xc6v_map.v fixes the RAMB36 72-bit
# SDP parity typo (DIPBDIP used "== 71", wiring the upper parity inputs to the lower parity bits)
export PATH=$HOME/tools/yosys-fix:$HOME/tools/bin:$HOME/tools/riscv/xpack-riscv-none-elf-gcc-15.2.0-1/bin:$HOME/tools/openocd/xpack-openocd-0.12.0-7/bin:$HOME/tools/venv/bin:$PATH
export CHIPDB=$HOME/tools/chipdb
export PRJXRAY_DB_DIR=$HOME/tools/nextpnr-xilinx/xilinx/external/prjxray-db
