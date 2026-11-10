# Getting started: toolchain, build flow, first designs

Everything runs without Vivado. We used Ubuntu 26.04 on an x86 PC with the card in a PCIe x8/x16 slot and a
Digilent JTAG-HS3 cable on the card's 2×7 2 mm JTAG header.

The scripts in this repository assume:
- this repository is cloned to **`~/celestica`**;
- the tools are under **`~/tools`** (sources and builds), `openFPGALoader` in `~/.local/bin`, and the Python
  packages in the venv `~/tools/venv`.

## Versions we used

| Tool | Version | Role |
|---|---|---|
| Yosys | 0.52 (Ubuntu) + one-line fix; **0.65 or newer recommended** (has the fix) | synthesis |
| nextpnr-xilinx | openXC7 `bc9b234` + [our patch](../patches/nextpnr-xilinx.diff) | place and route |
| prjxray-db | the copy bundled with nextpnr-xilinx (openXC7 fork) + our overlay in `pcie/db/` | chip database |
| Project X-Ray | f4pga `c9f02d8` + GCC 15 fix | `fasm2frames`, `xc7frames2bit`, `bit2fasm` |
| openFPGALoader | v1.1.1 `efb64ff` + XADC patch | load bitstreams, status, XADC, flash read |
| LiteX / LiteDRAM | 2026.8 (`litex_setup.py --config=standard`) | SoC, DDR3 controller |
| Verilator | 5.032 | testbenches |
| RISC-V GCC | xPack `riscv-none-elf-gcc` 15.2.0-1 | LiteX BIOS / firmware |
| OpenOCD | xPack 0.12.0-7 | LiteX JTAG console (`litex/jtag_console.py`) |
| Python | 3.14; numpy 2.5, migen 0.9.2, pyftdi 0.57, fasm 0.0.2; torch + tokenizers for the LLMs | host software |

Exact commits of every tool, download links and checksums: [`tools/toolchain_versions.txt`](../tools/toolchain_versions.txt);
LiteX/Migen commits: [`tools/litex_commits.txt`](../tools/litex_commits.txt); Python packages:
[`tools/requirements-venv.txt`](../tools/requirements-venv.txt). The patches apply to exactly these commits, so the
steps below check them out.

