# Clean, non-incremental synthesis runner for top_fpga
# Use when synth_1 appears stuck or crashes near Technology Mapping.

open_project riscv-32im.xpr

# Refresh sources from disk so recent RTL edits are picked up.
update_compile_order -fileset sources_1

# Force full synthesis (disable incremental checkpoint flow).
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.INCREMENTAL_MODE off [get_runs synth_1]

# Reset stale run artifacts/scripts and relaunch.
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1

set run_status [get_property STATUS [get_runs synth_1]]
puts "synth_1 STATUS: $run_status"

close_project
exit
