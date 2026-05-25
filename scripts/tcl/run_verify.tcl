# Open the project
open_project riscv-32im.xpr

# Update and Refresh all source files from disk
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Set the final testbench as the active simulation top
set_property top tb_pipeline_final [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Reset and Launch the simulation
launch_simulation

# Run the simulation to completion
run all
