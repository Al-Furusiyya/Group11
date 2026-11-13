"""Execute the SDC's Tcl control flow with a strict, small mocked API.

This checks syntax/options and clock-selection branches, NOT Quartus name
resolution, fitting, physical timing, or completeness of the constraints.
"""
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
TCLSH = shutil.which('tclsh')

HARNESS = r'''
set mode $::env(SDC_TEST_MODE)
set clocks {CLOCK_50}
if {$mode ne "fallback" && $mode ne "missing_tck"} {
    lappend clocks altera_reserved_tck
}
proc get_collection_size {collection} {llength $collection}
proc get_ports {args} {
    set pattern [lindex $args end]
    if {$::mode eq "missing_tck" && $pattern eq "altera_reserved_tck"} {return {}}
    return $pattern
}
proc get_clocks {args} {
    # Standard-compatible name query, no Pro-only -of_objects dependency.
    if {[llength $args] > 2} {error "unsupported get_clocks options"}
    set pattern [lindex $args end]
    return [lsearch -all -inline -glob $::clocks $pattern]
}
proc get_registers {args} {
    set pattern [lindex $args end]
    if {$pattern eq "*|pixel_clock"} {
        if {$::mode eq "missing_divider"} {return {}}
        return {vga_timing:timing|pixel_clock}
    }
    return $pattern
}
proc validate {command allowed args} {
    foreach arg $args {
        if {[string match -* $arg] && [lsearch -exact $allowed $arg] < 0} {
            error "unsupported option $arg for $command"
        }
    }
    puts [list $command {*}$args]
}
proc create_clock {args} {
    validate create_clock {-name -period} {*}$args
    set name [lindex $args [expr {[lsearch -exact $args -name] + 1}]]
    if {$name ne "CLOCK_50" && [lsearch -exact $::clocks $name] >= 0} {
        error "duplicate clock $name"
    }
    lappend ::clocks $name
}
proc create_generated_clock {args} {
    validate create_generated_clock {-name -source -divide_by} {*}$args
    if {[lindex $args end] ne "vga_timing:timing|pixel_clock"} {
        error "generated clock must target the divider register"
    }
}
proc set_clock_groups {args} {validate set_clock_groups {-asynchronous -group} {*}$args}
proc derive_clock_uncertainty {} {}
proc set_false_path {args} {validate set_false_path {-from -to -hold -setup} {*}$args}
proc set_max_delay {args} {validate set_max_delay {-from -to} {*}$args}
proc set_net_delay {args} {validate set_net_delay {-max -from -to} {*}$args}
if {[catch {source integration/cpu_jtag.sdc} message]} {
    puts stderr $message
    exit 1
}
'''


@unittest.skipUnless(TCLSH, 'tclsh unavailable; SDC mock execution skipped')
class SdcTests(unittest.TestCase):
    def run_sdc(self, mode):
        import os
        return subprocess.run([TCLSH], input=HARNESS, text=True,
                              capture_output=True, cwd=ROOT, timeout=10,
                              env=dict(os.environ, SDC_TEST_MODE=mode))

    def check_delay_constraints(self, output):
        lines = output.splitlines()
        delays = [line for line in lines if line.startswith('set_net_delay ')]
        self.assertEqual(len(delays), 2)
        self.assertTrue(all('-max 20.0' in line for line in delays))
        self.assertIn('request_payload', delays[0])
        self.assertIn('packet', delays[0])
        self.assertIn('response_payload', delays[1])
        self.assertIn('status_shift', delays[1])
        self.assertFalse(any(line.startswith('set_max_delay ') for line in lines))

    def test_embedded_jtag_clock_is_reused(self):
        result = self.run_sdc('embedded')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(line.startswith('create_clock ')
                             for line in result.stdout.splitlines()), 1)
        self.assertIn('create_generated_clock -name VGA_PIXEL_CLOCK', result.stdout)
        self.check_delay_constraints(result.stdout)

    def test_fallback_clock_matches_vendor_30mhz(self):
        result = self.run_sdc('fallback')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('create_clock -name altera_reserved_tck -period 33.333', result.stdout)
        self.assertIn('set_clock_groups -asynchronous -group altera_reserved_tck', result.stdout)
        self.check_delay_constraints(result.stdout)

    def test_missing_tck_is_an_explicit_error(self):
        result = self.run_sdc('missing_tck')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Virtual JTAG TCK not found', result.stderr)

    def test_missing_divider_is_an_explicit_error(self):
        result = self.run_sdc('missing_divider')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Expected one vga_timing pixel_clock register', result.stderr)


if __name__ == '__main__':
    unittest.main()
