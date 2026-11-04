#!/bin/bash
# Chat with MustaqiLLM running on the FPGA card (see fpga_chat.py --help). Example: mustaqi/fpga_chat.sh
exec ~/tools/venv/bin/python "$(dirname "$(readlink -f "$0")")/fpga_chat.py" "$@"
