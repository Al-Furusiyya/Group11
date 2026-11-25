# Our small Lab4 assembler. Quartus can run this, so rebuilding the firmware
# does not need Python or another compiler. The finished HEX is already included.
set root [file dirname [file normalize [info script]]]
proc read_source {path} {
    set input [open $path r];set lines [split [read $input] \n];close $input
    set expanded {}
    foreach line $lines {
        if {[regexp {^\s*\.include\s+(\S+)} $line -> name]} {
            set expanded [concat $expanded [read_source [file join [file dirname $path] $name]]]
        } else {lappend expanded $line}
    }
    return $expanded
}
set source [read_source [file join $root traffic.asm]]
array set symbol {}
set rows {}
proc value {s} {
    global symbol
    if {[string is integer -strict $s]} {return [expr {$s+0}]}
    if {[info exists symbol($s)]} {return $symbol($s)}
    foreach name [lsort -decreasing -command {apply {{a b} {expr {[string length $a]-[string length $b]}}}} [array names symbol]] {
        regsub -all "\\m${name}\\M" $s $symbol($name) s
    }
    return [expr $s]
}
proc regno {r} {
    if {![regexp -nocase {^R([0-9]+)$} $r -> n] || $n>15} {error "Bad register $r"}
    return $n
}
proc li {r n} {return [list [expr {0xF000|($r<<8)|(($n>>8)&255)}] [expr {0x2000|($r<<8)|($n&255)}]]}
array set condition {JE 0 JNE 1 JLT 6 JGE 7 JLE 13 JGT 12 JLTU 4 JGEU 5 JLEU 11 JGTU 10}
array set inverse {0 1 1 0 6 7 7 6 13 12 12 13 4 5 5 4 11 10 10 11}
proc assemble {tokens pc pass} {
    global condition inverse symbol
    set op [string toupper [lindex $tokens 0]]
    set a [lindex $tokens 1];set b [lindex $tokens 2]
    if {$pass==1} {
        switch -- $op {
            LI {return {0 0}} GET - SET {return {0 0 0}}
            SETI {return {0 0 0 0 0}} J {return {0 0 0}}
            CGET - CSET - PGET {return {0 0 0}}
            CALL {return {0 0 0 0 0 0 0}} RET {return {0 0 0}}
            JE - JNE - JLT - JGE - JLE - JGT - JLTU - JGEU - JLEU - JGTU {return {0 0 0 0}}
            CMP {if {![regexp -nocase {^R[0-9]+$} $b]} {return {0 0 0}}}
        }
        return {0}
    }
    if {[info exists condition($op)]} {
        set c $condition($op)
        return [concat [list [expr {0xC000|($inverse($c)<<8)|3}]] [li 14 [value $a]] {0x4ECE}]
    }
    switch -- $op {
        LI {return [li [regno $a] [value $b]]}
        GET {return [concat [li 12 [value $b]] [list [expr {0x400C|([regno $a]<<8)}]]]}
        SET {return [concat [li 12 [value $b]] [list [expr {0x404C|([regno $a]<<8)}]]]}
        SETI {return [concat [li 14 [value $b]] [li 12 [value $a]] {0x4E4C}]}
        CGET - CSET - PGET {
            set base [expr {$op=="PGET"?8:10}]
            return [list [expr {0x0CD0|$base}] [expr {0x6C00|([value $b]&255)}] [expr {($op=="CSET"?0x404C:0x400C)|([regno $a]<<8)}]]
        }
        J {return [concat [li 14 [value $a]] {0x4ECE}]}
        CALL {return [concat [li 15 [expr {$pc+7}]] {0x4F4D 0x6D01} [li 14 [value $a]] {0x4ECE}]}
        RET {return {0x6DFF 0x4F0D 0x4ECF}}
        LOAD {return [list [expr {0x4000|([regno $a]<<8)|[regno $b]}]]}
        STOR {return [list [expr {0x4040|([regno $a]<<8)|[regno $b]}]]}
        MOV - ADD - ADDU - SUB - MUL - AND - OR - XOR - CMP {
            array set sub {MOV 13 ADD 5 ADDU 6 SUB 9 MUL 14 AND 1 OR 2 XOR 3 CMP 11}
            if {$op=="CMP" && ![regexp -nocase {^R[0-9]+$} $b]} {
                return [concat [li 12 [value $b]] [list [expr {([regno $a]<<8)|0xBC}]]]
            }
            return [list [expr {([regno $a]<<8)|($sub($op)<<4)|[regno $b]}]]
        }
        ADDI - SUBI - ANDI - ORI - XORI {
            array set prefix {ADDI 6 SUBI 9 ANDI 1 ORI 2 XORI 3}
            set n [value $b]
            if {$op in {ADDI SUBI} && ($n < -128 || $n > 127)} {error "Immediate out of range: $n"}
            return [list [expr {($prefix($op)<<12)|([regno $a]<<8)|($n&255)}]]
        }
        LSHI - ASHI {
            set n [value $b]
            if {$n < -16 || $n > 15} {error "Shift outside signed five-bit range"}
            return [list [expr {0x8000|([regno $a]<<8)|($op=="ASHI"?32:0)|($n&31)}]]
        }
        default {error "Unknown instruction $op"}
    }
}
# Pass one finds the labels. Pass two emits actual Lab4 instruction words.
for {set pass 1} {$pass<=2} {incr pass} {
    set pc 0;set output {};set listing {};set line_number 0
    foreach original $source {
        incr line_number
        set line [string trim [lindex [split $original {;}] 0]]
        if {$line==""} {continue}
        if {[regexp {^\.equ\s+(\w+)\s+(.+)$} $line -> name expression]} {
            set symbol($name) [value $expression];continue
        }
        if {[regexp {^(\w+):$} $line -> name]} {set symbol($name) $pc;continue}
        set tokens [regexp -all -inline {[^,\s]+} $line]
        if {[catch {set words [assemble $tokens $pc $pass]} why]} {error "traffic.asm:$line_number: $why"}
        if {$pass==2} {
            set encoded {};foreach word $words {lappend encoded [format %04X $word]}
            lappend listing [format {%04X: %-35s %-34s ; source line %d} $pc [join $encoded { }] $line $line_number]
        }
        foreach word $words {lappend output [expr {$word&65535}];incr pc}
    }
}
if {$pc>=0x3000} {error "Program overlaps the constant route table"}
set instruction_words $pc
while {[llength $output]<32768} {lappend output 0}
set f [open [file join $root routes.hex] r];set route_words [split [string trim [read $f]] \n];close $f
if {[llength $route_words]!=9216} {error "Expected twelve routes, 256 points, three words per point"}
set at 0x3000
foreach word $route_words {lset output $at [scan $word %x];incr at}
set at 0x5500
foreach word {4442 3162 6234 8934 9702 13286 4352 3072 4352 4352 9216 12800 4352 3072 4352 6453 7221 10805} {lset output $at $word;incr at}
set at 0x5520
foreach word {8 2 4 1} {lset output $at $word;incr at}
set at 0x5530
foreach word {5 12 6 10 12 9 9 3 5 6 3 10} {lset output $at $word;incr at}
set f [open [file join $root traffic.hex] w]
foreach word $output {puts $f [format %04X $word]};close $f
set f [open [file join $root traffic.lst] w];puts $f [join $listing \n];close $f
set f [open [file join $root symbols.txt] w]
foreach name [lsort [array names symbol]] {puts $f [format {%s %04X} $name $symbol($name)]};close $f
puts "Built $instruction_words Lab4 instruction words; 32768-word initialized RAM image."
