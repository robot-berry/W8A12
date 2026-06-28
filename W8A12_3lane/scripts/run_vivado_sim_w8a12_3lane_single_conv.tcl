set origin_dir [file normalize [file join [file dirname [info script]] .. ..]]
set proj_dir   [file join $origin_dir build vivado_w8a12_3lane_single_conv_sim]
set ref_dir    [file join $origin_dir W8A12_3lane evidence reference A0_single_conv]

file delete -force $proj_dir
file mkdir $proj_dir
create_project w8a12_3lane_single_conv_sim $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_sources [list \
    [file join $origin_dir rtl span span_w8a12_requant.v] \
    [file join $origin_dir rtl span span_w8a12_layer_const_bank.v] \
    [file join $origin_dir rtl span span_w8a12_conv_layer.v] \
    [file join $origin_dir W8A12_3lane rtl span w8a12_3lane_conv_layer.v] \
]

add_files -fileset sources_1 $rtl_sources
set_property include_dirs [list [file join $origin_dir rtl] $ref_dir] [get_filesets sources_1]

add_files -fileset sim_1 $rtl_sources
add_files -fileset sim_1 [file join $origin_dir W8A12_3lane sim tb_w8a12_3lane_single_conv.sv]
set_property include_dirs [list [file join $origin_dir rtl] $ref_dir] [get_filesets sim_1]
set_property top tb_w8a12_3lane_single_conv [get_filesets sim_1]
set_property xsim.simulate.runtime 20ms [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation
close_sim
quit
