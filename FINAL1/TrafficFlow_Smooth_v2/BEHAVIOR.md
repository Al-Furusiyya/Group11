# TrafficFlow Smooth v2 behavior

This revision follows the latest request: a left-turn car moves straight into
the middle, yields there, and turns after oncoming traffic clears. Pedestrians
share the signal phase with compatible traffic rather than stopping all cars.
It supersedes the earlier rule that every admitted car must move continuously.
Straight/right cars and left cars already committed to their curved turn still
clear without stopping inside. The center wait is intentional only for lefts.

## Controls and connection

N/S/E/W mean travel destination, not origin. NB travels south to north.
S selects southbound; T selects straight. 1 runs/resumes, 2 pauses, 3 resets.
P then direction requests a pedestrian. A/F/C/B holds new traffic at red;
the same key or Esc releases the hold. Commands in PowerShell need Enter.

The working USB-Blaster/JTAG connection, Lab4 CPU relay, firmware, packet v4,
five banks/twenty sprites, pin assignments, project/top names and SDC remain.
Python owns all traffic decisions. Verilog only renders/interpolates state.

## Stable, smoother motion

Each live car keeps the same VGA slot until it exits. Other cars no longer
shift slots when a leader disappears. FIFO order and lane following use vehicle
identity/progress, not a sprite slot's position in the register bank.

Cruise is 24 road units/s. Curves use 14 units/s with bounded acceleration
between speeds. Continuous headway feedback replaces the old threshold that
alternated between accelerating and braking. Final stop-line/center braking
uses a planned, integrated deceleration instead of a sudden contact clamp.
Minimum queue spacing remains 16 units; moving headway is 0.65 seconds.

At VGA frame boundaries, `sprite_smoother.v` retains Q8 fractional position,
measures the incoming snapshot cadence, and spreads motion over that interval.
Its shared arithmetic processes forty coordinates in forty 50 MHz cycles
(0.8 microseconds), within vertical blank. Heading changes do not snap a car's
position. Paint/visibility changes, large jumps, pause and reset still snap.
The fractional output is rounded to the nearest native pixel, with exact target
completion. Late snapshots rebase from the current fractional position.

The renderer never extrapolates through a missing packet. It adapts across
1–30 VGA-frame intervals; a sudden host stall can still limit smoothness.
Interpolation adds roughly one snapshot of visual delay, bounded at about
half a second. RGB, sync and blanking retain their matched output registers.

## Left turns: enter, yield, commit

The first eligible selected car changes to the inner lane before the existing
notice boundary. It enters on its main green, proceeds straight to the center
waiting pocket, and keeps its wheels straight while yielding. For NB, the
holding point is (east=3.75, north=-4) in road units; the other approaches are
rotations of the same geometry. The curve starts at that point, not at the
stop line. A safe gap may let the car roll through without a compulsory stop.

Entry and turning are separate safety decisions. Entry reserves the approach
and stationary center pocket. Turning checks the complete curved/exiting path
against admitted traffic and approaching opposing straight/right cars. The
opposing straight car's rear must clear the central zone with extra space;
future checks also include a 0.65-second arrival-time buffer. This avoids the
previous turn that cut closely behind the last oncoming car. Conditions are
rechecked every 1/60-second simulation step.

The outer straight lane may pass the waiting left car. Once a left commits to
its curve, it completes it even if signals change. If actually held for five
seconds, it requests amber and clearance for protected service. Clearance
excludes only that stationary target, preventing it from waiting forever for
itself to leave. Other committed cars must clear first. An already entered
left may safely finish on amber; if it does, no unnecessary one-frame green
arrow is flashed afterwards. Emergency-held, already entered lefts may clear
a safe gap; no new cars enter on emergency red.

## Pedestrians with compatible traffic

The requested pedestrian uses the same far-side crossing as v1. WB remains on
the northwestern zebra. The model uses the actual rendered foot positions,
not the sprite's upper-left corner. The whole zebra is reserved throughout WALK,
including its ends and body-clearance allowance. Cars cannot thread behind or
in front of the moving person on that crossing.

Parallel main signals stay green. Their straight cars and turns that do not
cross the active zebra can proceed; perpendicular traffic stays red. Turns
through the occupied zebra wait before entry. A conflicting vehicle already
admitted before the request must finish before WALK starts. Compatible vehicles
need not empty the entire intersection. Parallel traffic is replenished during
selection/WALK, subject to the same five-slot limit per approach.

| Pedestrian | Green axis | Turns across this zebra that wait |
|---|---|---|
| NB, west-side zebra | NB/SB | NB left, SB right |
| SB, east-side zebra | NB/SB | SB left, NB right |
| EB, south-side zebra | EB/WB | EB right, WB left |
| WB, north-side zebra | EB/WB | WB right, EB left |

All four crossings last five simulated seconds and reach their exact endpoints.
After WALK the active axis receives amber, then clearance before another phase.
A standing duplicate person is hidden during the crossing. Pause freezes the
person, cars and clocks. Emergency saves and resumes crossing progress after
clearance; all admitted nonconflicting cars may finish meanwhile.

## Signals, timing and requests

Left-arrow housings now match the main signals' eleven-pixel width and center.
A short connector joins them. The arrow is crisp and symmetric: coral red means
stop, amber means permissive/yield, mint green means protected. A left that
crosses an active pedestrian zebra is red even while its main signal is green.
Signal states remain frame-atomic; there is no cosmetic blinking or color fade
that would obscure a change of permission.

Direction selection lasts 2 seconds, amber 1.2 seconds, minimum clearance
0.8 seconds, maximum left waiting budget 5 seconds, WALK 5 seconds. Clearance
extends for actual conflicting occupancy. These are scaled demonstration
settings. USER service ends when its finite requested batch, including the
selected target, clears. Default EB/WB green is continuous; its original display
counter repeats. The USER counter is a capped clearance estimate; YIELD is the
protection budget, not a mandatory wait.

Only the first eligible car takes a requested movement; other unlocked cars
in that service batch default straight. Locked routes are preserved. The notice
boundary still locks a choice 52 units before the center. One pending request
is kept, last direction wins, and committed cars are never rerouted mid-turn.

The host retains its 0.1-second catch-up cap; a slow link slows simulation rather
than causing a large jump. Physical KEY0 still clears both FPGA and host through
the working reset handshake and requires a fresh Run command.
