if {[llength $argv] < 1} {
    error "Usage: run_xsct_psu_init_only.tcl <psu_init.tcl>"
}

set psu_init_tcl [file normalize [lindex $argv 0]]
if {![file exists $psu_init_tcl]} {
    error "psu_init.tcl not found: $psu_init_tcl"
}

proc try_target {filter label} {
    if {[catch {targets -set -filter $filter} err]} {
        puts "PSU_INIT_ONLY_TARGET_SELECT_FAIL_${label}=$err"
        return 0
    }
    puts "PSU_INIT_ONLY_TARGET_SELECT_PASS_${label}=1"
    return 1
}

connect
after 1000
puts "PSU_INIT_ONLY_TARGETS_BEGIN"
targets
puts "PSU_INIT_ONLY_TARGETS_END"

set selected 0
foreach item {
    {{name =~ "PSU"} PSU}
    {{name =~ "PS TAP"} PS_TAP}
    {{name =~ "PMU"} PMU}
    {{name =~ "DAP"} DAP}
} {
    set filter [lindex $item 0]
    set label [lindex $item 1]
    if {[try_target $filter $label]} {
        set selected 1
        break
    }
}

if {!$selected} {
    error "Could not select a ZynqMP PS/PMU/DAP target for psu_init"
}

source $psu_init_tcl
puts "PSU_INIT_ONLY_SOURCE=$psu_init_tcl"

if {[catch {
    psu_init
    psu_ps_pl_isolation_removal
    psu_ps_pl_reset_config
} err]} {
    puts "PSU_INIT_ONLY_FAIL=$err"
    error $err
}

puts "PSU_INIT_ONLY_PASS=1"
