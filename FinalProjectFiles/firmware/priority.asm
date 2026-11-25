; ---- Priority events ------------------------------------------------
; We keep normal traffic in its own files. This just changes who can enter
; the intersection, and saves the old phase so we can continue afterwards.
; 1=A, 2=F, 3=C, 4=B. The bus waits behind pedestrians and emergency cars.
; Stage 1 clears the road, 2 admits one priority car, 3 clears it again.
; X is a simulated fault. Existing cars and walkers can finish safely.
priority_command:
    GET R0, COMMAND
    CMP R0, 17
    JE event_fault
    CMP R0, 12
    JLT event_direction_key
    CMP R0, 15
    JGT event_escape
    ADDI R0, -11
    CMP R0, 4
    JE event_bus_key
    SET R0, EVENT_PENDING
    ADDI R0, -1
    SET R0, EVENT_PENDING_DIR
    SETI EVENT_SELECT, 1
    RET
event_bus_key:
    GET R0, EVENT_TYPE
    CMP R0, 4
    JE event_step_return
    GET R0, BUS_PENDING
    CMP R0, 0
    JE event_bus_new
    GET R0, BUS_DIR
    ADDI R0, SERVICE_FIRST
    LSHI R0, 4
    LI R1, CARS
    ADDU R0, R1
    LOAD R0, R0
    CMP R0, 0
    JNE event_step_return
event_bus_new:
    SETI BUS_PENDING, 1
    SETI BUS_DIR, 3
    SETI EVENT_SELECT, 2
    RET
event_fault:
    GET R0, FAULT
    XORI R0, 1
    SET R0, FAULT
    RET
event_escape:
    CMP R0, 16
    JNE event_normal
    SETI FAULT, 0
    SETI EVENT_PENDING, 0
    ; Don't discard a bus that has already appeared on the road.
    GET R1, BUS_DIR
    ADDI R1, SERVICE_FIRST
    LSHI R1, 4
    LI R2, CARS
    ADDU R1, R2
    LOAD R2, R1
    CMP R2, 0
    JE event_escape_drop_bus
    ADDI R1, PAINT
    LOAD R2, R1
    CMP R2, 32
    JE event_escape_keep_bus
event_escape_drop_bus:
    SETI BUS_PENDING, 0
event_escape_keep_bus:
    SETI EVENT_SELECT, 0
    ; An already moving priority car finishes, rather than disappearing.
    J command_escape
event_direction_key:
    CMP R0, 4
    JLT event_normal
    CMP R0, 7
    JGT event_normal
    GET R1, EVENT_SELECT
    CMP R1, 0
    JE event_normal
    ADDI R0, -4
    CMP R1, 2
    JE event_bus_direction
    SET R0, EVENT_PENDING_DIR
    RET
event_bus_direction:
    SET R0, BUS_DIR
    RET
event_normal:
    ; P starts an ordinary pedestrian request even while an event is queued.
    CMP R0, 11
    JNE event_normal_dispatch
    SETI EVENT_SELECT, 0
event_normal_dispatch:
    J handle_command

; During priority, only the selected approach gets permission to enter.
; Emergency vehicles join normal traffic; only the bus waits offscreen
; for its separate pickup sequence.
; Already admitted cars finish using the old movement and yielding routines.
priority_admission:
    GET R0, FAULT
    CMP R0, 0
    JNE event_block
    GET R0, EVENT_STAGE
    CMP R0, 0
    JNE event_admission_active
    CMP R11, SERVICE_FIRST
    JGE event_block
    RET
event_admission_active:
    CMP R0, 2
    JNE event_block
    GET R0, EVENT_SLOT
    CMP R11, R0
    JE event_admission_service
    ; Let the ordinary queue in front of the new service vehicle clear.
    ; No opposing direction or extra service slot may enter.
    CMP R11, SERVICE_FIRST
    JGE event_block
    GET R0, DIRECTION
    GET R1, EVENT_DIR
    CMP R0, R1
    JNE event_block
    GET R0, BUS_PICKUP
    CMP R0, 2
    JE event_block
    CMP R0, 3
    JE event_block
    GET R8, EVENT_SLOT
    LSHI R8, 4
    LI R0, CARS
    ADDU R8, R0
    PGET R0, ENTERED
    CMP R0, 0
    JNE emergency_follow_release
    ; For A/F/C, distinguish cars ahead of the emergency from followers.
    PGET R0, PROGRESS
    GET R1, AT
    GET R2, ENTRY
    SUB R1, R2
    LI R2, 4352
    ADDU R1, R2
    CMP R1, R0
    JLE event_block
    J event_allow_ordinary
