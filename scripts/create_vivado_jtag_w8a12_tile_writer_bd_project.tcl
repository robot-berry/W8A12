set origin_dir [file normalize [file join [file dirname [info script]] ..]]
set vivado_dir [file join $origin_dir vivado]
set proj_dir   [file join $vivado_dir jwtw]
set bd_name    jwtw

if {[info exists ::env(JTAG_W8A12_TILE_WRITER_PROJECT_DIR)]} {
  set proj_dir [file normalize $::env(JTAG_W8A12_TILE_WRITER_PROJECT_DIR)]
}

set img_w 32
set tile_w 32
set tile_h 32
set halo 21
set pl_freq_mhz 100
set out_lanes 8
set tap_lanes 16
set scale_lanes 2
set debug_export_level 2

if {[info exists ::env(JTAG_W8A12_TILE_WRITER_IMG_W)]} {
  set img_w $::env(JTAG_W8A12_TILE_WRITER_IMG_W)
}
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_TILE_W)]} {
  set tile_w $::env(JTAG_W8A12_TILE_WRITER_TILE_W)
}
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_TILE_H)]} {
  set tile_h $::env(JTAG_W8A12_TILE_WRITER_TILE_H)
}
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_HALO)]} {
  set halo $::env(JTAG_W8A12_TILE_WRITER_HALO)
}
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_PL_FREQ_MHZ)]} {
  set pl_freq_mhz $::env(JTAG_W8A12_TILE_WRITER_PL_FREQ_MHZ)
}
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_OUT_LANES)]} {
  set out_lanes $::env(JTAG_W8A12_TILE_WRITER_OUT_LANES)
}
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_TAP_LANES)]} {
  set tap_lanes $::env(JTAG_W8A12_TILE_WRITER_TAP_LANES)
}
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_SCALE_LANES)]} {
  set scale_lanes $::env(JTAG_W8A12_TILE_WRITER_SCALE_LANES)
}
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_DEBUG_EXPORT_LEVEL)]} {
  set debug_export_level $::env(JTAG_W8A12_TILE_WRITER_DEBUG_EXPORT_LEVEL)
}

proc jwtw_ceil_log2_width {value} {
  if {$value <= 2} {
    return 1
  }
  set width 0
  set limit 1
  while {$limit < $value} {
    set limit [expr {$limit * 2}]
    incr width
  }
  return $width
}

set scale 4
set in_pixels [expr {$img_w * $img_w}]
set out_pixels [expr {$in_pixels * $scale * $scale}]
set in_idx_w [jwtw_ceil_log2_width $in_pixels]
set out_idx_w [jwtw_ceil_log2_width $out_pixels]

file mkdir $vivado_dir
file mkdir [file join $vivado_dir logs]
file delete -force $proj_dir

