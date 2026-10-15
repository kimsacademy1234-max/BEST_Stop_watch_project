# 클로드코드 참고 구현 비트스트림 만들기 (Vivado non-project 배치)
# 실행: build 폴더에서  C:\Xilinx\Vivado\2022.2\bin\vivado.bat -mode batch -source build.tcl
set src ../src
read_verilog [glob $src/*.v]
read_xdc $src/stopwatch_watch.xdc
synth_design -top stopwatch_watch -part xc7a35tcpg236-1
report_utilization -file util_synth.rpt
opt_design
place_design
route_design
report_utilization -file util_impl.rpt
report_timing_summary -file timing.rpt
report_methodology -file methodology.rpt
report_drc -file drc.rpt
write_bitstream -force stopwatch_watch.bit
