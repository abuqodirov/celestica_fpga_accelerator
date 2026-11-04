#!/bin/bash
# Put the FPGA back on its factory design (from the card's flash) - do this before shutting the PC down.
~/.local/bin/openFPGALoader -c digilent_hs3 -r && echo "FPGA is back on the factory design; the PC can be shut down."