emergency_follow_release:
    GET R0, EVENT_TYPE
    CMP R0, 4
    JE event_block
    PGET R0, PROGRESS
    LI R1, 9600
    CMP R0, R1
    JLT event_block
event_allow_ordinary:
    SETI ALLOWED, 1
    RET
event_admission_service:
    GET R0, EVENT_ROLLING
    CMP R0, 0
    JE event_block
    GET R0, EVENT_TYPE
    CMP R0, 4
    JE event_service_bus
    GET R0, EVENT_TURN_BUSY
    CMP R0, 0
    JNE event_block
event_service_bus:
    ; No conflicting turn is ahead of A/F/C. The bus can cross before
    ; boarding; its stop is on the outbound side.
    GET R0, BUS_PICKUP
    CMP R0, 2
    JE event_block
    CMP R0, 3
    JE event_block
    SETI ALLOWED, 1
    RET
event_block:
    SETI ALLOWED, 0
event_admission_return:
    RET
priority_lights:
    GET R0, FAULT
    GET R1, EVENT_STAGE
    OR R0, R1
    CMP R0, 0
    JE event_lights_return
    SETI NS, 0
    SETI EW, 0
    SETI LEFT_MASK, 0
    ; WALK mask stays visible if a fault arrives during a crossing.
event_lights_return:
    RET

priority_step:
    GET R0, RUNNING
    CMP R0, 0
    JE event_step_return
    GET R0, EVENT_STAGE
    CMP R0, 0
    JNE event_active
    ; Never cut a person off halfway through the zebra crossing.
    GET R0, PHASE
    CMP R0, WALK
    JE signals
    GET R0, FAULT
    CMP R0, 0
    JNE event_begin
    GET R0, EVENT_PENDING
    CMP R0, 0
    JNE event_begin
    GET R0, PHASE
    CMP R0, DEFAULT
    JNE event_check_bus
    GET R0, PENDING_VALID
    CMP R0, 0
    JE event_check_bus
    GET R0, PENDING_PED
    CMP R0, 0
    JNE signals_pending
event_check_bus:
    GET R0, BUS_PENDING
    CMP R0, 0
    JNE event_bus_priority
    GET R0, PHASE
    CMP R0, DEFAULT
    JNE signals
    GET R0, PENDING_VALID
    CMP R0, 0
    JNE signals_pending
    J signals
event_bus_priority:
    GET R0, HAVE_REQUEST
    GET R1, REQ_PED
    AND R0, R1
    CMP R0, 0
    JNE signals
    GET R0, PENDING_VALID
    GET R1, PENDING_PED
    AND R0, R1
    CMP R0, 0
    JNE signals
event_begin:
    GET R0, PHASE
    SET R0, EVENT_SAVED_PHASE
    GET R0, TIMER
    SET R0, EVENT_SAVED_TIMER
    SETI PHASE, EMERGENCY
    SETI EVENT_STAGE, 1
    SETI EVENT_WAIT, 72
    RET
event_active:
    GET R0, EVENT_STAGE
    CMP R0, 2
    JE event_passing
    GET R0, EVENT_WAIT
    CMP R0, 0
    JE event_wait_clear
    ADDI R0, -1
    SET R0, EVENT_WAIT
    RET
event_wait_clear:
    GET R0, OCCUPIED
    CMP R0, 0
    JNE event_step_return
    GET R0, FAULT
    CMP R0, 0
    JNE event_step_return
    GET R0, EVENT_PENDING
    CMP R0, 0
    JNE event_take_emergency
    GET R0, BUS_PENDING
    CMP R0, 0
    JE event_restore
    GET R0, HAVE_REQUEST
    GET R1, REQ_PED
    AND R0, R1
    CMP R0, 0
    JNE event_restore
    GET R0, PENDING_VALID
    GET R1, PENDING_PED
    AND R0, R1
    CMP R0, 0
    JNE event_restore
    SETI EVENT_TYPE, 4
    GET R0, BUS_DIR
    SET R0, EVENT_DIR
    SETI BUS_PENDING, 0
    J event_choose
event_take_emergency:
    ; A suspended school bus owns its approach slot. Finish that bus
    ; before another service on the same approach, never replace it.
    GET R0, EVENT_PENDING_DIR
    ADDI R0, SERVICE_FIRST
    LSHI R0, 4
    LI R1, CARS
    ADDU R0, R1
    LOAD R1, R0
    CMP R1, 0
    JNE event_resume_bus_first
