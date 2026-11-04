#!/usr/bin/env python3
"""Sweep dfiskew addr/cmd delays; for each, 5 single HW writes and report which columns changed."""
import subprocess, sys, os
from bios import Bios, csr

seq = "64,8,16,72,112"
for ad in range(4):
    for cd in range(4):
        b = Bios(); b.sync()
        b.write(csr("sdram_dfiskew_addr_delay"), ad); b.write(csr("sdram_dfiskew_cmd_delay"), cd)
        b.close()
        r = subprocess.run([sys.executable, "seq_test.py", str(30 + 4 * ad + cd), seq], capture_output=True, text=True, timeout=300)
        print(f"addr_delay={ad} cmd_delay={cd}: " + (r.stdout.strip().split("->")[-1] if r.stdout else r.stderr[-200:]), flush=True)
b = Bios(); b.sync(); b.write(csr("sdram_dfiskew_addr_delay"), 0); b.write(csr("sdram_dfiskew_cmd_delay"), 0); b.close()
