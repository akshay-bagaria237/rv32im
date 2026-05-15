# run_bitstream.tcl
set project_path [file join [pwd] "riscv-32im.xpr"]
open_project $project_path

# Add demo files if not already in project
add_files -norecurse [file join [pwd] "projectile_demo/uart_tx.v"]
add_files -norecurse [file join [pwd] "projectile_demo/projectile_top.v"]

# Set projectile_top as top
set_property top projectile_top [current_fileset]
update_compile_order -fileset sources_1

# Reset runs for a clean build
reset_run synth_1

# Launch Synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Launch Implementation
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "Bitstream generation complete!"
if {[get_property PROGRESS [get_runs impl_1]] == "100%"} {
    puts "SUCCESS: Bitstream generated."
} else {
    puts "FAILURE: Bitstream generation failed."
}
