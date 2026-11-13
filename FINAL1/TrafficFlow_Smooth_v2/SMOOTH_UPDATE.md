# v2 update

Compared with TrafficFlow_Smooth v1, **only three runtime files change**:

| File | Changes |
|---|---|
| `Python/control.py` | Stable sprite slots; gentler following/braking and curve speed; center left-turn staging and separate buffered gap decision; compatible traffic during pedestrian service |
| `sprite_smoother.v` | Adaptive-cadence Q8 interpolation with shared arithmetic, fractional rebasing and heading-change continuity |
| `vga_scene.v` | Matching signal housings, crisp arrow/connector, clear red/amber/green colors, pedestrian-conflicting left indication |

The app, Python link/protocol, Tcl host, CPU/JTAG/firmware, top wiring, QPF/QSF,
pins and SDC are unchanged from v1. No new Python libraries, ports, UART adapter
or additional QSF entries are needed. From the original working upload the
existing v1 top/source-list changes are also needed, so extracting this complete
project is recommended.

If updating v1 in place, copy all three runtime files, full-compile and program
the new SOF. For a clean build, extract `TrafficFlow_Smooth_v2.zip`, open its
unchanged `Lab4_Python_JTAG.qpf`, and follow `START_HERE.md`.

New acceptance tests cover stable slots, center braking/wheel direction,
rear clearance, protected-center deadlock prevention, every parallel pedestrian
movement combination and independent car/person body overlap. RTL tests cover
variable cadence, negative movement, heading changes, fractional rebasing,
stall, pause/reset, frame counter wrap and signal/pedestrian pixels.

Previous five-car and fixed-wait notes under `docs/history/` are historical.
