# Tcl Script to setup Timing Diagram Simulation (Robust version for paths with spaces)
set proj_dir [get_property DIRECTORY [current_project]]

# Construct paths using 'file join' to handle spaces and separators correctly
set tb_path [file normalize [file join $proj_dir "riscv-32im.srcs" "sources_1" "imports" "5-stage-version" "testBenches" "tb_pipeline_timing.v"]]
set imem_path [file normalize [file join $proj_dir "imem.hex"]]
set dmem_path [file normalize [file join $proj_dir "dmem.hex"]]

puts "--- Adding Timing Testbench ---"
if {[file exists $tb_path]} {
    add_files -fileset sim_1 -norecurse [list $tb_path]
} else {
    puts "ERROR: Could not find testbench at $tb_path"
}

puts "--- Adding Hex Files to Simulation ---"
if {[file exists $imem_path] && [file exists $dmem_path]} {
    add_files -fileset sim_1 -norecurse [list $imem_path $dmem_path]
} else {
    puts "ERROR: Hex files not found in project root."
}

puts "--- Setting tb_pipeline_timing as Top ---"
set_property top tb_pipeline_timing [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

puts "--- Updating Compile Order ---"
update_compile_order -fileset sim_1

puts "--- SETUP COMPLETE ---"
puts "You can now click 'Run Behavioral Simulation' in the Flow Navigator."
