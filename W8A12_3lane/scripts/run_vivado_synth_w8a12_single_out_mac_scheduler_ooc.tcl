set origin_dir [file normalize [file join [file dirname [info script]] .. ..]]
set build_dir  [file join $origin_dir build vivado_w8a12_single_out_mac_scheduler_ooc]
set report_dir [file join $origin_dir W8A12_3lane evidence resource A4_single_out_mac_scheduler_ooc]
set ref_dir    [file join $origin_dir W8A12_3lane evidence reference A0_single_conv]

file delete -force $build_dir
file mkdir $build_dir
file mkdir $report_dir
create_project w8a12_single_out_mac_scheduler_ooc $build_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]

add_files -fileset sources_1 [list \
    [file join $origin_dir rtl span span_w8a12_requant.v] \
    [file join $origin_dir W8A12_3lane rtl span w8a12_lane_mac_core.v] \
    [file join $origin_dir W8A12_3lane rtl span w8a12_single_out_mac_scheduler.v] \
    [file join $origin_dir W8A12_3lane rtl span w8a12_single_out_mac_scheduler_ooc_top.v] \
]
set_property include_dirs [list $ref_dir] [get_filesets sources_1]
update_compile_order -fileset sources_1

synth_design -top w8a12_single_out_mac_scheduler_ooc_top -mode out_of_context -flatten_hierarchy rebuilt
report_utilization -file [file join $report_dir utilization_ooc.rpt] -hierarchical
report_timing_summary -file [file join $report_dir timing_ooc.rpt]
write_checkpoint -force [file join $report_dir w8a12_single_out_mac_scheduler_ooc.dcp]
quit
