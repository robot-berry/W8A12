proc w8a12_disable_tclapp_autoload {} {
    if {[llength [info commands ::tclapp::load_apps]] > 0} {
        catch {rename ::tclapp::load_apps ::tclapp::_w8a12_orig_load_apps}
    }
    proc ::tclapp::w8a12_stub_register_options {args} {
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
            proc ${full_ns}::register_options {args} {return 0}
        }
    }
    proc ::tclapp::load_apps {args} {
        ::tclapp::w8a12_stub_register_options {*}$args
        return ""
    }
    proc ::tclapp::load_app {args} {
        ::tclapp::w8a12_stub_register_options {*}$args
        return ""
    }
    if {[llength [info commands ::tclapp::tcl_store_on]] > 0} {
        catch {
            if {[llength [info commands ::tclapp::tcl_store_on_w8a12_orig]] == 0} {
                rename ::tclapp::tcl_store_on ::tclapp::tcl_store_on_w8a12_orig
                proc ::tclapp::tcl_store_on {} { return 0 }
            }
        }
    }
}

w8a12_disable_tclapp_autoload
catch {set_param labtools.enable_cs_server 0}

set bitstream_file ""
set base_addr 0xA0000000
set poll_count 1
set poll_delay_ms 100

for {set i 0} {$i < [llength $argv]} {incr i} {
    set key [lindex $argv $i]
    switch -- $key {
        "--bitstream" {
            incr i
            set bitstream_file [lindex $argv $i]
        }
        "--base" {
            incr i
            set base_addr [expr [lindex $argv $i]]
        }
        "--poll-count" {
            incr i
            set poll_count [expr [lindex $argv $i]]
        }
        "--poll-delay-ms" {
            incr i
            set poll_delay_ms [expr [lindex $argv $i]]
        }
        default {
            error "Unknown argument: $key"
        }
    }
}

set REG_STATUS       0x00
set REG_INPUT_FLAGS  0x04
set REG_INPUT_PIXEL  0x08
set REG_OUTPUT_PIXEL 0x0c
set REG_OUTPUT_FLAGS 0x10
set REG_COUNTER_IN   0x14
set REG_COUNTER_OUT  0x18
set REG_ERROR        0x1c
set REG_FRAME_CYCLES 0x20
set REG_FRAME_DONE   0x24
set REG_PERF_CTRL    0x28
set REG_E2E_CYCLES   0x2c
set REG_DEBUG_WRITEBACK_HASH  0x30
set REG_DEBUG_WRITEBACK_RANGE 0x34
set REG_DEBUG_WRITEBACK_FIRST 0x38
set REG_DEBUG_WRITEBACK_LAST  0x3c

proc parse_hex_data {value} {
    set s [string trim $value]
    set first [lindex $s 0]
    if {$first ne ""} {
        set s $first
    }
    regsub -all {[^0-9A-Fa-f]} $s "" s
    if {$s eq ""} {
        return 0
    }
    scan $s %x result
    return $result
}

proc axi_read32 {axi addr} {
    set name [format "rd_%08X_%08X" $addr [clock clicks]]
    create_hw_axi_txn $name $axi -type read -address [format 0x%08X $addr]
    run_hw_axi [get_hw_axi_txns $name]
    set data [get_property DATA [get_hw_axi_txns $name]]
    delete_hw_axi_txn [get_hw_axi_txns $name]
    return [parse_hex_data $data]
}

proc axi_write32 {axi addr value} {
    set name [format "wr_%08X_%08X" $addr [clock clicks]]
    create_hw_axi_txn $name $axi -type write -address [format 0x%08X $addr] -data [format 0x%08X $value]
    run_hw_axi [get_hw_axi_txns $name]
    delete_hw_axi_txn [get_hw_axi_txns $name]
}

proc bit {value index} {
    return [expr {($value >> $index) & 1}]
}

proc open_jtag_axi {bitstream_file} {
    open_hw_manager
    if {[llength [get_hw_servers -quiet]] == 0} {
        connect_hw_server
    }
    if {[llength [get_hw_targets -quiet]] == 0} {
        error "No hardware target found. Check USB-JTAG cable and board power."
    }
    set target [lindex [get_hw_targets -quiet] 0]
    current_hw_target $target
    open_hw_target

    set dev [lindex [get_hw_devices -quiet] 0]
    if {$dev eq ""} {
        error "No hardware device found on JTAG chain."
    }
    current_hw_device $dev

    if {$bitstream_file ne ""} {
        puts "Programming bitstream: $bitstream_file"
        set_property PROGRAM.FILE $bitstream_file $dev
        program_hw_devices $dev
        refresh_hw_device $dev
    } else {
        refresh_hw_device $dev
    }

    set axis [get_hw_axis -quiet *]
    if {[llength $axis] == 0} {
        error "No JTAG-to-AXI Master found. Regenerate bitstream with jtag_axi IP."
    }
    return [lindex $axis 0]
}

