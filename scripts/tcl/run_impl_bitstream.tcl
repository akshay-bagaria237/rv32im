open_project riscv-32im.xpr

reset_run synth_1
reset_run impl_1

launch_runs synth_1 -jobs 8
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

open_run impl_1
set bit_path [get_property BITSTREAM.FILE [current_design]]
puts "BITSTREAM_PATH=$bit_path"

close_project
