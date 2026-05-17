# cleanup_and_sync.tcl
# Run this in the Vivado Tcl Console

puts "Cleaning up missing file references..."
remove_files [get_files -filter {IS_AVAILABLE == 0}]

puts "Syncing unified testbench..."
set tb_file "riscv-32im.srcs/sources_1/imports/5-stage-version/testBenches/tb_pipeline_final.v"
if {[file exists $tb_file]} {
    add_files -norecurse $tb_file
    set_property top tb_pipeline_final [get_filesets sim_1]
    set_property top_lib xil_defaultlib [get_filesets sim_1]
    update_compile_order -fileset sim_1
    puts "SUCCESS: tb_pipeline_final is now the top simulation module."
} else {
    puts "ERROR: tb_pipeline_final.v not found on disk!"
}
