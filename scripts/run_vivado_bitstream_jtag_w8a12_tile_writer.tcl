set origin_dir [file normalize [file join [file dirname [info script]] ..]]
set script_dir [file join $origin_dir scripts]

if {[llength [info commands ::tclapp::load_apps]] > 0} {
    catch {rename ::tclapp::load_apps ::tclapp::jwtw_original_load_apps}
    proc ::tclapp::jwtw_stub_register_options {args} {
        set ns ""
        for {set i 0} {$i < [llength $args]} {incr i} {
            if {[lindex $args $i] eq "-namespace" && [expr {$i + 1}] < [llength $args]} {
                set ns [lindex $args [expr {$i + 1}]]
            }
        }
        if {$ns eq "" && [llength $args] > 0} {
            set ns [lindex $args end]
        }
        if {$ns ne ""} {
            set full_ns "::tclapp::${ns}"
            namespace eval $full_ns {}
            proc ${full_ns}::register_options {args} {
                puts "JTAG_W8A12_TILE_WRITER_TCLAPP_REGISTER_OPTIONS_STUB=[namespace current] args=$args"
                return 0
            }
        }
    }
    proc ::tclapp::load_apps {args} {
        puts "JTAG_W8A12_TILE_WRITER_TCLAPP_LOAD_APPS_SKIPPED=$args"
        ::tclapp::jwtw_stub_register_options {*}$args
        return ""
    }
    proc ::tclapp::load_app {args} {
        puts "JTAG_W8A12_TILE_WRITER_TCLAPP_LOAD_APP_SKIPPED=$args"
        ::tclapp::jwtw_stub_register_options {*}$args
        return ""
    }
}

source [file join $script_dir create_vivado_jtag_w8a12_tile_writer_bd_project.tcl]

set proj_dir [file join $origin_dir vivado jwtw]
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_PROJECT_DIR)]} {
    set proj_dir [file normalize $::env(JTAG_W8A12_TILE_WRITER_PROJECT_DIR)]
}
set rpt_dir  [file join $proj_dir reports]
file mkdir $rpt_dir

set max_threads 1
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_MAX_THREADS)]} {
    set max_threads $::env(JTAG_W8A12_TILE_WRITER_MAX_THREADS)
}
set synth_directive RuntimeOptimized
if {[info exists ::env(JTAG_W8A12_TILE_WRITER_SYNTH_DIRECTIVE)]} {
    set synth_directive $::env(JTAG_W8A12_TILE_WRITER_SYNTH_DIRECTIVE)
}
set_param general.maxThreads $max_threads
puts "JTAG_W8A12_TILE_WRITER_MAX_THREADS=$max_threads"
puts "JTAG_W8A12_TILE_WRITER_SYNTH_DIRECTIVE=$synth_directive"

set bit_dir [file join $proj_dir jwtw.runs impl_1]
file mkdir $bit_dir

set bd_file [get_files [file join $proj_dir jwtw.srcs sources_1 bd $bd_name ${bd_name}.bd]]
puts "JTAG_W8A12_TILE_WRITER_STAGE=generate_target"
generate_target all $bd_file
update_compile_order -fileset sources_1

# Keep the flow in the parent Vivado process.  The managed run wrapper can
# fail before it records useful diagnostics on this host.
set synth_args [list \
    -top ${bd_name}_wrapper \
    -part xczu19eg-ffvc1760-2-i \
    -flatten_hierarchy none \
]
if {$synth_directive ne "Default"} {
    lappend synth_args -directive $synth_directive
}

puts "JTAG_W8A12_TILE_WRITER_STAGE=synth_design"
synth_design {*}$synth_args
write_checkpoint -force [file join $bit_dir jwtw_wrapper_synth.dcp]
report_utilization -file [file join $rpt_dir jtag_w8a12_tile_writer_utilization_synth.rpt]

puts "JTAG_W8A12_TILE_WRITER_STAGE=opt_design"
opt_design
write_checkpoint -force [file join $bit_dir jwtw_wrapper_opt.dcp]

puts "JTAG_W8A12_TILE_WRITER_STAGE=place_design"
place_design
phys_opt_design
write_checkpoint -force [file join $bit_dir jwtw_wrapper_placed.dcp]
report_utilization -file [file join $rpt_dir jtag_w8a12_tile_writer_utilization_place.rpt]
report_timing_summary -file [file join $rpt_dir jtag_w8a12_tile_writer_timing_place.rpt]

puts "JTAG_W8A12_TILE_WRITER_STAGE=route_design"
route_design
phys_opt_design
write_checkpoint -force [file join $bit_dir jwtw_wrapper_routed.dcp]

report_utilization -file [file join $rpt_dir jtag_w8a12_tile_writer_utilization_impl.rpt]
report_timing_summary -file [file join $rpt_dir jtag_w8a12_tile_writer_timing_impl.rpt]

puts "JTAG_W8A12_TILE_WRITER_STAGE=write_bitstream"
write_bitstream -force [file join $bit_dir jwtw_wrapper.bit]

puts "JTAG_W8A12_TILE_WRITER_PROJECT=[file join $proj_dir jwtw.xpr]"
puts "JTAG_W8A12_TILE_WRITER_BIT=[file join $bit_dir jwtw_wrapper.bit]"
puts "JTAG_W8A12_TILE_WRITER_UTIL=[file join $rpt_dir jtag_w8a12_tile_writer_utilization_impl.rpt]"
puts "JTAG_W8A12_TILE_WRITER_TIMING=[file join $rpt_dir jtag_w8a12_tile_writer_timing_impl.rpt]"

quit
