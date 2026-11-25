# Our CPU and peripherals use CLOCK_50. The VGA output clock is divided by two.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
set pixel_divider [get_registers -nowarn {*|pixel_clock}]
if {[get_collection_size $pixel_divider] != 1} {
 error "Expected one vga_timing pixel_clock register."
}
create_generated_clock -name VGA_PIXEL_CLOCK -source [get_ports {CLOCK_50}] -divide_by 2 $pixel_divider
derive_clock_uncertainty
set_false_path -from [get_ports {PS2_CLK PS2_DAT}]
set_false_path -to [get_registers -nowarn {*|auto_meta}]