create_project jwtw $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_sources [list \
    [file join $origin_dir rtl board sr_tile_scheduler.v] \
    [file join $origin_dir rtl board sr_tile_halo_fetch_stream_shell.v] \
    [file join $origin_dir rtl board sr_tile_rgb_buffer_streamer.v] \
    [file join $origin_dir rtl board sr_stream_cropper.v] \
    [file join $origin_dir rtl board sr_tile_output_writer.v] \
    [file join $origin_dir rtl board sr_feature_tile_buffer_streamer.v] \
    [file join $origin_dir rtl board sr_tile_halo_fetch_w8a12_conv1_shell.v] \
    [file join $origin_dir rtl board sr_tile_halo_fetch_w8a12_conv1_spab6_scheduler_shell.v] \
    [file join $origin_dir rtl board sr_tile_halo_fetch_w8a12_front_tail_rgb_shell.v] \
    [file join $origin_dir rtl board sr_tile_halo_fetch_w8a12_front_tail_writer_shell.v] \
    [file join $origin_dir rtl board sr_jtag_w8a12_tile_writer_endpoint.v] \
    [file join $origin_dir rtl board sr_w8a12_block_group_single_out_tile_engine.v] \
    [file join $origin_dir rtl board sr_w8a12_block_group_single_out_buffered_tile_engine.v] \
    [file join $origin_dir rtl board sr_w8a12_block_group_attention_residual_tile_engine.v] \
    [file join $origin_dir rtl board sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine.v] \
    [file join $origin_dir rtl span span_w8a12_generated_select.vh] \
    [file join $origin_dir rtl span span_rgb_line_window3x3.v] \
    [file join $origin_dir rtl span span_w8a12_feature_line_window3x3.v] \
    [file join $origin_dir rtl span span_w8a12_rgb_normalize.v] \
    [file join $origin_dir rtl span span_w8a12_rgb_window_normalize.v] \
    [file join $origin_dir rtl span span_w8a12_weight_group_rom.v] \
    [file join $origin_dir rtl span span_w8a12_requant_pipe.v] \
    [file join $origin_dir rtl span span_w8a12_parallel_mac_tile.v] \
    [file join $origin_dir rtl span span_w8a12_parallel_group_accum_engine.v] \
    [file join $origin_dir rtl span span_w8a12_parallel_conv_vector_streamed_weights.v] \
    [file join $origin_dir rtl span span_w8a12_conv1_streamed_frontend.v] \
    [file join $origin_dir rtl span span_w8a12_requant.v] \
    [file join $origin_dir rtl span span_w8a12_block_group_const_bank.v] \
    [file join $origin_dir rtl span span_w8a12_block_group_unary_lut.v] \
    [file join $origin_dir rtl span span_w8a12_block_group_attention.v] \
    [file join $origin_dir rtl span span_w8a12_block_group_single_out_conv_layer.v] \
    [file join $origin_dir rtl span span_w8a12_block_group_single_out_conv_act_kernel.v] \
    [file join $origin_dir rtl span span_w8a12_feature_conv_streamed_frontend.v] \
    [file join $origin_dir rtl span span_w8a12_conv2_streamed_frontend.v] \
    [file join $origin_dir rtl span span_w8a12_conv1x1_streamed_frontend.v] \
    [file join $origin_dir rtl span span_w8a12_conv_cat_scale_concat.v] \
    [file join $origin_dir rtl span span_w8a12_upsampler0_streamed_frontend.v] \
    [file join $origin_dir rtl span span_w8a12_pixelshuffle_x4_streamed_rgb.v] \
    [file join $origin_dir rtl span span_w8a12_upsampler0_pixelshuffle_streamed_rgb.v] \
    [file join $origin_dir rtl span span_w8a12_tail_streamed_rgb.v] \
    [file join $origin_dir rtl generated reds_span_x4_f48_w8a12 span_w8a12_layers.vh] \
    [file join $origin_dir rtl generated reds_span_x4_f48_w8a12 span_w8a12_rgb_norm.vh] \
    [file join $origin_dir rtl generated reds_span_x4_f48_w8a12 postprocess span_w8a12_postprocess.vh] \
    [file join $origin_dir rtl generated reds_span_x4_f48_w8a12 block_group span_w8a12_block_group_mem.vh] \
]

add_files -fileset sources_1 $rtl_sources
set_property include_dirs [list [file join $origin_dir rtl] [file join $origin_dir rtl generated]] [get_filesets sources_1]
update_compile_order -fileset sources_1

create_bd_design $bd_name
current_bd_design $bd_name

set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:* ps]
set_property -dict [list \
  CONFIG.PSU__FPGA_PL0_ENABLE {1} \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $pl_freq_mhz \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL} \
  CONFIG.PSU__USE__FABRIC__RST {1} \
  CONFIG.PSU__USE__M_AXI_GP0 {0} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__M_AXI_GP2 {0} \
  CONFIG.PSU__USE__S_AXI_GP0 {0} \
  CONFIG.PSU__USE__S_AXI_GP1 {0} \
  CONFIG.PSU__USE__S_AXI_GP2 {0} \
  CONFIG.PSU__USE__S_AXI_GP3 {0} \
  CONFIG.PSU__USE__S_AXI_GP4 {0} \
  CONFIG.PSU__USE__S_AXI_GP5 {0} \
  CONFIG.PSU__USE__S_AXI_GP6 {0} \
  CONFIG.PSU__USE__IRQ0 {0} \
] $ps

