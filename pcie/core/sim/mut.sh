#!/bin/bash
# mutation check for tb_bridge.v: each broken copy of the bridge must FAIL (or time out)
cd "$(dirname "$0")"
mut() { sed "$1" ../pcie_trn_bridge.v > m_$3.v; cmp -s m_$3.v ../pcie_trn_bridge.v && { echo "$2: sed did not apply"; return; }
        iverilog -g2005 -o tbm_$3 tb_bridge.v m_$3.v && r=$(timeout 60 vvp -n tbm_$3 +seed=3 +ntlp=1500 | grep -E 'PASS|FAIL' | cut -c1-80)
        echo "$2: ${r:-TIMEOUT (hang = caught)}"; rm -f m_$3.v tbm_$3; }
mut 's/rrem\[1\] ? 2.d0 : 2.d2/rrem[1] ? 2'"'"'d2 : 2'"'"'d0/' "sof position swapped" 1
mut 's/(h_len\[1:0\] + 2.d2)/(h_len[1:0] + 2'"'"'d1)/' "last trem off by one" 2
mut 's/(p_left == 11.d1) ? p_lbe/(p_left == 11'"'"'d1) ? p_fbe/' "last BE wrong" 3
mut 's/- (12.d3 - {10.d0, last_byte(lbe)})/- (12'"'"'d2 - {10'"'"'d0, last_byte(lbe)})/' "byte count" 4
mut 's/ \&\& !(reof \&\& sofpos == 2.d0 \&\& i > eofpos)//' "single-beat mask" 5
mut 's/{dw\[6:2\], first_byte(p_fbe)}/{dw[6:2], 2'"'"'b00}/' "lower address" 6
mut 's/(!have_head || (!h_ur \&\& aj != h_len))/(!have_head || aj != h_len)/' "rsp taken while head is UR" 7
mut 's/assign rdst_rdy = !hv \&\& rst_n;/assign rdst_rdy = rst_n;/' "no back-pressure" 8
mut 's/2.d0: ab0\[apos\[10:2\]\]/2'"'"'d0: ab1[apos[10:2]]/' "assembly bank" 9
