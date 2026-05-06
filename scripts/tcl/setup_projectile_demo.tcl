# setup_projectile_demo.tcl
# Run this script in Vivado Tcl Console to add the demo files and set the top module

# Add the newly created verilog files
add_files -norecurse "C:/Users/Lenovo/Downloads/riscv-32im/projectile_demo/uart_tx.v"
add_files -norecurse "C:/Users/Lenovo/Downloads/riscv-32im/projectile_demo/projectile_top.v"

# Set projectile_top as the top module
set_property top projectile_top [current_fileset]
update_compile_order -fileset sources_1

puts "Projectile Demo setup complete! You can now Generate Bitstream."