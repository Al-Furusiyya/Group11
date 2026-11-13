# Run by Python using quartus_stp -t. Uses the existing USB-Blaster, not a COM port.
# Keep stdout machine-readable tags separate from Quartus diagnostic messages.
chan configure stdout -buffering none
proc emit {tag value} {chan puts stdout "$tag $value";chan flush stdout}
proc fail {message} {
    if {$message eq "BOARD_RESET"} {emit JTAG_RESET "KEY0 reset"} else {
        emit JTAG_ERROR [string map {\n { } \r { }} $message]
    }
}
proc select_one {items selector label} {
    if {[llength $items]==0} {error "No $label detected."}
    if {$selector eq ""} {
        if {[llength $items]!=1} {error "Multiple $label choices. Run devices and specify --$label."}
        return [lindex $items 0]
    }
    if {[string is integer -strict $selector]} {
        if {$selector<0 || $selector>=[llength $items]} {error "Invalid $label index $selector."}
        return [lindex $items $selector]
    }
    set matches {}
    foreach item $items {if {[string first $selector $item]>=0} {lappend matches $item}}
    if {[llength $matches]!=1} {error "The $label selector must identify exactly one item."}
    return [lindex $matches 0]
}
proc read_status {} {
    set raw [string trim [device_virtual_dr_shift -instance_index 0 -length 192 -value_in_hex]]
    if {![regexp {^[0-9a-fA-F]{1,48}$} $raw]} {error "Invalid Virtual JTAG response: $raw"}
    return "[string repeat 0 [expr {48-[string length $raw]}]]$raw"
}
proc transfer {sequence packet_hex} {
    set packet_bits [expr "0x$packet_hex"]
    set control [expr {($packet_bits>>32)&255}]
    set idle [expr {$control==0 || $control==3}]
    # Check reset even if KEY0 interrupted a scan before a valid reply existed.
    device_virtual_ir_shift -instance_index 0 -ir_value 2 -no_captured_ir_value
    set deadline [expr {[clock milliseconds]+4000}]
    while {1} {
        set raw [read_status]
        set bits [expr "0x$raw"]
        set flags [expr {($bits>>184)&255}]
        if {($flags&16)!=0 && !$idle} {error "BOARD_RESET"}
        if {($flags&8)!=0} {error "FPGA rejected a scan length or a write while busy. Press KEY0 and restart."}
        if {($flags&1)==0} {break}
        if {[clock milliseconds]>=$deadline} {error "Previous JTAG request is still busy. Press KEY0."}
        after 2
    }
    device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value
    device_virtual_dr_shift -instance_index 0 -length 288 -dr_value $packet_hex -value_in_hex -no_captured_dr_value
    device_virtual_ir_shift -instance_index 0 -ir_value 2 -no_captured_ir_value
    set deadline [expr {[clock milliseconds]+4000}]
    while {[clock milliseconds]<$deadline} {
        set raw [read_status]
        set bits [expr "0x$raw"]
        set flags [expr {($bits>>184)&255}]
        if {($flags&16)!=0 && !$idle} {error "BOARD_RESET"}
        set returned_sequence [expr {($bits>>16)&255}]
        if {($flags&8)!=0} {error "FPGA rejected a scan length or a write while busy. Press KEY0 and restart."}
        if {($flags&1)==0 && ($flags&2)!=0 && $returned_sequence==$sequence} {return $raw}
        after 2
    }
    if {($flags&16)!=0} {error "BOARD_RESET"}
    error "No CPU/frame acknowledgement. Check new .sof, KEY0 reset, CPU firmware and VGA clock."
}
proc main {} {
    global argv
    set mode [lindex $argv 0]
    set cable_selector [lindex $argv 1]
    set device_selector [lindex $argv 2]
    set cables [get_hardware_names]
    if {$mode eq "devices"} {
        set ci 0
        foreach cable $cables {
            emit JTAG_CABLE "$ci $cable"
            set di 0
            foreach dev [get_device_names -hardware_name $cable] {
                emit JTAG_DEVICE "$ci $di $dev";incr di
            }
            incr ci
        }
        emit JTAG_END devices
        return
    }
    set cable [select_one $cables $cable_selector cable]
    set all_devices [get_device_names -hardware_name $cable]
    if {$device_selector eq ""} {
        set candidates {}
        foreach dev $all_devices {if {[string match -nocase "*5CSE*" $dev]} {lappend candidates $dev}}
        set device [select_one $candidates "" device]
    } else {set device [select_one $all_devices $device_selector device]}
    open_device -hardware_name $cable -device_name $device
    emit JTAG_READY "$cable | $device"
    fconfigure stdin -blocking 1 -buffering line
    while {[gets stdin line]>=0} {
        if {$line eq "QUIT"} {break}
        set parts [split $line]
        if {[llength $parts]!=3 || [lindex $parts 0] ne "FRAME"} {fail "Unknown request";continue}
        set sequence [lindex $parts 1];set packet_hex [lindex $parts 2]
        if {![string is integer -strict $sequence] || $sequence<0 || $sequence>255 ||
            ![regexp {^[0-9a-fA-F]{72}$} $packet_hex]} {fail "Invalid FRAME fields";continue}
        set locked 0
        set failed [catch {
            device_lock -timeout 2000;set locked 1
            set response [transfer $sequence $packet_hex]
        } message]
        if {$locked} {catch {device_unlock}}
        if {$failed} {fail $message} else {emit JTAG_REPLY $response}
    }
    close_device
}
if {[info exists ::quartus(args)]} {set argv $::quartus(args)}
if {[catch {main} message]} {fail $message;catch {close_device};exit 1}
