# L6 확인용 ILA 비트 (11/01) : vivado -mode batch -source build_ila.tcl -tclargs before|after
set which [lindex $argv 0]
set here [file dirname [file normalize [info script]]]
set dir $here/$which
set src $dir/src
create_project ila_$which $dir/proj -part xc7a35tcpg236-1 -force
catch { set_property board_part digilentinc.com:basys3:part0:1.2 [current_project] }
add_files -norecurse [glob -nocomplain $src/*.v $src/*/*.v $src/*/*.sv]
add_files -fileset constrs_1 -norecurse $src/merge_final_top.xdc
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_l6
set_property -dict [list CONFIG.C_NUM_OF_PROBES {5} CONFIG.C_DATA_DEPTH {1024} CONFIG.C_PROBE0_WIDTH {1} CONFIG.C_PROBE1_WIDTH {1} CONFIG.C_PROBE2_WIDTH {7} CONFIG.C_PROBE3_WIDTH {6} CONFIG.C_PROBE4_WIDTH {1}] [get_ips ila_l6]
generate_target all [get_ips ila_l6]
set_property top merge_final_top [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} { puts "RESULT synth FAILED"; exit 1 }
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
open_run impl_1
report_timing_summary -file $dir/timing.rpt
puts "RESULT $which synth=[get_property STATUS [get_runs synth_1]] impl=[get_property STATUS [get_runs impl_1]]"
