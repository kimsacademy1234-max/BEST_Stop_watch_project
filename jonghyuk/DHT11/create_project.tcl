# Creates a fresh Vivado 2020.2 project for the Basys3 DHT11 design.
#
# GUI : Tcl Console ->  cd D:/work/vivado_direc/20261029_DHT11 ; source create_project.tcl
# Batch: vivado -mode batch -source create_project.tcl
#
# Project goes to ./vivado/dht11_basys3.xpr. Re-running deletes and recreates it.
# Sources stay in ./src ./sim ./constrs (referenced, not copied).

set root      [file normalize [file dirname [info script]]]
set proj_name dht11_basys3
set proj_dir  [file join $root vivado]
set part      xc7a35tcpg236-1

create_project $proj_name $proj_dir -part $part -force
set_property target_language    Verilog [current_project]
set_property simulator_language Mixed   [current_project]

add_files -fileset sources_1 -norecurse [glob [file join $root src *.v]]
add_files -fileset constrs_1 -norecurse [file join $root constrs Basys-3-Master.xdc]
add_files -fileset sim_1     -norecurse [glob [file join $root sim *.v]]

# ILA (instantiated inside dht11_controller, like the SR04 lab):
#   probe0 = c_oe (FPGA drives LOW)   probe1 = i_dht11 (raw line)
#   probe2 = c_io_sync2 (synchronized) probe3 = c_state[3:0]
# 131072 samples at 100 MHz = 1.31 ms window.
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_0
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {4} \
    CONFIG.C_PROBE0_WIDTH  {1} \
    CONFIG.C_PROBE1_WIDTH  {1} \
    CONFIG.C_PROBE2_WIDTH  {1} \
    CONFIG.C_PROBE3_WIDTH  {4} \
    CONFIG.C_DATA_DEPTH    {131072} \
] [get_ips ila_0]
generate_target all [get_files ila_0.xci]

set_property top top_dht11    [get_filesets sources_1]
set_property top tb_dht1_ctrl [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {1000ms} -objects [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created: [file join $proj_dir $proj_name.xpr]"
puts "Design top: top_dht11   Sim top: tb_dht1_ctrl (board test: tb_dht2_top)"