**Note on nextpnr:** nextpnr-xilinx is now archived; development continues in
[openXC7/nextpnr](https://github.com/openXC7/nextpnr) (`himbaechel` xilinx). Two of our three nextpnr fixes are
already in it; the GT one is not (see [toolchain-bugs.md](toolchain-bugs.md)). We have not rebuilt our designs with
the new nextpnr.

## Installation

### 1. System packages and USB access (needs sudo)

```bash
sudo apt update
sudo apt install -y yosys openfpgaloader iverilog verilator gtkwave git cmake build-essential \
  ninja-build pkg-config python3-dev python3-pip python3-venv libboost-all-dev libeigen3-dev \
  libftdi1-dev libusb-1.0-0-dev libhidapi-dev zlib1g-dev libudev-dev libgpiod-dev
sudo usermod -aG plugdev $USER
```

Then unplug and replug the HS3: the udev rule only applies to devices plugged in after it was installed. Ubuntu's
own `openfpgaloader` (0.13.1) does **not** know the XC7K480T; install it anyway for its udev rule, but use the
upstream build below.

### 2. openFPGALoader (upstream, with Kintex-7 XADC readout)

```bash
mkdir -p ~/tools && cd ~/tools
git clone https://github.com/trabucayre/openFPGALoader.git && cd openFPGALoader
git checkout efb64ff
git apply ~/celestica/patches/openFPGALoader-xadc-kintex7.diff
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$HOME/.local
ninja -C build install
```

Put `~/.local/bin` before `/usr/bin` in `PATH`, or call `~/.local/bin/openFPGALoader` directly.

### 3. nextpnr-xilinx and the chip database

```bash
cd ~/tools
git clone https://github.com/openXC7/nextpnr-xilinx.git && cd nextpnr-xilinx
git checkout bc9b234                 # the commit we used (the repository is archived)
git submodule update --init --depth 1
git apply ~/celestica/patches/nextpnr-xilinx.diff
cmake -B build -G Ninja -DARCH=xilinx -DBUILD_GUI=OFF -DCMAKE_BUILD_TYPE=Release
ninja -C build                      # the build dir is Ninja: `make` silently does nothing

# chip database for this exact part: ~3 min, ~13 GB RAM, 684 MB result
mkdir -p ~/tools/chipdb && cd xilinx
python3 python/bbaexport.py --device xc7k480tffg1156-2 --bba ~/tools/chipdb/xc7k480t.bba
../build/bbasm -l ~/tools/chipdb/xc7k480t.bba ~/tools/chipdb/xc7k480tffg1156-2.bin
rm ~/tools/chipdb/xc7k480t.bba
```

### 4. Project X-Ray tools

```bash
cd ~/tools
git clone https://github.com/f4pga/prjxray.git && cd prjxray
git checkout c9f02d8
git submodule update --init --recursive --depth 1
git apply ~/celestica/patches/prjxray-gcc15.diff      # GCC 15: <cstdint>, no -Werror
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
ninja -C build
```

### 5. Python environment and LiteX

```bash
python3 -m venv ~/tools/venv
~/tools/venv/bin/pip install -e ~/tools/prjxray fasm pyftdi pyyaml simplejson intervaltree numpy textx meson
mkdir -p ~/tools/litex && cd ~/tools/litex
wget https://raw.githubusercontent.com/enjoy-digital/litex/master/litex_setup.py
~/tools/venv/bin/python litex_setup.py --init --install --config=standard
# pin LiteX, LiteDRAM, Migen, ... to the commits we used (LiteX changes quickly; ypcb_soc.py uses LiteDRAM internals)
while read d c; do case $d in '#'*|'') continue;; esac; git -C ~/tools/litex/$d checkout -q $c; done \
    < ~/celestica/tools/litex_commits.txt
# for the LLM tools (CPU-only torch is enough):
~/tools/venv/bin/pip install torch tokenizers huggingface_hub
```

`tools/requirements-venv.txt` lists every package version we had, if something does not import.

The warning "Unable to import fast Antlr4 parser" from `fasm` is harmless.

### 5b. RISC-V GCC and OpenOCD (for LiteX SoCs)

LiteX compiles its BIOS with a RISC-V GCC, and `litex/jtag_console.py` talks to the SoC through OpenOCD.
`litex/env.sh` expects the xPack builds at these paths:

```bash
mkdir -p ~/tools/dl ~/tools/riscv ~/tools/openocd && cd ~/tools/dl
wget https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v15.2.0-1/xpack-riscv-none-elf-gcc-15.2.0-1-linux-x64.tar.gz
wget https://github.com/xpack-dev-tools/openocd-xpack/releases/download/v0.12.0-7/xpack-openocd-0.12.0-7-linux-x64.tar.gz
sha256sum *.tar.gz     # compare with tools/toolchain_versions.txt
tar -xzf xpack-riscv-none-elf-gcc-15.2.0-1-linux-x64.tar.gz -C ~/tools/riscv
tar -xzf xpack-openocd-0.12.0-7-linux-x64.tar.gz -C ~/tools/openocd
```

### 6. Yosys with the RAMB36 fix (only if your yosys is older than 0.65)

```bash
mkdir -p ~/tools/yosys-fix && cd ~/tools/yosys-fix
cp /usr/bin/yosys . && ln -s /usr/bin/yosys-abc . && cp -r /usr/share/yosys share
cd share && patch -p2 < ~/celestica/patches/yosys-0.52-brams_xc6v_map.diff
```

yosys looks for `share/` next to its real binary, so copy the binary (a symlink would still find
`/usr/share/yosys`). `litex/env.sh` puts `~/tools/yosys-fix` first on `PATH`. (Only designs with 72-bit-wide block RAMs need it, such as the LiteX JTAG loader FIFO.)

### 7. Command wrappers used by the scripts

```bash
mkdir -p ~/tools/bin && cd ~/tools/bin
ln -s ~/tools/nextpnr-xilinx/build/nextpnr-xilinx ~/tools/nextpnr-xilinx/build/bbasm .
ln -s ~/tools/prjxray/build/tools/xc7frames2bit .
printf '#!/bin/sh\nexec %s/tools/venv/bin/python %s/tools/prjxray/utils/fasm2frames.py "$@"\n' $HOME $HOME > fasm2frames
chmod +x fasm2frames
```

`litex/env.sh` sets `PATH`, `CHIPDB` and `PRJXRAY_DB_DIR` for all LiteX builds: `. ~/celestica/litex/env.sh`.

### 8. Check the card

```bash
openFPGALoader -c digilent_hs3 --detect               # model xc7k480t
openFPGALoader -c digilent_hs3 --read-register STAT   # factory design running: 0x4107afc
openFPGALoader -c digilent_hs3 --read-xadc            # temperature, VCCINT, VCCAUX
```

**Before writing anything to the flash, back it up** (`pins/flashdump`, read-only, 73 s for 64 MB). We never
wrote the flash: everything in this repository loads over JTAG into the FPGA's RAM only.

## Build flow

```
Verilog ──yosys──▶ .json ──nextpnr-xilinx──▶ .fasm ──unused_pins.py──▶ (VREF fix) ──fasm2frames──▶ .frames
        ──xc7frames2bit──▶ .bit ──openFPGALoader──▶ FPGA (RAM only)
```

```bash
T=~/tools; P=xc7k480tffg1156-2; DB=$T/nextpnr-xilinx/xilinx/external/prjxray-db/kintex7
yosys -p "synth_xilinx -flatten -abc9 -nosrl -arch xc7 -top top; write_json top.json" top.v
$T/nextpnr-xilinx/build/nextpnr-xilinx --chipdb $T/chipdb/$P.bin --xdc top.xdc \
    --json top.json --fasm top.fasm --freq 100
python3 ~/celestica/tools/unused_pins.py top.fasm top_pn.fasm      # REQUIRED on this card
fasm2frames --part $P --db-root $DB top_pn.fasm > top.frames
xc7frames2bit --part_file $DB/$P/part.yaml --part_name $P --frm_file top.frames --output_file top.bit
openFPGALoader -c digilent_hs3 --freq 30M top.bit     # ~6 s; success shows "init 1 done 1"
```

- `-nosrl`: shift-register LUTs gave wrong data in this flow ([toolchain-bugs.md](toolchain-bugs.md)).
- Designs with SSTL15 (DDR3) inputs also need the VREF fix:
  `sed 's/\.VREF\.V_675_MV$/.VREF.V_750_MV/'` on the FASM.
- Designs with a PLL/MMCM: constrain it next to its clock input, e.g.
  `set_property BEL PLLE2_ADV_X0Y1/PLLE2_ADV [get_cells PLLE2_ADV]`, or routing may fail. Use PLLs, not MMCMs, for
  phase-shifted clocks.
- `fasm2frames` is pure Python and memory-hungry: **~10 GB for the big LLM designs**. Never run two at once on a
  16 GB machine (the build scripts serialise them with `flock`).

Loading over JTAG only changes the FPGA's RAM. Back to the factory design: `openFPGALoader -c digilent_hs3 -r`
(run it twice if the status stays `0x4001a0c`), or power-cycle the PC. While our design is loaded the card's PCIe
device disappears; the kernel logs a few correctable PCIe errors per reload, which is harmless.

## First designs

### `calc/`: JTAG calculator and 1024-bit multiplier (no board pins needed)

Clock from `STARTUPE2.CFGMCLK`, I/O through `BSCANE2` USER1/USER2.

```bash
cd ~/celestica/calc
make sim        # Verilator: calculator testbench (18,370 vectors)
make sim-big    # Verilator: 2,004 big multiplications
make bit        # bitstream (~3.5 min)
make load       # into the FPGA (~6 s)
make run        # 287 calculator vectors on the card, compared with simulation
make run-big    # two random 200-digit numbers multiplied on the FPGA, checked against Python
make restore    # back to the factory design
```

### `pins/blink`: LEDs

P30 = LED3 (slow), N30 = LED4 (fast, yellow), M30 = LED5 (medium).

### `minirv/`: a small RISC-V CPU on the card

`minirv/fpga`: the CPU (`minirv/top.v`, unchanged) in a small SoC (64 KiB block RAM, console, LEDs, JTAG debug
port) at 50 MHz. `make sim` compares Verilator with a reference model; `make hw` runs the same programs on the
card and compares with Verilator.

### `tests/`: small hardware checks

Block-RAM initial contents (`tests/diag`), LUT-RAM (`tests/lutram*`), MMCM vs PLL phase shifts (`tests/phase`,
`tests/pllphase`).

### LiteX SoC with DDR3

```bash
cd ~/celestica/litex && . ./env.sh
./build.sh build_ddr3                      # CPU + DDR3 channel 0 (8 lanes), BIOS memtest
YPCB_BUILD=build_ddr3 ./boottest.sh build_ddr3/gateware/ypcb_00338_1p1.bit   # leveling + memtest summary
python3 console.py                         # BIOS console over the JTAG UART
```

See [ddr3.md](ddr3.md) for the options and the two-channel setup.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Unknown device with IDCODE: 0x23751093` | Ubuntu's openFPGALoader 0.13.1 | Use the upstream build |
| `Access denied (insufficient permissions)` | HS3 plugged in before the udev rule existed | Replug it, or `sudo udevadm control --reload && sudo udevadm trigger` |
| After loading: `init 0 done 0`, STAT `0x4001a0c` | Unused pins pulled down | Add the `unused_pins.py` step |
| `read_xadc only supported for Artix 7` | openFPGALoader family check | XADC patch (step 2) |
| Factory design doesn't come back after `-r` | Seen after an interrupted flash dump | Run `-r` again; or a short clean flash read; or power-cycle the PC |
| prjxray build: `uint8_t does not name a type` | GCC 15 | `patches/prjxray-gcc15.diff` |
| nextpnr: `Unable to find legal placement` with a floorplan | A net's name puts cells in the wrong region (aliased nets) | See [lessons.md](lessons.md) |
| Results wrong only on hardware | Logic too slow for the clock | Compare nextpnr's estimate with known-good builds (it is pessimistic, see lessons.md) |
| Reads over JTAG wrong at 30 MHz | HS3 samples TDO too early | ≤ 20 MHz, or falling-edge sampling |
