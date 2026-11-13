# Test-only Quartus API stand-in. The production jtag_server.tcl is sourced intact.
set server [lindex $argv 0];set argv [lrange $argv 1 end]
set physical_reset_pending [expr {[lindex $argv 0] eq "reset_test"}]
set interrupt_idle_once [expr {[lindex $argv 0] eq "reset_during_idle"}]
set expected_bank 0
set active_ir 0;set packet_seq 0;set polls 0;set locked 0
proc get_hardware_names {} {return [list {DE-SoC [USB-0]}]}
proc get_device_names {args} {return [list {@1: SOCVHPS (0x4BA00477)} {@2: 5CSEMA5 (0x02D120DD)}]}
proc open_device {args} {
 if {[string first 5CSEMA5 $args]<0} {error "Selected HPS instead of FPGA"}
}
proc close_device {} {}
proc device_lock {args} {set ::locked 1}
proc device_unlock {} {set ::locked 0}
proc device_virtual_ir_shift {args} {
 if {!$::locked} {error "IR scan without lock"}
 set index [lsearch -exact $args -ir_value];set ::active_ir [lindex $args [expr {$index+1}]]
}
proc device_virtual_dr_shift {args} {
 if {!$::locked} {error "DR scan without lock"}
 set i [lsearch -exact $args -length];set length [lindex $args [expr {$i+1}]]
 if {$::active_ir==1} {
  if {$length!=288} {error "wrong write width"}
  set i [lsearch -exact $args -dr_value];set hex [lindex $args [expr {$i+1}]]
  set bits [expr "0x$hex"]
  if {($bits&65535)!=0x5aa5 || (($bits>>16)&255)!=4} {error "Wrong packet byte order/header"}
  if {$::interrupt_idle_once} {
   set ::interrupt_idle_once 0;set ::physical_reset_pending 1;return ""
  }
  if {(($bits>>32)&255)==0 || (($bits>>32)&255)==3} {set ::physical_reset_pending 0}
  set bank [expr {($bits>>66)&7}]
  if {$bank>4 || ($bank!=0 && $bank!=$::expected_bank)} {error "Wrong bank order"}
  set ::expected_bank [expr {$bank==4 ? 0 : $bank+1}]
  set ::packet_seq [expr {($bits>>24)&255}];set ::polls 0
  return ""
 }
 if {$::active_ir!=2 || $length!=192} {error "wrong status instruction/width"}
 if {$::physical_reset_pending} {return "100000000000000000000000000000000000000000000000"}
 incr ::polls
 if {$::polls==1} {return [format %048x [expr {1<<184}]]}
 set bits [expr {0x474a|($::packet_seq<<16)|(2<<32)|(5<<40)|(9<<48)}]
 set crc 0
 for {set i 0} {$i<21} {incr i} {
  set crc [expr {$crc^(($bits>>($i*8))&255)}]
  for {set k 0} {$k<8} {incr k} {
   if {$crc&128} {set crc [expr {(($crc<<1)^7)&255}]} else {set crc [expr {($crc<<1)&255}]}
  }
 }
 set bits [expr {$bits|($crc<<168)|(3<<176)|(2<<184)}]
 # format %x on some Tcl builds is limited to machine words; manual bignum hex.
 set hex ""
 for {set i 0} {$i<48} {incr i} {
  set hex "[string index 0123456789abcdef [expr {$bits&15}]]$hex";set bits [expr {$bits>>4}]
 }
 return $hex
}
source $server
