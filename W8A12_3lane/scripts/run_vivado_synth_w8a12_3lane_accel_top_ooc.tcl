set origin_dir [file normalize [file join [file dirname [info script]] .. ..]]
set build_dir  [file join $origin_dir build vivado_w8a12_3lane_accel_top_ooc]
set report_dir [file join $origin_dir W8A12_3lane evidence top accel_top_ooc]

file delete -force $build_dir
file mkdir $build_dir
file mkdir $report_dir
create_project w8a12_3lane_accel_top_ooc $build_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]

add_files -fileset sources_1 [list \
    [file join $origin_dir W8A12_3lane rtl span w8a12_3lane_tile_pipeline_shell.v] \
    [file join $origin_dir W8A12_3lane rtl top w8a12_3lane_accel_top.v] \
    [file join $origin_dir W8A12_3lane rtl top w8a12_3lane_accel_top_ooc_top.v] \
]
update_compile_order -fileset sources_1

synth_design -top w8a12_3lane_accel_top_ooc_top -mode out_of_context -flatten_hierarchy rebuilt
create_clock -period 10.000 -name clk [get_ports clk]
report_utilization -file [file join $report_dir utilization_ooc.rpt] -hierarchical
report_timing_summary -file [file join $report_dir timing_ooc.rpt]
write_checkpoint -force [file join $report_dir w8a12_3lane_accel_top_ooc.dcp]
quit
