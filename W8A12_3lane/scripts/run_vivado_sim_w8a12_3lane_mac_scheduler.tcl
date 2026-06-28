set origin_dir [file normalize [file join [file dirname [info script]] .. ..]]
set proj_dir   [file join $origin_dir build vivado_w8a12_3lane_mac_scheduler_sim]
set ref_dir    [file join $origin_dir W8A12_3lane evidence reference A0_single_conv]

puts "INFO: W8A12 3-lane MAC scheduler sim"
puts "INFO: origin_dir=$origin_dir"
puts "INFO: proj_dir=$proj_dir"
puts "INFO: ref_dir=$ref_dir"
if {![file exists [file join $ref_dir a0_3lane_files.vh]]} {
    error "missing A0 include file: [file join $ref_dir a0_3lane_files.vh]"
}

file delete -force $proj_dir
file mkdir $proj_dir
create_project w8a12_3lane_mac_scheduler_sim $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -fileset sources_1 [list \
    [file join $origin_dir rtl span span_w8a12_requant.v] \
    [file join $origin_dir W8A12_3lane rtl span w8a12_lane_mac_core.v] \
    [file join $origin_dir W8A12_3lane rtl span w8a12_single_out_mac_scheduler.v] \
    [file join $origin_dir W8A12_3lane rtl span w8a12_single_lane_mac_scheduler.v] \
    [file join $origin_dir W8A12_3lane rtl span w8a12_3lane_mac_scheduler.v] \
]

add_files -fileset sim_1 [file join $origin_dir W8A12_3lane sim tb_w8a12_3lane_mac_scheduler.sv]
set_property include_dirs [list $ref_dir] [get_filesets sim_1]
set_property top tb_w8a12_3lane_mac_scheduler [get_filesets sim_1]
set_property xsim.simulate.runtime 400us [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation
quit
