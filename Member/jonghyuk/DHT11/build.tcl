# Synthesis -> implementation -> bitstream, with a timing check.
# Run create_project.tcl first. Results are copied to ./output.
#
# GUI : source build.tcl
# Batch: vivado -mode batch -source build.tcl

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

set out [file join $root output]
file mkdir $out

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Build failed: [get_property STATUS [get_runs impl_1]]"
}

open_run impl_1
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing_summary.rpt]
report_utilization -file [file join $out utilization.rpt]
report_drc         -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]

if {[llength [get_timing_paths -quiet -delay_type max -slack_lesser_than 0]] ||
    [llength [get_timing_paths -quiet -delay_type min -slack_lesser_than 0]]} {
    error "Timing failed; see [file join $out timing_summary.rpt]"
}

set run_dir [get_property DIRECTORY [get_runs impl_1]]
file copy -force [file join $run_dir top_dht11.bit] $out
if {[file exists [file join $run_dir top_dht11.ltx]]} {
    file copy -force [file join $run_dir top_dht11.ltx] $out
}
puts "BUILD AND TIMING PASSED -> $out"
