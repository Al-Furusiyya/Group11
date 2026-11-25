; ---- School bus pickup ----------------------------------------------
; B travels through the intersection first, then stops on the exit road.
; Pickup 1 = driving, 3 = waiting for everyone to stop, 2 = boarding,
; 0 = done. The stop arm stays out while traffic is held.
school_bus_begin:
    GET R11, EVENT_SLOT
    MOV R10, R11
    LSHI R10, 4
    LI R0, CARS
    ADDU R10, R0
    CGET R0, MOVEMENT
    LI R1, 4
    CALL metadata
    ; Rear-clear distance + 6 units for the large bus + 12 units beyond.
    LI R1, 1152
    ADDU R0, R1
    CGET R1, PROGRESS
    CMP R1, R0
    JLE bus_set_stop
    ; If a resumed bus is beyond the pickup point, stop at its current
    ; location. Never reverse a vehicle.
    MOV R0, R1
bus_set_stop:
    SET R0, BUS_STOP
    SETI BUS_PICKUP, 1
    SETI BUS_TICKS, 0
    SETI BUS_BOARDED, 0
    RET

; Use the existing braking routine for the outbound pickup point, without
; overriding a stricter admission or following limit.
school_bus_limit:
    GET R0, BUS_PICKUP
    CMP R0, 0
    JE bus_return
    GET R0, EVENT_SLOT
    CMP R11, R0
    JNE bus_return
    GET R0, BUS_STOP
    GET R1, LIMIT
    CMP R0, R1
    JGE bus_return
    SET R0, LIMIT
bus_return:
    RET

; Everyone else slows down using the existing deceleration. This includes
; the cars traveling against the bus (both directions on the same road).
; We hold the other road too, since the child is outside the vehicle.
school_bus_brake_others:
    ; A bus can wait here during a higher-priority service. Keep its
    ; identity and position; it cannot join normal traffic accidentally.
    CMP R11, SERVICE_FIRST
    JLT bus_brake_pickup
    GET R0, EVENT_SLOT
    CMP R11, R0
    JNE service_hold
    GET R0, EVENT_ROLLING
    CMP R0, 0
    JNE active_service_speed
service_hold:
    SETI DESIRED, 0
    RET
active_service_speed:
    CALL emergency_approach_pace
    J bus_brake_pickup
bus_brake_pickup:
    GET R0, BUS_PICKUP
    CMP R0, 2
    JE bus_brake_hold
    CMP R0, 3
    JNE bus_return
bus_brake_hold:
    GET R0, EVENT_SLOT
    CMP R11, R0
    JE bus_return
    CGET R0, ENTERED
    CMP R0, 0
    JE bus_brake_now
    CGET R0, PROGRESS
    GET R1, CLEAR_AT
    CMP R0, R1
    JLT bus_return
bus_brake_now:
    SETI DESIRED, 0
    RET

school_bus_step:
    GET R0, BUS_PICKUP
    CMP R0, 0
    JE bus_return
    CMP R0, 2
    JE bus_boarding
    CMP R0, 3
    JE bus_wait_stopped
    ; R10/R11 still point at the service car from event_passing.
    GET R0, FAULT
    CMP R0, 0
    JNE bus_return
    CGET R0, PROGRESS
    GET R1, BUS_STOP
    CMP R0, R1
    JLT bus_return
    SETI BUS_PICKUP, 3
bus_wait_stopped:
    GET R0, FAULT
    CMP R0, 0
    JNE bus_return
    GET R0, OCCUPIED
    CMP R0, 0
    JNE bus_return
    ; The child only begins when every live car has reached zero speed.
    LI R8, CARS
    LI R9, ALL_SLOTS
bus_check_stopped:
    PGET R0, LIVE
    CMP R0, 0
    JE bus_check_next
    PGET R0, VELOCITY
    CMP R0, 0
    JNE bus_return
bus_check_next:
    ADDI R8, 16
    ADDI R9, -1
    CMP R9, 0
    JNE bus_check_stopped
    SETI BUS_PICKUP, 2
    SETI BUS_TICKS, 180
    RET
bus_boarding:
    GET R0, BUS_TICKS
    ADDI R0, -1
    SET R0, BUS_TICKS
    CMP R0, 0
    JNE bus_return
    SETI BUS_PICKUP, 0
    SETI BUS_BOARDED, 1
    RET

; Word 14 carries the child's boarding progress (0..63) to the VGA.
; The CPU owns the dwell timer; the scene only draws the moving child.
school_bus_display:
    LI R0, 0
    GET R1, BUS_PICKUP
    CMP R1, 2
    JNE bus_store_display
    LI R0, 180
    GET R1, BUS_TICKS
    SUB R0, R1
    LI R1, 45
    MUL R0, R1
    LSHI R0, -7
bus_store_display:
    LI R1, IO_DISPLAY+14
    STOR R0, R1
    RET
