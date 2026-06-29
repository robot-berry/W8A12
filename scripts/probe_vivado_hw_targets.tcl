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
catch {puts "VIVADO_HW_TARGET_LABTOOLS_ENABLE_CS_SERVER=[get_param labtools.enable_cs_server]"}

open_hw_manager
connect_hw_server

set targets [get_hw_targets -quiet *]
puts "VIVADO_HW_TARGET_COUNT=[llength $targets]"
foreach target_name $targets {
    puts "VIVADO_HW_TARGET_CANDIDATE=$target_name"
}
if {[llength $targets] == 0} {
    error "No Vivado hardware target found. Check board power, USB-JTAG cable, driver, and JTAG mode."
}

open_hw_target [lindex $targets 0]
set target [current_hw_target -quiet]
puts "VIVADO_HW_TARGET=$target"

set devices [get_hw_devices -quiet]
puts "VIVADO_HW_DEVICE_COUNT=[llength $devices]"
foreach dev $devices {
    puts "VIVADO_HW_DEVICE=$dev"
}
if {[llength $devices] == 0} {
    error "No Vivado hardware device found after opening target."
}

puts "VIVADO_HW_TARGET_PROBE_PASS=1"
