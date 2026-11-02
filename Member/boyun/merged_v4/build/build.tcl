# 팀 통합판(ahnsung/source_file_v2) + 10/16 변경 반영판 빌드. build 폴더에서 실행
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
