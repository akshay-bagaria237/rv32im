# Direct synthesis flow (no launch_runs, no runme.log lock contention).
# Use this when synth_1 is stuck or crashes/hangs in project run infrastructure.

open_project riscv-32im.xpr
update_compile_order -fileset sources_1

# Ensure top module is set for synthesis.
set_property top top_fpga [get_filesets sources_1]

# Run synthesis directly in this Tcl process.
synth_design -top top_fpga -part xc7a100tcsg324-1

# Save basic outputs for inspection.
write_checkpoint -force top_fpga_direct_synth.dcp
report_utilization -file top_fpga_direct_utilization.rpt

close_project
exit
