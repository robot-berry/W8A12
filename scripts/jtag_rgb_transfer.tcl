# Vivado Hardware Manager 通过 USB-JTAG 传输 RGB888 图像。
#
# 前提：
#   1. bitstream 中已经包含 JTAG-to-AXI Master IP。
#   2. JTAG-to-AXI Master 能访问 sr_jtag_rgb_transfer_endpoint。
#   3. sr_jtag_rgb_transfer_endpoint 基地址为 0xA0000000。
#
# 用法示例：
#   vivado -mode batch -source scripts/jtag_rgb_transfer.tcl -tclargs \
#     --input input.rgb --output output.rgb --bitstream path/to/top.bit

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

set input_file ""
set output_file ""
set bitstream_file ""
set base_addr 0xA0000000
set img_w 64
set img_h 64
set scale 2
set perf_only 0
set max_output_pixels 0
set input_ready_tries 1000000
set output_wait_tries 5000000
set perf_wait_tries 5000000

for {set i 0} {$i < [llength $argv]} {incr i} {
    set key [lindex $argv $i]
    switch -- $key {
        "--input" {
            incr i
            set input_file [lindex $argv $i]
        }
        "--output" {
            incr i
            set output_file [lindex $argv $i]
        }
        "--bitstream" {
            incr i
            set bitstream_file [lindex $argv $i]
        }
        "--base" {
            incr i
            set base_addr [expr [lindex $argv $i]]
        }
        "--width" {
            incr i
            set img_w [expr [lindex $argv $i]]
        }
        "--height" {
            incr i
            set img_h [expr [lindex $argv $i]]
        }
        "--scale" {
            incr i
            set scale [expr [lindex $argv $i]]
        }
        "--perf-only" {
            set perf_only 1
        }
        "--max-output-pixels" {
            incr i
            set max_output_pixels [expr [lindex $argv $i]]
        }
        "--input-ready-tries" {
            incr i
            set input_ready_tries [expr [lindex $argv $i]]
        }
        "--output-wait-tries" {
            incr i
            set output_wait_tries [expr [lindex $argv $i]]
        }
        "--perf-wait-tries" {
            incr i
            set perf_wait_tries [expr [lindex $argv $i]]
        }
        default {
            error "Unknown argument: $key"
        }
    }
}

if {$input_file eq "" || $output_file eq ""} {
    error "Usage: --input input.rgb --output output.rgb \[--bitstream top.bit\] \[--base 0xA0000000\]"
}

set REG_STATUS       0x00
set REG_INPUT_FLAGS  0x04
set REG_INPUT_PIXEL  0x08
set REG_OUTPUT_PIXEL 0x0c
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

set STATUS_IN_READY  0x40
set STATUS_OUT_VALID 0x80

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

proc axi_write32 {axi addr value} {
    set name [format "wr_%08X_%08X" $addr [clock clicks]]
    create_hw_axi_txn $name $axi -type write -address [format 0x%08X $addr] -data [format %08X [expr {$value & 0xffffffff}]]
    run_hw_axi [get_hw_axi_txns $name]
    delete_hw_axi_txn [get_hw_axi_txns $name]
}

proc axi_read32 {axi addr} {
    set name [format "rd_%08X_%08X" $addr [clock clicks]]
    create_hw_axi_txn $name $axi -type read -address [format 0x%08X $addr]
    run_hw_axi [get_hw_axi_txns $name]
    set data [get_property DATA [get_hw_axi_txns $name]]
    delete_hw_axi_txn [get_hw_axi_txns $name]
    return [parse_hex_data $data]
}

proc read_rgb_file {path expected_bytes} {
    set f [open $path rb]
    fconfigure $f -translation binary -encoding binary
    set blob [read $f]
    close $f
    set size [string length $blob]
    if {$size != $expected_bytes} {
        error "input raw size mismatch: got $size bytes, expected $expected_bytes bytes"
    }
    binary scan $blob c* signed_bytes
    set bytes {}
    foreach b $signed_bytes {
        lappend bytes [expr {$b & 0xff}]
    }
    return $bytes
}

