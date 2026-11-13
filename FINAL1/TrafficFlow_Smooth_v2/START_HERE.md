# Build, program and run

## 1. Extract into a new folder

Extract `TrafficFlow_Smooth_v2.zip` beneath:

```text
C:\altera_lite\quartusprojects\finalproject
```

The ZIP contains `TrafficFlow_Smooth_v2`, so the project should be at:

```text
C:\altera_lite\quartusprojects\finalproject\TrafficFlow_Smooth_v2\Lab4_Python_JTAG.qpf
```

Using the new folder avoids accidentally programming an older build. Do not
combine old source files or an old SOF with this version.

## 2. Compile in Quartus

1. Open `Lab4_Python_JTAG.qpf` in this new folder.
2. Device: **5CSEMA5F31C6**. Top-level entity: **demo_VGA_Python**.
3. Run **Processing > Start Compilation** (full compilation).
4. Review compilation and timing reports. This package has not been fitted or
   timing-validated with Quartus in the delivery environment.
5. Keep `CPU/traffic_firmware.hex` at its supplied relative path. It is already
   assembled; no assembler is needed to compile the project.

The QSF includes the source list, DE1-SoC pins and clock/CDC constraints.
Do not add `sim/sld_virtual_jtag_model.v` to the Quartus project; it is test-only.

## 3. Program

1. Open Quartus Programmer and select the DE-SoC USB-Blaster cable.
2. Add the **new** `output_files/Lab4_Python_JTAG.sof`.
3. Program the **FPGA**, not the SOCVHPS entry. Wait for successful completion.
4. Close Programmer and any active Signal Tap session.
5. Press and release the physical **KEY0** push-button.

The VGA display should show the GUI, red main lights, inactive left arrows,
zero counters and **no cars**. Python traffic does not run until you press 1.

## 4. Check the connection

In PowerShell:

```powershell
cd "C:\altera_lite\quartusprojects\finalproject\TrafficFlow_Smooth_v2"
python .\Python\app.py devices
python .\Python\app.py check --cable 0 --device 1
```

The indices above match your observed chain: cable 0, SOCVHPS device 0, FPGA
device 1. Use the output of `devices` if your chain changes.

The check should print:

```text
PASS: Python -> USB-Blaster/JTAG -> Lab4 CPU -> VGA frame commit -> acknowledgement.
```

The application sets `TBB_MALLOC_DISABLE_REPLACEMENT=1` for its Quartus child
process. The Tcl server uses explicit, unbuffered channel output. These fixes
are already included; no manual edits or system-wide environment changes are
needed for this launch path.

## 5. Run

```powershell
python .\Python\app.py run --cable 0 --device 1
```

Or double-click `START_CAR.bat` for automatic single-cable/FPGA selection.
Press **1 on the PS/2 keyboard attached to the FPGA**, or type `1` plus Enter in PowerShell, to start the simulation.
PS/2 keys take effect without Enter. At the PowerShell console, type a command
and press Enter; multiple tokens such as `n l` may be entered together.

| Action | Physical key / console token |
|---|---|
| Run / resume | `1` |
| Pause | `2` |
| Reset to empty GUI | `3` |
| Northbound / southbound / eastbound / westbound | `N` / `S` / `E` / `W` |
| Left / straight / right | `L` / **`T`** / `R` |
| Pedestrian request | `P`, then a direction |
| Emergency hold | `A` / `F` / `C` / `B` |
| Release emergency | Same emergency key again, or `Esc` |
| Exit host application | Console `quit`, or Ctrl+C |

**S on screen means straight; T on the keyboard activates it.** Physical S
always means southbound. The small `S [T]` legend reinforces that distinction.

Pressing KEY0 during a live session empties the hardware GUI immediately. The
host detects the reset, clears its traffic state, and waits for a fresh 1.
Wait for the host reset message before pressing 1 again.

`--auto-run` remains available for an explicitly requested immediate start.
`--demo` is accepted for compatibility but is no longer required for motion.
The default launcher intentionally does not use `--auto-run`.

## 6. Board acceptance sequence

1. Reset: no cars. Press 1: five-car EB/WB queues enter, alternating straight/right.
2. Enter `n l` together in the console (or press N then L promptly on PS/2).
   NB enters the middle with wheels straight, yields there, then turns after
   the last oncoming car has safe rear clearance.
   Its amber arrow indicates yielding; a protected green is a fallback, not
   required for every left. Straight followers can pass in the outer lane.
3. Repeat N T, N R, and each other direction to confirm route orientation.
4. Enter `p w`: conflicting cars clear, then WB walks the northwestern zebra
   while compatible EB/WB traffic continues. Turns across that zebra wait.
5. Press 2 mid-stage: positions and counters freeze. Press 1: they resume.
6. Press A: all-red hold. Press A again: clearance, then the interrupted stage.
7. Press KEY0 during motion: the GUI stays empty until a new Run command.

## Troubleshooting

- **Error 332000 / `-ignore_clock_latency` / `Read_sdc failed`:** replace
  `integration/cpu_jtag.sdc` with this updated archive's copy and full-compile.
  See `docs/history/QUARTUS_BUILD_FIX.md`; Error 11802 alone does not prove resource overflow.
- **Old/wrong image or reply version:** full-compile and program this folder's
  SOF. Python packet v4 requires reply version 3 from the new RTL.
- **Bad scan / busy:** press KEY0 once, then check. This source accepts extra
  physical bypass clocks. If rejection persists, collect the Quartus build,
  exact console output, and actual scan-counter/IR/state traces in Signal Tap.
- **No CPU/frame acknowledgement:** verify the new SOF, firmware inclusion,
  CLOCK_50 pin, and VGA frame timing. LEDR[8] toggles on CPU bank acknowledgements.
- **Another application holds JTAG:** close its active programming/debug session.
- **Lost connection:** stop the host and press KEY0; the board otherwise retains
  its last committed frame. This source has no disconnect watchdog.

A Quartus compilation, timing review and real-board run are still required.
