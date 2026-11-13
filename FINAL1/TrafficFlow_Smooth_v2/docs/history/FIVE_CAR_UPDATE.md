Historical baseline document. Current behavior/build steps: ../../BEHAVIOR.md and ../../START_HERE.md.

# Five cars per traffic direction

This update adds five independent cars per active direction (twenty available
sprites). They queue at red lights, keep 16 road units apart, and enter from
the road edges. The default still runs EB/WB only, alternating straight/right;
NB/SB becomes active when selected. The first eligible selected-direction car
takes L/T/R. The four followers use the existing user-service default: straight.
Previously locked cars keep their routes. User service stays green in five-second
intervals until its queued batch clears, including after the selected left turn.

## Replace only these seven runtime files

Copy these paths from the updated archive over the matching project paths:

1. `Python/control.py` — five-car queues, spacing and first-car-only choice.
2. `Python/protocol.py` — twenty car records in five fixed-size packets.
3. `Python/jtag_link.py` — transmit all banks and collect keyboard replies.
4. `JTAG/jtag_display_link.v` — new protocol and ordered-bank validation.
5. `CPU/traffic_io.v` — stage all cars and commit them together at blanking.
6. `demo_VGA_Python.v` — connect all twenty sprite slots.
7. `vga_scene.v` — draw all slots using a shared sprite decoder.

CPU firmware/ISA, QSF project and pin assignments, SDC timing constraints,
PS/2 mapping, GUI artwork, and the Tcl JTAG server are unchanged. The full ZIP
also updates the directly affected tests, fixtures, previews and documentation.

## Rebuild before running

The old SOF supports only four cars. This update uses packet v4 / reply v3, so
both the seven files above and a newly compiled SOF are required.

1. Stop the Python app with Ctrl+C and close active Signal Tap sessions.
2. Replace the seven files, open `Lab4_Python_JTAG.qpf`, and full-compile.
3. Program the newly generated `output_files/Lab4_Python_JTAG.sof` on the FPGA
   row. If Error 209042 returns, stop the remaining `quartus_stp` process:

   ```powershell
   Get-Process -Name quartus_stp -ErrorAction SilentlyContinue | Stop-Process -Force
   ```

4. After programming succeeds, close Programmer, press KEY0, and run:

   ```powershell
   cd "C:\altera_lite\quartusprojects\finalproject\Lab4_Traffic_Final"
   python .\Python\app.py check --cable 0 --device 1
   python .\Python\app.py run --cable 0 --device 1
   ```

5. Press 1 to start. Press N then L: the selected car turns left under its
   arrow; the following four go straight on the subsequent main green.

## Validation

45 software tests: 44 passed and one RTL-dependent test skipped. Coverage
includes all direction/turn combinations with five-car queues, no follower
rerouting, spacing, completing both queues, banking all twenty cars, sequence
wrap and recovering from reset mid-snapshot. Software reference images show
the busier streets. Junction entry remains serialized for conflicting paths.

Quartus fitting, timing and hardware operation have not been verified here.
Updated RTL regression benches are included for execution with Icarus Verilog.