set axi [open_jtag_axi $bitstream_file]
puts "Using hw_axi: $axi"
puts [format "JTAG_W8A12_REG_BASE=0x%08X" $base_addr]

for {set i 0} {$i < $poll_count} {incr i} {
    set status       [axi_read32 $axi [expr {$base_addr + $REG_STATUS}]]
    set input_flags  [axi_read32 $axi [expr {$base_addr + $REG_INPUT_FLAGS}]]
    set input_pixel  [axi_read32 $axi [expr {$base_addr + $REG_INPUT_PIXEL}]]
    set output_pixel [axi_read32 $axi [expr {$base_addr + $REG_OUTPUT_PIXEL}]]
    set output_flags [axi_read32 $axi [expr {$base_addr + $REG_OUTPUT_FLAGS}]]
    set counter_in   [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_IN}]]
    set counter_out  [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_OUT}]]
    set errors       [axi_read32 $axi [expr {$base_addr + $REG_ERROR}]]
    set frame_cycles [axi_read32 $axi [expr {$base_addr + $REG_FRAME_CYCLES}]]
    set frame_done   [axi_read32 $axi [expr {$base_addr + $REG_FRAME_DONE}]]
    set perf_ctrl    [axi_read32 $axi [expr {$base_addr + $REG_PERF_CTRL}]]
    set e2e_cycles   [axi_read32 $axi [expr {$base_addr + $REG_E2E_CYCLES}]]
    set debug_writeback_hash  [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_HASH}]]
    set debug_writeback_range [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_RANGE}]]
    set debug_writeback_first [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_FIRST}]]
    set debug_writeback_last  [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_LAST}]]
    set perf_drain [expr {$perf_ctrl & 1}]

    axi_write32 $axi [expr {$base_addr + $REG_PERF_CTRL}] [expr {$perf_drain | 0x00000100}]
    set bank1_perf_ctrl [axi_read32 $axi [expr {$base_addr + $REG_PERF_CTRL}]]
    set debug_tail_feat0_hash     [axi_read32 $axi [expr {$base_addr + $REG_INPUT_FLAGS}]]
    set debug_src_feat0_hash      [axi_read32 $axi [expr {$base_addr + $REG_INPUT_PIXEL}]]
    set debug_src_b1_hash         [axi_read32 $axi [expr {$base_addr + $REG_OUTPUT_FLAGS}]]
    set debug_spab_b1_input_hash  [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_HASH}]]
    set debug_spab_b1_c1_hash     [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_RANGE}]]
    set debug_spab_b1_c2_hash     [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_FIRST}]]
    set debug_spab_b1_c3_hash     [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_LAST}]]

    axi_write32 $axi [expr {$base_addr + $REG_PERF_CTRL}] [expr {$perf_drain | 0x00000200}]
    set bank2_perf_ctrl [axi_read32 $axi [expr {$base_addr + $REG_PERF_CTRL}]]
    set debug_spab_b1_c1_raw_hash    [axi_read32 $axi [expr {$base_addr + $REG_INPUT_FLAGS}]]
    set debug_spab_b1_c2_replay_hash [axi_read32 $axi [expr {$base_addr + $REG_INPUT_PIXEL}]]
    set debug_spab_b1_c2_window_hash [axi_read32 $axi [expr {$base_addr + $REG_OUTPUT_FLAGS}]]
    set debug_spab_b1_residual_hash  [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_HASH}]]
    set debug_spab_b1_att_hash       [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_RANGE}]]
    set debug_bank2_tail_b1_hash     [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_FIRST}]]
    set debug_bank2_tail_rgb_q_hash  [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_LAST}]]

    axi_write32 $axi [expr {$base_addr + $REG_PERF_CTRL}] $perf_drain

    puts [format "JTAG_W8A12_REG_SAMPLE=%d" $i]
    puts [format "JTAG_W8A12_REG_STATUS=0x%08X" $status]
    puts [format "JTAG_W8A12_REG_INPUT_FLAGS=0x%08X" $input_flags]
    puts [format "JTAG_W8A12_REG_INPUT_PIXEL=0x%08X" $input_pixel]
    puts [format "JTAG_W8A12_REG_OUTPUT_PIXEL=0x%08X" $output_pixel]
    puts [format "JTAG_W8A12_REG_OUTPUT_FLAGS=0x%08X" $output_flags]
    puts [format "JTAG_W8A12_REG_COUNTER_IN=%d" $counter_in]
    puts [format "JTAG_W8A12_REG_COUNTER_OUT=%d" $counter_out]
    puts [format "JTAG_W8A12_REG_ERROR=0x%08X" $errors]
    puts [format "JTAG_W8A12_REG_FRAME_CYCLES=%d" $frame_cycles]
    puts [format "JTAG_W8A12_REG_FRAME_DONE=0x%08X" $frame_done]
    puts [format "JTAG_W8A12_REG_PERF_CTRL=0x%08X" $perf_ctrl]
    puts [format "JTAG_W8A12_REG_DEBUG_BANK1_PERF_CTRL=0x%08X" $bank1_perf_ctrl]
    puts [format "JTAG_W8A12_REG_DEBUG_BANK2_PERF_CTRL=0x%08X" $bank2_perf_ctrl]
    puts [format "JTAG_W8A12_REG_E2E_CYCLES=%d" $e2e_cycles]
    puts [format "JTAG_W8A12_REG_DEBUG_WRITEBACK_HASH=0x%08X" $debug_writeback_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_WRITEBACK_RANGE=0x%08X" $debug_writeback_range]
    puts [format "JTAG_W8A12_REG_DEBUG_WRITEBACK_FIRST=0x%08X" $debug_writeback_first]
    puts [format "JTAG_W8A12_REG_DEBUG_WRITEBACK_LAST=0x%08X" $debug_writeback_last]
    puts [format "JTAG_W8A12_REG_DEBUG_TAIL_B1_HASH=0x%08X" $input_flags]
    puts [format "JTAG_W8A12_REG_DEBUG_TAIL_B6_ACT1_HASH=0x%08X" $input_pixel]
    puts [format "JTAG_W8A12_REG_DEBUG_TAIL_RGB_Q_HASH=0x%08X" $output_flags]
    puts [format "JTAG_W8A12_REG_DEBUG_TAIL_FEAT0_HASH=0x%08X" $debug_tail_feat0_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SRC_FEAT0_HASH=0x%08X" $debug_src_feat0_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SRC_B1_HASH=0x%08X" $debug_src_b1_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SPAB_B1_INPUT_HASH=0x%08X" $debug_spab_b1_input_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SPAB_B1_C1_HASH=0x%08X" $debug_spab_b1_c1_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SPAB_B1_C2_HASH=0x%08X" $debug_spab_b1_c2_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SPAB_B1_C3_HASH=0x%08X" $debug_spab_b1_c3_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SPAB_B1_C1_RAW_HASH=0x%08X" $debug_spab_b1_c1_raw_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SPAB_B1_C2_REPLAY_HASH=0x%08X" $debug_spab_b1_c2_replay_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SPAB_B1_C2_WINDOW_HASH=0x%08X" $debug_spab_b1_c2_window_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SPAB_B1_RESIDUAL_HASH=0x%08X" $debug_spab_b1_residual_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_SPAB_B1_ATT_HASH=0x%08X" $debug_spab_b1_att_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_BANK2_TAIL_B1_HASH=0x%08X" $debug_bank2_tail_b1_hash]
    puts [format "JTAG_W8A12_REG_DEBUG_BANK2_TAIL_RGB_Q_HASH=0x%08X" $debug_bank2_tail_rgb_q_hash]
    if {$counter_out > 0} {
        puts [format "JTAG_W8A12_REG_DEBUG_WRITEBACK_RANGE_DECODE=min=%d max=%d count=%d" \
            [expr {($debug_writeback_range >> 24) & 0xff}] \
            [expr {($debug_writeback_range >> 16) & 0xff}] \
            [expr {$debug_writeback_range & 0xffff}]]
    } else {
        puts [format "JTAG_W8A12_REG_DEBUG_WRITER_LIVE=valid_h=%d valid_w=%d tile_last=%d sched_done=%d sched_busy=%d writer_busy=%d front_busy=%d writer_done=%d front_done=%d writer_error=%d front_error=%d tile_is_full=%d sched_tile_ready=%d sched_tile_valid=%d sched_error=%d state=%d" \
            [expr {($debug_writeback_range >> 24) & 0xff}] [expr {($debug_writeback_range >> 16) & 0xff}] \
            [bit $debug_writeback_range 15] [bit $debug_writeback_range 14] [bit $debug_writeback_range 13] \
            [bit $debug_writeback_range 12] [bit $debug_writeback_range 11] [bit $debug_writeback_range 10] \
            [bit $debug_writeback_range 9] [bit $debug_writeback_range 8] [bit $debug_writeback_range 7] \
            [bit $debug_writeback_range 6] [bit $debug_writeback_range 5] [bit $debug_writeback_range 4] \
            [bit $debug_writeback_range 3] [expr {$debug_writeback_range & 0x7}]]
    }
    flush stdout
    if {$i + 1 < $poll_count} {
        after $poll_delay_ms
    }
}

close_hw_manager
