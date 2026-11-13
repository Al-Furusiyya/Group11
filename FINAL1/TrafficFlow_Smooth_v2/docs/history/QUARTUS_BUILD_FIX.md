Historical baseline document. Current behavior/build steps: ../../BEHAVIOR.md and ../../START_HERE.md.

# Quartus 25.1 Standard/Lite build correction

The confirmed failure is in `integration/cpu_jtag.sdc`, not a Python command.
The previous package used an option your edition rejects:

```tcl
set_max_delay -ignore_clock_latency 20.0 -from $request_src -to $request_dst
```

Both mailbox constraints now use Standard-compatible net-delay limits:

```tcl
set_net_delay -max 20.0 -from $request_src -to $request_dst
set_net_delay -max 20.0 -from $reply_src -to $reply_dst
```

Net-delay constraints also remain applicable when the vendor JTAG hub cuts
asynchronous setup/hold timing. Merely removing the unsupported option from
`set_max_delay` would leave that path constraint overridden by the clock group.
Review `report_net_delay` after fitting to verify the matched nets and slack.

The corrected SDC also:

- Reuses `altera_reserved_tck`, already created at 30 MHz by `sld_hub`. It does
  not add a duplicate 24 MHz clock. A fallback defines the same named 30 MHz
  clock only when the port exists but the vendor clock is absent.
- Defines `VGA_PIXEL_CLOCK` on `*|pixel_clock`, the divide-by-two register,
  rather than at `VGA_CLK`. This lets the clock propagate from the actual
  divider to the output. The SDC explicitly errors if the divider is missing.
- Preserves the 50 MHz input constraint and synchronizer exceptions.

## Apply to your extracted project

1. Download the updated `Lab4_Traffic_Final.zip`.
2. Copy its `Lab4_Traffic_Final/integration/cpu_jtag.sdc` over the same file in:

   `C:\altera_lite\quartusprojects\finalproject\Lab4_Traffic_Final\integration`

   That is the only synthesis input changed by this correction. Alternatively,
   extract the entire updated archive into a clean folder.
3. Open `Lab4_Python_JTAG.qpf` and run **Processing > Start Compilation**.
4. Confirm there is no `Read_sdc failed` message, review timing reports, and
   program the new SOF only after successful compilation.

No switch to a larger FPGA is justified by the supplied log. Error 11802 may
be a consequence of the SDC failure; it is not by itself proof of excessive
ALMs, registers, RAM or routing. If it remains after fixing the SDC, collect
the earliest remaining error plus these complete reports:

```text
output_files/Lab4_Python_JTAG.fit.rpt
output_files/Lab4_Python_JTAG.map.rpt
```

Warning 16406/16407 concerns KEY0's reset signal being routed through a global
buffer from a non-dedicated pin. It is not the fatal SDC error. Keep KEY0 on
the supplied board pin; do not move a physical push-button to a clock pin.

## Validation limits

Software regressions and four SDC Tcl/mock-API scenarios passed. Neither
Quartus nor an FPGA is available in the delivery environment. These tests do
not establish that this revision fits or meets timing on the board.

## Vendor references

- [Standard Edition: net-delay constraints](https://docs.altera.com/r/docs/683068/18.1/quartus-prime-standard-edition-user-guide-timing-analyzer/net-delay-set_net_delay)
- [set_net_delay command syntax](https://resources.altera.com/quartushelp/17.0/tafs/tafs/tcl_pkg_sdc_ext_ver_1.0_cmd_set_net_delay.htm)
- [Standard Edition Timing Analyzer guide, including exception precedence](https://www.intel.com/programmable/technical-pdfs/683068.pdf)
- [create_generated_clock examples using a divider register](https://resources.altera.com/quartushelp/26.1/tafs/tafs/tcl_pkg_sdc_ver_1.5_cmd_create_generated_clock.htm)