event_take_new_emergency:
    GET R0, EVENT_PENDING
    SET R0, EVENT_TYPE
    GET R0, EVENT_PENDING_DIR
    SET R0, EVENT_DIR
    SETI EVENT_PENDING, 0
    J event_choose
event_resume_bus_first:
    SETI EVENT_TYPE, 4
    GET R0, BUS_DIR
    SET R0, EVENT_DIR
    SETI BUS_PENDING, 0
event_choose:
    SETI EVENT_SELECT, 0
    SETI EVENT_ROLLING, 0
    SETI EVENT_TURN_BUSY, 0
    CALL emergency_seed_lead
    CALL event_pick_car
    GET R0, EVENT_SLOT
    CMP R0, 31
    JE event_retry
    SETI EVENT_STAGE, 2
    GET R0, EVENT_TYPE
    CMP R0, 4
    JNE emergency_start_roll
    CALL school_bus_begin
    RET
event_retry:
    ; All five slots might still be exiting. Try again after they move.
    GET R0, EVENT_TYPE
    CMP R0, 4
    JE event_retry_bus
    SET R0, EVENT_PENDING
    GET R0, EVENT_DIR
    SET R0, EVENT_PENDING_DIR
    RET
event_retry_bus:
    SETI BUS_PENDING, 1
    GET R0, EVENT_DIR
    SET R0, BUS_DIR
    RET
event_passing:
    GET R11, EVENT_SLOT
    MOV R10, R11
    LSHI R10, 4
    LI R0, CARS
    ADDU R10, R0
    CGET R0, LIVE
    CMP R0, 0
    JE event_finish
    CALL event_prepare_roll
    ; A fault blocks its entry. An emergency also outranks a waiting bus.
    GET R0, EVENT_TYPE
    CMP R0, 4
    JNE event_step_return
    ; Once the child starts walking, let the pickup finish before preemption.
    GET R0, BUS_PICKUP
    CMP R0, 2
    JE school_bus_step
    ; Once the child is aboard, finish the same trip. Don't schedule a
    ; second pickup for the same vehicle if an emergency arrived meanwhile.
    GET R0, BUS_BOARDED
    CMP R0, 0
    JNE event_step_return
    GET R0, EVENT_PENDING
    CMP R0, 0
    JNE event_bus_preempt
    GET R0, PENDING_VALID
    GET R1, PENDING_PED
    AND R0, R1
    CMP R0, 0
    JE school_bus_step
event_bus_preempt:
    GET R0, EVENT_PENDING
    CMP R0, 0
    JE event_bus_preempt_ok
    GET R0, EVENT_PENDING_DIR
    GET R1, EVENT_DIR
    CMP R0, R1
    JE school_bus_step
event_bus_preempt_ok:
    CGET R0, ENTERED
    CMP R0, 0
    JNE school_bus_step
    SETI BUS_PENDING, 1
    GET R0, EVENT_DIR
    SET R0, BUS_DIR
event_finish:
    SETI EVENT_ROLLING, 0
    SETI BUS_PICKUP, 0
    SETI BUS_TICKS, 0
    SETI BUS_BOARDED, 0
    SETI EVENT_STAGE, 3
    SETI EVENT_WAIT, 48
    SETI EVENT_SLOT, 31
    SETI EVENT_TYPE, 0
    RET
event_restore:
    SETI EVENT_ROLLING, 0
    GET R0, EVENT_SAVED_PHASE
    SET R0, PHASE
    GET R0, EVENT_SAVED_TIMER
    SET R0, TIMER
    SETI EVENT_STAGE, 0
    SETI EVENT_TYPE, 0
    SETI EVENT_SLOT, 31
event_step_return:
    RET

; The school bus still clears its lead queue before starting the trip.
; For A/F/C, recompute conflicting turns while the vehicle rolls in.
; Other approaches stay red until this event completes.
; Keep R10/R11 pointing to the service slot for event_passing.
event_prepare_roll:
    GET R0, EVENT_TYPE
    CMP R0, 4
    JNE emergency_check_turns
    GET R0, EVENT_ROLLING
    CMP R0, 0
    JNE event_step_return
    GET R0, FAULT
    CMP R0, 0
    JNE event_step_return
    GET R0, OCCUPIED
    CMP R0, 0
    JNE event_step_return
    CGET R6, PROGRESS
    LI R0, 4352
    SUB R6, R0
    GET R8, EVENT_DIR
    LSHI R8, 4
    LI R0, CARS
    ADDU R8, R0
    LI R9, 5
