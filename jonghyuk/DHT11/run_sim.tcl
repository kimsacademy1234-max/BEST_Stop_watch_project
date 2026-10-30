# Runs both testbenches with xsim and checks "TOTAL MISMATCH = 0".
# Run create_project.tcl first.
#
# GUI : source run_sim.tcl        (project may already be open)
# Batch: vivado -mode batch -source run_sim.tcl

set root [file normalize [file dirname [info script]]]
set xpr  [file join $root vivado dht11_basys3.xpr]
if {[catch {current_project}]} { open_project $xpr }

# Add any source/testbench files that are not in the project yet (e.g. new files)
foreach f [glob -nocomplain [file join $root src *.v]] {
    if {![llength [get_files -quiet $f]]} { add_files -fileset sources_1 -norecurse $f; puts "Added $f" }
}
foreach f [glob -nocomplain [file join $root sim *.v]] {
    if {![llength [get_files -quiet $f]]} { add_files -fileset sim_1 -norecurse $f; puts "Added $f" }
}
update_compile_order -fileset sources_1

set sim_dir [file join $root vivado dht11_basys3.sim sim_1 behav xsim]
set failed {}

foreach tb {tb_dht1_ctrl tb_dht2_top tb_dht3_core} {
    set_property top $tb [get_filesets sim_1]
    update_compile_order -fileset sim_1
    catch {launch_simulation -simset sim_1 -mode behavioral} msg
    catch {close_sim -force}
    set log [file join $sim_dir simulate.log]
    set text ""
    if {[file exists $log]} {
        set fh [open $log r]; set text [read $fh]; close $fh
    }
    if {[string first "TOTAL MISMATCH = 0" $text] >= 0} {
        puts "SIM PASS: $tb"
    } else {
        puts "SIM FAIL: $tb  (see $log)"
        lappend failed $tb
    }
}

set_property top tb_dht1_ctrl [get_filesets sim_1]
if {[llength $failed]} { error "Simulation failed: $failed" }
puts "ALL SIMULATIONS PASSED"
