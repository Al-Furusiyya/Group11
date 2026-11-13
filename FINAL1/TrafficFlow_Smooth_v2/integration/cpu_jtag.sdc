create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# The divider is a register inside vga_timing. Defining the clock only at the
# VGA_CLK output leaves the internal divider unconstrained in TimeQuest.
set pixel_divider [get_registers -nowarn {*|pixel_clock}]
if {[get_collection_size $pixel_divider] != 1} {
    error "Expected one vga_timing pixel_clock register; check the top-level source files."
}
create_generated_clock -name VGA_PIXEL_CLOCK -source [get_ports {CLOCK_50}] -divide_by 2 $pixel_divider

# sld_hub normally supplies both the 30 MHz reserved TCK clock and its
# asynchronous clock group before this file is read. Reuse that clock.
# Do not add a second, slower JTAG_TCK clock on the same port.
if {[get_collection_size [get_clocks -nowarn {altera_reserved_tck}]] == 0} {
    set jtag_clock_port [get_ports -nowarn {altera_reserved_tck}]
    if {[get_collection_size $jtag_clock_port] == 0} {
        error "Virtual JTAG TCK not found; verify that sld_hub is synthesized."
    }
    create_clock -name altera_reserved_tck -period 33.333 $jtag_clock_port
    set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}]
}
derive_clock_uncertainty
set_false_path -from [get_ports {PS2_CLK PS2_DAT}]
# Explicit first-stage exceptions; the vendor TCK group also cuts cross-domain
# setup/hold analysis. Same-domain synchronizer stages remain timed.
foreach first_stage {request_meta done_meta valid_meta overflow_meta reset_meta} {
    set_false_path -to [get_registers -nowarn *|$first_stage]
}
# Mailbox buses are HELD while their toggles cross two synchronization FFs.
# Bound their net delays independently of the vendor's asynchronous clock group.
# Standard/Lite does not support set_max_delay -ignore_clock_latency, and an
# ordinary set_max_delay would be overridden by that clock-group exception.
# Review report_net_delay after fitting; this does not replace CDC validation.
set request_src [get_registers -nowarn {*|request_payload*}]
set request_dst [get_registers -nowarn {*|packet*}]
set reply_src [get_registers -nowarn {*|response_payload*}]
set reply_dst [get_registers -nowarn {*|status_shift*}]
set_net_delay -max 20.0 -from $request_src -to $request_dst
set_net_delay -max 20.0 -from $reply_src -to $reply_dst
