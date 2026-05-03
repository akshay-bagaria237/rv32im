# program_fpga.tcl
open_hw_manager
connect_hw_server -url localhost:3121
current_hw_target [get_hw_targets *]
open_hw_target
set device [get_hw_devices xc7a100t*]
current_hw_device $device
set bitstream_file [file join [pwd] "riscv-32im.runs/impl_1/projectile_top.bit"]
set_property PROGRAM.FILE $bitstream_file $device
program_hw_devices $device
refresh_hw_device $device
puts "FPGA Programmed Successfully!"
close_hw_target
disconnect_hw_server
close_hw_manager
