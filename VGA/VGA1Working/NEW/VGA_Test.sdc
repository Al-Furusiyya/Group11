# Board clock: 50 MHz, or 20 ns per cycle.
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# VGA output clock: board clock divided by two.
create_generated_clock -name VGA_PIXEL_CLOCK -source [get_ports {CLOCK_50}] -divide_by 2 [get_ports {VGA_CLK}]

# Let Quartus calculate clock uncertainty.
derive_clock_uncertainty