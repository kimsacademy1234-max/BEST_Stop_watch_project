#!/bin/bash
# 버그 사본 하나 (S1 ~ S8) 에 대해 : 단위 TB 2 개 (tb_sd1_char · tb_sd2_sender v2 판) + 전체 Top TB (tb_top_full, FIX=6)
#   bash run_bug.sh S1
unset NoDefaultCurrentDirectoryInExePath
V="C:/Xilinx/Vivado/2022.2/bin"
K=$1
B=/c/work/sender_bug/$K
S=$B/src
T1="/c/Users/LG/Developer/work/26_AI_CAMP_2/20261030_uart_sender/20261030_uart_sender.srcs/sim_1/imports/tb/tb_sd1_char.v"
T2=/c/work/sender_v2_tb/tb_sd2_sender/tb_sd2_sender_v2.v
for tb in tb_sd1_char tb_sd2_sender; do
  mkdir -p $B/$tb && cd $B/$tb && rm -rf xsim.dir
  if [ $tb = tb_sd1_char ]; then F="$S/UART/sender_char_mux.v $T1"; else F="$S/UART/sender_char_mux.v $S/UART/uart_sender.v $T2"; fi
  "$V/xvlog.bat" $F > c.log 2>&1
  "$V/xelab.bat" $tb -s s -debug typical > e.log 2>&1
  grep -h "ERROR" c.log e.log | head -3
  timeout 600 "$V/xsim.bat" s -runall -log r.log > /dev/null 2>&1
  echo "$K $tb : $(grep -a 'TOTAL MISMATCH' r.log | tail -1) (FAIL 줄 $(grep -ac 'FAIL\|MISMATCH at\|ERR' r.log))"
done
timeout 1800 bash "/c/Users/LG/Developer/Lec_verilog/팀프로젝트2_자료/통합검증/run_full.sh" $B/top $S 6 > $B/top.out 2>&1
echo "$K tb_top_full : $(grep -a 'TOTAL MISMATCH' $B/top/r.log | tail -1)"
