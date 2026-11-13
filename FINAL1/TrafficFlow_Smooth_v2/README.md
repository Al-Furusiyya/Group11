# TrafficFlow Smooth v2

Start with [START_HERE.md](START_HERE.md). Rebuild and program the new SOF using
**Lab4_Python_JTAG.qpf**, top **demo_VGA_Python**, device **5CSEMA5F31C6**.

- Stable sprite identities and cadence-adaptive fractional interpolation.
- Gentler queue braking, following and curved-turn speed.
- Left turns move straight to the center, yield there, then turn with more
  clearance behind the last oncoming car.
- Crisp, aligned left-arrow housings with clearer red/amber/green colors.
- Pedestrians reserve their whole crossing while compatible traffic continues.

Your working USB-Blaster/JTAG host, actual Lab4 CPU relay, firmware, protocol,
pins and clock/CDC constraints are retained. No UART adapter or new dependency.
Only three runtime files change from v1; see [SMOOTH_UPDATE.md](SMOOTH_UPDATE.md).

[BEHAVIOR.md](BEHAVIOR.md) explains the updated rules and timing.
[VERIFICATION.md](VERIFICATION.md) reports executed tests and remaining board
checks. `docs/rtl_previews/` contains actual HDL pixel captures;
`docs/previews/` contains separate software references. The ZIP omits old
Quartus caches and compiled output. A fresh Quartus fit/program is required.