proc write_rgb_file {path bytes} {
    set f [open $path wb]
    fconfigure $f -translation binary -encoding binary
    puts -nonewline $f [binary format c* $bytes]
    close $f
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

set input_pixels [expr {$img_w * $img_h}]
set output_pixels [expr {$img_w * $img_h * $scale * $scale}]
set output_pixels_to_read $output_pixels
if {$max_output_pixels > 0 && $max_output_pixels < $output_pixels} {
    set output_pixels_to_read $max_output_pixels
}
set input_bytes_expected [expr {$input_pixels * 3}]
set output_bytes_expected [expr {$output_pixels * 3}]
set output_bytes_to_write [expr {$output_pixels_to_read * 3}]

puts "Input : $input_file"
puts "Output: $output_file"
puts "Image : ${img_w}x${img_h}, scale x${scale}"
puts "Input bytes expected : $input_bytes_expected"
puts "Output bytes expected: $output_bytes_expected"
if {$output_pixels_to_read != $output_pixels} {
    puts "Output pixels to read: $output_pixels_to_read"
}

set input_bytes [read_rgb_file $input_file $input_bytes_expected]
set axi [open_jtag_axi $bitstream_file]
puts "Using hw_axi: $axi"

set output_bytes {}
set written_pixels 0
set last_output_report 0

proc drain_output_once {axi base_addr output_var written_var max_pixels} {
    upvar $output_var output_bytes
    upvar $written_var written_pixels
    global REG_STATUS REG_OUTPUT_PIXEL STATUS_OUT_VALID

    if {$written_pixels >= $max_pixels} {
        return 0
    }

    set status [axi_read32 $axi [expr {$base_addr + $REG_STATUS}]]
    if {($status & $STATUS_OUT_VALID) == 0} {
        return 0
    }

    set pix [axi_read32 $axi [expr {$base_addr + $REG_OUTPUT_PIXEL}]]
    lappend output_bytes [expr {($pix >> 16) & 0xff}]
    lappend output_bytes [expr {($pix >> 8) & 0xff}]
    lappend output_bytes [expr {$pix & 0xff}]
    incr written_pixels
    return 1
}

proc wait_input_ready {axi base_addr output_var written_var} {
    upvar $output_var output_bytes
    upvar $written_var written_pixels
    global REG_STATUS REG_COUNTER_IN REG_COUNTER_OUT REG_ERROR STATUS_IN_READY output_pixels_to_read input_ready_tries

    for {set i 0} {$i < $input_ready_tries} {incr i} {
        set status [axi_read32 $axi [expr {$base_addr + $REG_STATUS}]]
        if {($status & $STATUS_IN_READY) != 0} {
            return
        }
        drain_output_once $axi $base_addr output_bytes written_pixels $output_pixels_to_read
        if {(($i + 1) % 10000) == 0} {
            set counter_in_poll [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_IN}]]
            set counter_out_poll [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_OUT}]]
            set errors_poll [axi_read32 $axi [expr {$base_addr + $REG_ERROR}]]
            puts [format "Input wait: tries=%d reg_in=%d reg_out=%d received=%d/%d status=0x%08X errors=0x%08X" \
                [expr {$i + 1}] $counter_in_poll $counter_out_poll $written_pixels $output_pixels_to_read $status $errors_poll]
            flush stdout
        }
    }
    error "timeout waiting for input_ready"
}

# 清除输入丢弃和输出溢出标志。
axi_write32 $axi [expr {$base_addr + $REG_ERROR}] 0x00000003
axi_write32 $axi [expr {$base_addr + $REG_PERF_CTRL}] $perf_only

for {set i 0} {$i < $input_pixels} {incr i} {
    set idx [expr {$i * 3}]
    set r [lindex $input_bytes $idx]
    set g [lindex $input_bytes [expr {$idx + 1}]]
    set b [lindex $input_bytes [expr {$idx + 2}]]
    set x [expr {$i % $img_w}]

    set flags 0
    if {$i == 0} {
        set flags [expr {$flags | 1}]
    }
    if {$x == ($img_w - 1)} {
        set flags [expr {$flags | 2}]
    }

    wait_input_ready $axi $base_addr output_bytes written_pixels
    axi_write32 $axi [expr {$base_addr + $REG_INPUT_FLAGS}] $flags
    axi_write32 $axi [expr {$base_addr + $REG_INPUT_PIXEL}] [expr {($r << 16) | ($g << 8) | $b}]

    if {!$perf_only} {
        while {[drain_output_once $axi $base_addr output_bytes written_pixels $output_pixels_to_read] > 0} {
            if {$written_pixels >= ($last_output_report + 4096) || $written_pixels == $output_pixels_to_read} {
                set status_poll [axi_read32 $axi [expr {$base_addr + $REG_STATUS}]]
                set counter_out_poll [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_OUT}]]
                puts [format "Output drain progress: received=%d/%d reg_out=%d status=0x%08X" \
                    $written_pixels $output_pixels_to_read $counter_out_poll $status_poll]
                set last_output_report $written_pixels
                flush stdout
            }
        }
        if {$output_pixels_to_read != $output_pixels && $written_pixels >= $output_pixels_to_read} {
            write_rgb_file $output_file $output_bytes
            puts "Done."
            puts "Prefix output pixels: $written_pixels"
            puts "Wrote $output_file ($output_bytes_to_write bytes)"
            puts "JTAG_PREFIX_ONLY=1"
            close_hw_manager
            exit 0
        }
    }

    if {(($i + 1) % 64) == 0} {
        puts "Sent [expr {$i + 1}]/$input_pixels input pixels, received $written_pixels/$output_pixels output pixels"
        flush stdout
    }
}

