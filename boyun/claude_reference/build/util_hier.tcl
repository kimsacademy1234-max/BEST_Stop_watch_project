read_verilog [glob ../src/*.v]
read_xdc ../src/stopwatch_watch.xdc
synth_design -top stopwatch_watch -part xc7a35tcpg236-1 -flatten_hierarchy none
report_utilization -hierarchical -file util_hier_synth.rpt
