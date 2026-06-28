set origin_dir [file normalize [file join [file dirname [info script]] .. ..]]
set proj_dir   [file join $origin_dir build vivado_w8a12_3lane_accel_top_sim]

file delete -force $proj_dir
file mkdir $proj_dir
create_project w8a12_3lane_accel_top_sim $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -fileset sources_1 [list \
    [file join $origin_dir W8A12_3lane rtl span w8a12_3lane_tile_pipeline_shell.v] \
    [file join $origin_dir W8A12_3lane rtl top w8a12_3lane_accel_top.v] \
]

add_files -fileset sim_1 [file join $origin_dir W8A12_3lane sim tb_w8a12_3lane_accel_top.sv]
set_property top tb_w8a12_3lane_accel_top [get_filesets sim_1]
set_property xsim.simulate.runtime 20us [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation
quit