set status_after_input [axi_read32 $axi [expr {$base_addr + $REG_STATUS}]]
set counter_in_after_input [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_IN}]]
set counter_out_after_input [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_OUT}]]
puts [format "Input loop complete: sent=%d/%d reg_in=%d reg_out=%d status=0x%08X" \
    $input_pixels $input_pixels $counter_in_after_input $counter_out_after_input $status_after_input]
flush stdout

if {$perf_only} {
    for {set tries 0} {$tries < $perf_wait_tries} {incr tries} {
        set frame_done_poll [axi_read32 $axi [expr {$base_addr + $REG_FRAME_DONE}]]
        if {($frame_done_poll & 0x1) != 0} {
            break
        }
        if {(($tries + 1) % 10000) == 0} {
            set status_poll [axi_read32 $axi [expr {$base_addr + $REG_STATUS}]]
            set counter_out_poll [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_OUT}]]
            puts [format "Perf wait: tries=%d output=%d/%d frame_done=0 status=0x%08X" \
                [expr {$tries + 1}] $counter_out_poll $output_pixels $status_poll]
            flush stdout
        }
        after 1
    }
} else {
    set last_output_report $written_pixels
    for {set tries 0} {$written_pixels < $output_pixels_to_read && $tries < $output_wait_tries} {incr tries} {
        if {[drain_output_once $axi $base_addr output_bytes written_pixels $output_pixels_to_read] == 0} {
            after 1
        }
        if {$written_pixels >= ($last_output_report + 4096) || $written_pixels == $output_pixels_to_read} {
            set status_poll [axi_read32 $axi [expr {$base_addr + $REG_STATUS}]]
            set counter_out_poll [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_OUT}]]
            puts [format "Output drain progress: received=%d/%d reg_out=%d status=0x%08X" \
                $written_pixels $output_pixels_to_read $counter_out_poll $status_poll]
            set last_output_report $written_pixels
            flush stdout
        } elseif {(($tries + 1) % 10000) == 0} {
            set status_poll [axi_read32 $axi [expr {$base_addr + $REG_STATUS}]]
            set counter_out_poll [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_OUT}]]
            puts [format "Output wait: tries=%d received=%d/%d reg_out=%d status=0x%08X" \
                [expr {$tries + 1}] $written_pixels $output_pixels_to_read $counter_out_poll $status_poll]
            flush stdout
        }
    }

    if {$written_pixels != $output_pixels_to_read} {
        error "output timeout: got $written_pixels pixels, expected $output_pixels_to_read"
    }

    write_rgb_file $output_file $output_bytes

    if {$output_pixels_to_read != $output_pixels} {
        puts "Done."
        puts "Prefix output pixels: $written_pixels"
        puts "Wrote $output_file ($output_bytes_to_write bytes)"
        puts "JTAG_PREFIX_ONLY=1"
        close_hw_manager
        exit 0
    }
}

set counter_in  [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_IN}]]
set counter_out [axi_read32 $axi [expr {$base_addr + $REG_COUNTER_OUT}]]
set errors      [axi_read32 $axi [expr {$base_addr + $REG_ERROR}]]
set frame_cycles [axi_read32 $axi [expr {$base_addr + $REG_FRAME_CYCLES}]]
set frame_done   [axi_read32 $axi [expr {$base_addr + $REG_FRAME_DONE}]]
set e2e_cycles   [axi_read32 $axi [expr {$base_addr + $REG_E2E_CYCLES}]]
set debug_writeback_hash  [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_HASH}]]
set debug_writeback_range [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_RANGE}]]
set debug_writeback_first [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_FIRST}]]
set debug_writeback_last  [axi_read32 $axi [expr {$base_addr + $REG_DEBUG_WRITEBACK_LAST}]]
if {($frame_done & 0x1) == 0 && $output_pixels_to_read == $output_pixels} {
    error "frame performance counter did not complete"
}

axi_write32 $axi [expr {$base_addr + $REG_PERF_CTRL}] 0x00000000

puts "Done."
puts "Input counter : $counter_in"
puts "Output counter: $counter_out"
puts "Frame cycles  : $frame_cycles"
puts "Frame done    : $frame_done"
puts "E2E cycles    : $e2e_cycles"
puts [format "Error flags   : 0x%08X" $errors]
puts [format "Debug wb hash : 0x%08X" $debug_writeback_hash]
puts [format "Debug wb range: 0x%08X" $debug_writeback_range]
puts [format "Debug wb first: 0x%08X" $debug_writeback_first]
puts [format "Debug wb last : 0x%08X" $debug_writeback_last]
if {$perf_only} {
    puts "Perf-only run did not write output RGB."
} else {
    puts "Wrote $output_file ($output_bytes_to_write bytes)"
}
puts "JTAG_FRAME_CYCLES=$frame_cycles"
puts "JTAG_FRAME_DONE=$frame_done"
puts "JTAG_E2E_CYCLES=$e2e_cycles"
puts "JTAG_PERF_ONLY=$perf_only"
