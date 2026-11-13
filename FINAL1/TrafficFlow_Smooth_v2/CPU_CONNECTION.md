# CPU integration

The actual Lab4 CPU remains between host transport and display output:

`Python -> Quartus Tcl -> Virtual JTAG -> input mailbox -> CPU LOAD/STOR ->
VGA staging -> frame-boundary commit -> JTAG acknowledgement -> Python`

PS/2 follows `receiver/decoder -> traffic_io FIFO -> CPU -> JTAG FIFO -> Python`.
The renderer never reads the JTAG input mailbox directly.

## Word-addressed I/O

| CPU address | Access | Meaning |
|---|---|---|
| 0x3C0..0x3CF | read | 31-byte input bank, padded to sixteen words |
| 0x3D0..0x3DF | write | Display staging words |
| 0x3E0 | read | Received bank valid |
| 0x3E1 | read | Commit pending |
| 0x3E2 | write bit 0 | Commit bank; bank 4 waits for frame boundary |
| 0x3E3 | read | Keyboard FIFO not empty |
| 0x3E4 | read/pop | One PS/2 command |
| 0x3E5 | write | Forward command into JTAG reply FIFO |
| 0x3E6 | read | Committed frame counter |

`CPU/build_firmware.py` assembles the supplied relay into 1024 initialized words.
The reserved I/O area is 0x3C0..0x3FF. The prebuilt HEX and listing are included.
Original CPU arithmetic, branch and register modules and the relay firmware
are unchanged. The CPU copies five banks of sixteen words for each complete
20-car snapshot. Banks 0..3 acknowledge after staging; bank 4 atomically
commits all cars and UI at video blanking. The frame counter counts completed
snapshots, not individual banks.

`demo_VGA_Python.v` connects the clocks, physical KEY0 reset, CPU, peripherals,
keyboard, Virtual JTAG and renderer. `vga_scene.v` performs drawing only; all
traffic scheduling and geometry are in `Python/control.py`.

KEY0 restores the display to the same empty state as `DisplayState()` and arms
the transport reset handshake. See `PROTOCOL.md` for metadata and reply version.
LEDR[8] toggles on CPU bank acknowledgement; LEDR[9] latches peripheral/keyboard/packet
errors. Neither is a traffic phase timer.