roll_check_queue:
    PGET R0, LIVE
    CMP R0, 0
    JE roll_next
    PGET R0, ENTERED
    CMP R0, 0
    JNE roll_next
    ; A requeued bus can have normal followers. Don't wait for those
    ; followers to cross first: they are supposed to remain behind it.
    PGET R0, MOVEMENT
    LI R1, 0
    CALL metadata
    PGET R3, PROGRESS
    SUB R3, R0
    CMP R3, R6
    JGT event_step_return
roll_next:
    ADDI R8, 64
    ADDI R9, -1
    CMP R9, 0
    JNE roll_check_queue
    SETI EVENT_ROLLING, 1
    RET

; Word 6 was unused in our display packet. Send the event type, direction,
; stage, slot and fault flag together. Verilog only draws these fields.
; bits 2:0 type, 4:3 direction, 6:5 stage, 11:7 slot, 12 fault, 13 left turn.
priority_display:
    GET R0, EVENT_TYPE
    GET R1, EVENT_DIR
    CMP R0, 0
    JNE event_pack
    GET R0, EVENT_PENDING
    GET R1, EVENT_PENDING_DIR
    CMP R0, 0
    JNE event_pack
    GET R0, BUS_PENDING
    CMP R0, 0
    JE event_pack
    LI R0, 4
    GET R1, BUS_DIR
event_pack:
    LSHI R1, 3
    OR R0, R1
    GET R1, EVENT_STAGE
    LSHI R1, 5
    OR R0, R1
    GET R1, EVENT_SLOT
    LSHI R1, 7
    OR R0, R1
    GET R1, FAULT
    LSHI R1, 12
    OR R0, R1
    GET R1, EVENT_STAGE
    CMP R1, 2
    JNE event_pack_store
    GET R10, EVENT_SLOT
    LSHI R10, 4
    LI R1, CARS
    ADDU R10, R1
    CGET R1, MOVEMENT
    CMP R1, LEFT
    JNE event_pack_store
    LI R1, 8192
    OR R0, R1
event_pack_store:
    GET R1, BUS_PICKUP
    LSHI R1, 14
    OR R0, R1
    LI R1, IO_DISPLAY+6
    STOR R0, R1
    RET

; Each approach owns one extra slot. A service begins offscreen, behind
; the existing queue, and never changes the identity of an ordinary car.
event_pick_car:
    GET R11, EVENT_DIR
    ADDI R11, SERVICE_FIRST
    SET R11, EVENT_SLOT
    MOV R10, R11
    LSHI R10, 4
    LI R0, CARS
    ADDU R10, R0
    CGET R0, LIVE
    CMP R0, 0
    JNE event_step_return
    MOV R1, R10
    LI R2, 16
    LI R0, 0
event_spawn_clear:
    STOR R0, R1
    ADDI R1, 1
    ADDI R2, -1
    CMP R2, 0
    JNE event_spawn_clear
    LI R0, 1
    CSET R0, LIVE
    CSET R0, MOVEMENT
    GET R0, EVENT_TYPE
    LSHI R0, 3
    CSET R0, PAINT
    ; Start beyond the road edge, or farther back if the queue is long.
    GET R0, EVENT_DIR
    LSHI R0, 2
    LI R1, STATS+1
    ADDU R0, R1
    LOAD R0, R0
    LI R1, 1536
    SUB R0, R1
    LI R1, -ROUTE_EXTENSION
    GET R2, EVENT_TYPE
    CMP R2, 4
    JE event_spawn_edge_ready
    GET R2, EVENT_DIR
    CMP R2, 2
    JGE event_spawn_ew_edge
    LI R1, -2048
    J event_spawn_edge_ready
event_spawn_ew_edge:
    LI R1, -3584
event_spawn_edge_ready:
    CMP R0, R1
    JLE event_spawn_progress
    MOV R0, R1
event_spawn_progress:
    CSET R0, PROGRESS
    ; The spawner runs later in this same frame. Update the tail now so
    ; it puts new normal cars behind the service, not in front/on top.
    GET R1, EVENT_DIR
    LSHI R1, 2
    LI R2, STATS+1
    ADDU R1, R2
    STOR R0, R1
    RET
