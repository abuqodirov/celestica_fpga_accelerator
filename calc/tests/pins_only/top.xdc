# BPI flash control pins (verified: the flash dump through these pins returned a
# valid bitstream). Driven high so the flash stays idle while our design runs.
set_property -dict {PACKAGE_PIN V30 IOSTANDARD LVCMOS18} [get_ports flash_ce_n]
set_property -dict {PACKAGE_PIN T33 IOSTANDARD LVCMOS18} [get_ports flash_oe_n]
set_property -dict {PACKAGE_PIN T34 IOSTANDARD LVCMOS18} [get_ports flash_we_n]
set_property -dict {PACKAGE_PIN M31 IOSTANDARD LVCMOS18} [get_ports flash_adv_n]
