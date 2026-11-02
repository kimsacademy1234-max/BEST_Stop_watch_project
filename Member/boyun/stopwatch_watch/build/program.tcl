# 보드(Basys-3)에 stopwatch_watch.bit 올리기 (Vivado 배치)
# 실행: build 폴더에서  C:\Xilinx\Vivado\2022.2\bin\vivado.bat -mode batch -nojournal -nolog -source program.tcl
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7a35t*] 0]
current_hw_device $dev
set_property PROGRAM.FILE [file normalize stopwatch_watch.bit] $dev
program_hw_devices $dev
puts "PROGRAMMED: [get_property PROGRAM.FILE $dev]"
close_hw_target
disconnect_hw_server
