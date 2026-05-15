open_project riscv-32im.xpr

# Ensure latest RTL is picked up by project runs.
update_compile_order -fileset sources_1
remove_files [get_files -quiet -filter {IS_AVAILABLE == 0}]

# Disable incremental synthesis for synth_1 to avoid unstable incremental checkpoints.
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.INCREMENTAL_MODE off [get_runs synth_1]

# Clear stale run state and regenerate synth_1 scripts with updated properties.
reset_run synth_1
launch_runs synth_1 -scripts_only

close_project
exit