set jtag_axi [create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:* ja]
set axi_ic   [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:* ai]
set rst      [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* rst]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $axi_ic

set sr [create_bd_cell -type module -reference sr_jtag_w8a12_tile_writer_endpoint sr0]
set_property -dict [list \
  CONFIG.IMG_W $img_w \
  CONFIG.TILE_W $tile_w \
  CONFIG.TILE_H $tile_h \
  CONFIG.HALO $halo \
  CONFIG.SCALE $scale \
  CONFIG.IN_PIXELS $in_pixels \
  CONFIG.OUT_PIXELS $out_pixels \
  CONFIG.IN_IDX_W $in_idx_w \
  CONFIG.OUT_IDX_W $out_idx_w \
  CONFIG.OUT_LANES $out_lanes \
  CONFIG.TAP_LANES $tap_lanes \
  CONFIG.SCALE_LANES $scale_lanes \
  CONFIG.DEBUG_EXPORT_LEVEL $debug_export_level \
] $sr

connect_bd_intf_net [get_bd_intf_pins ja/M_AXI] [get_bd_intf_pins ai/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ai/M00_AXI] [get_bd_intf_pins sr0/s_axi]

connect_bd_net [get_bd_pins ps/pl_clk0] \
  [get_bd_pins ja/aclk] \
  [get_bd_pins ai/ACLK] \
  [get_bd_pins ai/S00_ACLK] \
  [get_bd_pins ai/M00_ACLK] \
  [get_bd_pins rst/slowest_sync_clk] \
  [get_bd_pins sr0/s_axi_aclk]

connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins rst/ext_reset_in]
connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
  [get_bd_pins ja/aresetn] \
  [get_bd_pins ai/S00_ARESETN] \
  [get_bd_pins ai/M00_ARESETN] \
  [get_bd_pins sr0/s_axi_aresetn]
connect_bd_net [get_bd_pins rst/interconnect_aresetn] [get_bd_pins ai/ARESETN]

assign_bd_address
set sr_seg [get_bd_addr_segs -quiet sr0/s_axi/*]
if {[llength $sr_seg] > 0} {
  assign_bd_address -offset 0xA0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces ja/Data] [lindex $sr_seg 0] -force
}

validate_bd_design
save_bd_design

set bd_file [get_files [file join $proj_dir jwtw.srcs sources_1 bd $bd_name ${bd_name}.bd]]
catch { set_property synth_checkpoint_mode None $bd_file }
catch { set_property generate_synth_checkpoint false $bd_file }

make_wrapper -files [get_files [file join $proj_dir jwtw.srcs sources_1 bd $bd_name ${bd_name}.bd]] -top
add_files -norecurse [file join $proj_dir jwtw.gen sources_1 bd $bd_name hdl ${bd_name}_wrapper.v]
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "Created JTAG W8A12 tile-writer Block Design project:"
puts "  [file join $proj_dir jwtw.xpr]"
puts "Data path:"
puts "  USB-JTAG -> JTAG-to-AXI Master -> on-chip LR buffer -> hardware tile/halo W8A12 writer -> on-chip HR buffer"
puts "AXI base:"
puts "  0xA0000000"
puts "IMG_W=$img_w"
puts "TILE_W=$tile_w"
puts "TILE_H=$tile_h"
puts "HALO=$halo"
puts "IN_PIXELS=$in_pixels"
puts "OUT_PIXELS=$out_pixels"
puts "IN_IDX_W=$in_idx_w"
puts "OUT_IDX_W=$out_idx_w"
puts "PL_FREQ_MHZ=$pl_freq_mhz"
puts "DEBUG_EXPORT_LEVEL=$debug_export_level"
