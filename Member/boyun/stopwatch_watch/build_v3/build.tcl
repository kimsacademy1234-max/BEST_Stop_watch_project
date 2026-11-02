# v3 자리 단위 설정 + 디바운서 2 kHz (../build_2khz/btn_debounce.v). 나머지는 ../src
set src ../src
foreach f [glob $src/*.v] { if {[file tail $f] ne "btn_debounce.v"} { read_verilog $f } }
read_verilog ../build_2khz/btn_debounce.v
read_xdc $src/stopwatch_watch.xdc
synth_design -top stopwatch_watch -part xc7a35tcpg236-1
opt_design
place_design
route_design
report_utilization -file util_impl.rpt
report_timing_summary -file timing.rpt
report_drc -file drc.rpt
write_bitstream -force stopwatch_watch_v3_digit_2khz.bit
