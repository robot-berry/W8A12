set opt_dcp ""
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_OPT_DCP)]} {
    set opt_dcp [file normalize $::env(JTAG_W8A12_TILE_WRITER_OPT_DCP)]
}
if {$opt_dcp eq "" || ![file exists $opt_dcp]} {
    error "JTAG_W8A12_TILE_WRITER_OPT_DCP is missing or does not exist: $opt_dcp"
}

set out_dir [file dirname $opt_dcp]
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_IMPL_DIR)]} {
    set out_dir [file normalize $::env(JTAG_W8A12_TILE_WRITER_IMPL_DIR)]
}
file mkdir $out_dir

set rpt_dir [file join [file dirname [file dirname $out_dir]] reports]
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_REPORT_DIR)]} {
    set rpt_dir [file normalize $::env(JTAG_W8A12_TILE_WRITER_REPORT_DIR)]
}
file mkdir $rpt_dir

set max_threads 1
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_MAX_THREADS)]} {
    set max_threads $::env(JTAG_W8A12_TILE_WRITER_MAX_THREADS)
}
set_param general.maxThreads $max_threads

set place_directive Default
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_PLACE_DIRECTIVE)]} {
    set place_directive $::env(JTAG_W8A12_TILE_WRITER_PLACE_DIRECTIVE)
}
set phys_opt_directive Default
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_PHYS_OPT_DIRECTIVE)]} {
    set phys_opt_directive $::env(JTAG_W8A12_TILE_WRITER_PHYS_OPT_DIRECTIVE)
}
set route_directive Default
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_ROUTE_DIRECTIVE)]} {
    set route_directive $::env(JTAG_W8A12_TILE_WRITER_ROUTE_DIRECTIVE)
}
set post_route_phys_opt_directive Default
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_POST_ROUTE_PHYS_OPT_DIRECTIVE)]} {
    set post_route_phys_opt_directive $::env(JTAG_W8A12_TILE_WRITER_POST_ROUTE_PHYS_OPT_DIRECTIVE)
}

puts "JTAG_W8A12_TILE_WRITER_RESUME_OPT_DCP=$opt_dcp"
puts "JTAG_W8A12_TILE_WRITER_RESUME_IMPL_DIR=$out_dir"
puts "JTAG_W8A12_TILE_WRITER_RESUME_REPORT_DIR=$rpt_dir"
puts "JTAG_W8A12_TILE_WRITER_MAX_THREADS=$max_threads"
puts "JTAG_W8A12_TILE_WRITER_PLACE_DIRECTIVE=$place_directive"
puts "JTAG_W8A12_TILE_WRITER_PHYS_OPT_DIRECTIVE=$phys_opt_directive"
puts "JTAG_W8A12_TILE_WRITER_ROUTE_DIRECTIVE=$route_directive"
puts "JTAG_W8A12_TILE_WRITER_POST_ROUTE_PHYS_OPT_DIRECTIVE=$post_route_phys_opt_directive"

puts "JTAG_W8A12_TILE_WRITER_RESUME_STAGE=open_checkpoint"
open_checkpoint $opt_dcp

puts "JTAG_W8A12_TILE_WRITER_RESUME_STAGE=place_design"
set place_args [list]
if {$place_directive ne "Default" && $place_directive ne ""} {
    lappend place_args -directive $place_directive
}
place_design {*}$place_args
if {$phys_opt_directive ne "None"} {
    set phys_opt_args [list]
    if {$phys_opt_directive ne "Default" && $phys_opt_directive ne ""} {
        lappend phys_opt_args -directive $phys_opt_directive
    }
    phys_opt_design {*}$phys_opt_args
}
write_checkpoint -force [file join $out_dir jwtw_wrapper_placed.dcp]
report_utilization -file [file join $rpt_dir jtag_w8a12_tile_writer_utilization_place.rpt]
report_timing_summary -file [file join $rpt_dir jtag_w8a12_tile_writer_timing_place.rpt]
catch {report_design_analysis -congestion -file [file join $rpt_dir jtag_w8a12_tile_writer_congestion_place.rpt]}

puts "JTAG_W8A12_TILE_WRITER_RESUME_STAGE=route_design"
set route_args [list]
if {$route_directive ne "Default" && $route_directive ne ""} {
    lappend route_args -directive $route_directive
}
if {[catch {route_design {*}$route_args} route_err route_opts]} {
    catch {report_route_status -file [file join $rpt_dir jtag_w8a12_tile_writer_route_status_failed.rpt]}
    catch {report_design_analysis -congestion -file [file join $rpt_dir jtag_w8a12_tile_writer_congestion_route_failed.rpt]}
    puts "JTAG_W8A12_TILE_WRITER_ROUTE_ERROR=$route_err"
    return -options $route_opts $route_err
}
if {$post_route_phys_opt_directive ne "None"} {
    set post_route_phys_opt_args [list]
    if {$post_route_phys_opt_directive ne "Default" && $post_route_phys_opt_directive ne ""} {
        lappend post_route_phys_opt_args -directive $post_route_phys_opt_directive
    }
    phys_opt_design {*}$post_route_phys_opt_args
}
write_checkpoint -force [file join $out_dir jwtw_wrapper_routed.dcp]

report_utilization -file [file join $rpt_dir jtag_w8a12_tile_writer_utilization_impl.rpt]
report_timing_summary -file [file join $rpt_dir jtag_w8a12_tile_writer_timing_impl.rpt]
report_route_status -file [file join $rpt_dir jtag_w8a12_tile_writer_route_status_impl.rpt]
catch {report_design_analysis -congestion -file [file join $rpt_dir jtag_w8a12_tile_writer_congestion_impl.rpt]}
catch {report_power -file [file join $rpt_dir jtag_w8a12_tile_writer_power_impl.rpt]}

puts "JTAG_W8A12_TILE_WRITER_RESUME_STAGE=write_bitstream"
write_bitstream -force [file join $out_dir jwtw_wrapper.bit]

puts "JTAG_W8A12_TILE_WRITER_RESUME_BIT=[file join $out_dir jwtw_wrapper.bit]"
puts "JTAG_W8A12_TILE_WRITER_RESUME_UTIL=[file join $rpt_dir jtag_w8a12_tile_writer_utilization_impl.rpt]"
puts "JTAG_W8A12_TILE_WRITER_RESUME_TIMING=[file join $rpt_dir jtag_w8a12_tile_writer_timing_impl.rpt]"
puts "PASS resume_jtag_w8a12_tile_writer_from_opt_dcp"
quit
