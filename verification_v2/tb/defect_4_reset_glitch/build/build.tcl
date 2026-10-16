# defect_4_reset_glitch 결함 src 비트스트림 (v2 포트 이름). build 폴더에서 실행: vivado -mode batch -source build.tcl
foreach f [glob ../src/*.v] { read_verilog $f }
foreach f [glob ../src/*.sv] { read_verilog -sv $f }
read_xdc ../src/stopwatch_watch.xdc
synth_design -top stopwatch_watch -part xc7a35tcpg236-1
opt_design
place_design
route_design
report_utilization -file util_impl.rpt
report_timing_summary -file timing.rpt
report_drc -file drc.rpt
write_bitstream -force stopwatch_watch.bit
