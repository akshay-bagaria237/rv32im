# program_fpga_robust.tcl
open_hw_manager
connect_hw_server -url localhost:3121
refresh_hw_server
# Try to find any target
set targets [get_hw_targets]
if { [llength $targets] == 0 } {
    puts "ERROR: No hardware targets found. Check your USB cable and power!"
    exit 1
}
open_hw_target [lindex $targets 0]
set device [get_hw_devices xc7a100t*]
current_hw_device $device
set bitstream_file [file join [pwd] "riscv-32im.runs/impl_1/projectile_top.bit"]
set_property PROGRAM.FILE $bitstream_file $device
program_hw_devices $device
refresh_hw_device $device
puts "SUCCESS: FPGA Programmed with Diagnostic Parabola Bitstream!"
close_hw_target
disconnect_hw_server
close_hw_manager
