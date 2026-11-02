# 디바운서 샘플 tick 2 kHz 판 (src 의 btn_debounce.v 대신 이 폴더의 것을 씀). 나머지는 ../src 그대로
set src ../src
foreach f [glob $src/*.v] { if {[file tail $f] ne "btn_debounce.v"} { read_verilog $f } }
read_verilog btn_debounce.v
read_xdc $src/stopwatch_watch.xdc
synth_design -top stopwatch_watch -part xc7a35tcpg236-1
opt_design
place_design
route_design
report_utilization -file util_impl.rpt
report_timing_summary -file timing.rpt
report_drc -file drc.rpt
write_bitstream -force stopwatch_watch_2khz.bit
