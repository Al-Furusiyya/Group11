Historical baseline document. Current behavior/build steps: ../../BEHAVIOR.md and ../../START_HERE.md.

# Traffic behavior and implementation decisions

## Direction and keyboard semantics

NB means travel from geographic south toward north; SB is the reverse. EB
travels west-to-east and WB east-to-west. The isometric road labels indicate
geographic endpoints. Cars originate opposite their selected destination.

S is the southbound input. Straight is labeled S but uses physical T. This
resolves the otherwise ambiguous S key without changing the PS/2 mapping.

KEY0 and keyboard 3 produce an empty, inactive GUI. Run starts default traffic;
Pause freezes simulation time, vehicle positions, pedestrians and countdowns.
Run while already running does not reset a stage. Movement/direction/emergency
commands are ignored while idle or paused; Run/Reset remain available.

## Default flow

EB and WB main signals remain green; NB and SB remain red. Both left arrows on
the active axis stay red. Each EB/WB stream alternates straight, right, straight,
right as successive cars spawn. The default countdown repeats every five
seconds without an unnecessary red flash at each rollover.

There are twenty independent sprites, five per approach. Each direction has
a FIFO queue with 16 road units of spacing; cars waiting beyond the road edge
become visible as they enter. Default traffic replenishes EB/WB continuously.
Inactive NB/SB approaches remain empty until requested. A reservation admits one car into the
conflict area at a time; even opposing green streams may briefly queue at the
stop bar. This conservative policy avoids intersecting paths.

## Direction selection and notice boundary

Selecting N/S/E/W immediately stops new conflicting admissions with all-red
signals. Admitted cars continue clearing. The requested axis's incoming cars
move at 6 road units/second during a five-second CHOOSE stage. Normal travel is
24 road units/second.

L/T/R applies to the first eligible selected-direction car. The four following cars and the paired opposite
queue go straight during user service. Previously locked cars keep their routes. With no choice, the selected car goes straight. A hidden
notice boundary 52 road units before the center locks the movement. Choices
are accepted only while the selection window is open and the target has not
passed that boundary. A previously committed/locked car is never rerouted;
if needed, the request targets the first unlocked car already waiting, or a new car if none is eligible.
A valid late lane-change choice blends into its path without a position jump.

Further direction requests during a maneuver are queued. One pending request is
kept, and a newer pending direction replaces it. L/T/R then edits that pending
request. Requests never interrupt a car halfway through its turn.

After CHOOSE and junction clearance, straight/right traffic gets a five-second
green stage. If any car in the requested axis's five-per-direction batch has not yet cleared,
another five-second green interval is used. Once that batch has cleared, a five-second all-red stage precedes
return to default or service of the next request. Vehicles already admitted
finish; no car is teleported away during a light change.

## Protected left turn

After CHOOSE, the target approaches its red left arrow while previously committed
straight/right cars on the requested axis can clear under main green signals. Approach travel is distance-dependent, not a timed
signal stage; WAIT may display 0 during that travel.

At the entry point the car waits a full five seconds. Its left arrow stays red;
the opposite approach on the same axis may pass under its main green. Then all
main lights turn red. Any already-admitted car is allowed to finish before the
selected left arrow turns green for five seconds. Only that selected left car
can enter. It follows a curved path into its outgoing lane. The requested axis then receives normal green in five-second intervals so
the remaining straight followers clear. A five-second all-red clearance
follows before the next activity.

The countdown may hold at zero while waiting for a committed vehicle's rear to
clear. Clearance is never shortened merely because a timer expired. All timed
signal/selection/walk stages use the common five-second constant.

## Pedestrians

P arms pedestrian selection; a following N/S/E/W specifies travel direction.
There is a five-second all-red clearing stage, extended only if a vehicle is
still inside. The requested pedestrian then moves across the relevant zebra
crossing for five simulated seconds, with its card green and counting down.
All vehicle main and left signals remain red. Another five-second clearance
precedes normal operation. Multiple crossings are serialized.

## Emergency controls

The request did not specify distinct A/F/C/B priority routes. This version
implements each as a separately highlighted all-red hold, not an emergency
vehicle-routing algorithm. Admitted vehicles clear; new vehicles stop. Press
the same emergency key again or Esc to release. After five-second clearance,
the saved stage resumes with its saved timer. Pressing a different emergency
key changes the selected service while preserving the saved stage. Reset
always cancels everything. A pedestrian animation is paused during the hold
and resumes after release/clearance.

## Clock, display and reset behavior

The controller uses fixed 1/60-second simulation steps with a fractional-time
accumulator, so behavior does not depend on how a time interval is subdivided.
The host publishes at up to 30 snapshots/second. It caps one wall-clock update
at 0.1s; a slow or stalled JTAG connection slows the simulation rather than
causing a large visual jump. Timers measure simulated time.

Python alone makes traffic decisions. The FPGA draws the committed snapshot.
Mint beveled borders show Run, direction, movement and pedestrian selections;
Pause uses amber and Reset/emergency use coral. The last pending request can be
highlighted while an earlier maneuver finishes. The central card reports the
active phase, while the menu shows the selected input.

KEY0 asynchronously clears the FPGA display and communication state. The JTAG
status reports reset-pending, even if KEY0 truncated a transfer. The Tcl server
notifies Python; result 3 also rejects subsequent running snapshots until the host
sends an idle/reset snapshot. Python catches that response, resets its
controller, and sends an empty frame. This prevents a running host from undoing
a physical reset on its very next update.
