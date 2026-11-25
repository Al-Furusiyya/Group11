; ---- Car motion -----------------------------------------------------
; We update the same twenty slots every frame. A car does not change slots
; when another one leaves, which helps the VGA smoother track the right car.
move_cars:
    GET R0, RUNNING
    CMP R0, 0
    JE motion_return
    LI R10, CARS
    LI R11, 0
motion_car:
    CALL current_route
    CGET R0, LIVE
    CMP R0, 0
    JE spawn_car
    CGET R0, PROGRESS
    SET R0, AT
    SETI LIMIT, 32767
    SETI DESIRED, 103
    SETI ALLOWED, 0
    GET R0, DIRECTION
    CMP R0, 2
    JLT motion_ns
    GET R0, EW
    J motion_green_check
motion_ns:
    GET R0, NS
motion_green_check:
    CMP R0, 2
    JNE motion_left_green
    SETI ALLOWED, 1
motion_left_green:
    CGET R0, MOVEMENT
    CMP R0, LEFT
    JNE motion_walk_check
    GET R0, DIRECTION
    CALL direction_bit
    GET R1, LEFT_MASK
    AND R0, R1
    CMP R0, 0
    JE motion_walk_check
    SETI ALLOWED, 1
motion_walk_check:
    GET R0, HAVE_REQUEST
    GET R1, REQ_PED
    AND R0, R1
    CMP R0, 0
    JE motion_stop_line
    GET R0, PHASE
    CMP R0, SELECT
    JE motion_walk_conflict
    CMP R0, WALK
    JNE motion_stop_line
motion_walk_conflict:
    GET R0, ROUTE
    LI R1, CONFLICTS
    ADDU R0, R1
    LOAD R0, R0
    GET R1, REQ_DIR
    LI R2, 1
motion_walk_bit:
    CMP R1, 0
    JE motion_walk_bit_ready
    LSHI R2, 1
    ADDI R1, -1
    J motion_walk_bit
motion_walk_bit_ready:
    AND R0, R2
    CMP R0, 0
    JE motion_stop_line
    SETI ALLOWED, 0
motion_stop_line:
    ; Priority only changes admission. The old braking and movement stay here.
    CALL priority_admission
    CGET R0, ENTERED
    CMP R0, 0
    JNE motion_turn_speed
    GET R0, ALLOWED
    CMP R0, 0
    JNE motion_turn_speed
    GET R0, ENTRY
    SET R0, LIMIT
motion_turn_speed:
    CALL school_bus_limit
    CGET R0, MOVEMENT
    CMP R0, STRAIGHT
    JE motion_left_wait
    GET R0, AT
    GET R1, TURN_END
    CMP R0, R1
    JGE motion_left_wait
    SETI DESIRED, 60
motion_left_wait:
    CGET R0, ENTERED
    CMP R0, 0
    JE motion_headway
    CGET R0, MOVEMENT
    CMP R0, LEFT
    JNE motion_headway
    CGET R0, COMMITTED
    CMP R0, 0
    JNE motion_headway
    CALL left_gap
    GET R0, GAP_OK
    CMP R0, 0
    JE motion_hold
    GET R0, AT
    GET R1, HOLD
    LI R2, 384
    SUB R1, R2
    CMP R0, R1
    JLT motion_hold
    GET R0, ALLOWED
    CMP R0, 0
    JNE motion_commit_left
    GET R0, PHASE
    CMP R0, YELLOW
    JE motion_commit_left
    CMP R0, EMERGENCY
    JE motion_commit_left
    CMP R0, CLEAR
    JNE motion_hold
    GET R0, RESUME_VALID
    CMP R0, 0
    JE motion_hold
motion_commit_left:
    LI R0, 1
    CSET R0, COMMITTED
motion_hold:
    CGET R0, COMMITTED
    CMP R0, 0
    JNE motion_headway
    GET R0, HOLD
    SET R0, LIMIT
motion_headway:
    CALL school_bus_brake_others
    CGET R0, ENTERED
    CMP R0, 0
    JNE motion_brake
    CALL following_gap
motion_brake:
    GET R0, LIMIT
    CMP R0, 32767
    JE motion_speed
    GET R1, AT
    SUB R0, R1
    CMP R0, 0
    JGT motion_brake_cap
    SETI DESIRED, 0
    J motion_speed
motion_brake_cap:
    CALL braking_cap
    GET R1, DESIRED
    CMP R0, R1
    JGE motion_speed
    SET R0, DESIRED
motion_speed:
    GET R1, DESIRED
    CMP R1, 0
    JGE motion_speed_nonnegative
    LI R1, 0
motion_speed_nonnegative:
    CGET R0, VELOCITY
    CMP R0, R1
    JGE motion_decelerate
    ADDI R0, 1
    J motion_advance
motion_decelerate:
    CMP R0, R1
    JE motion_advance
    ADDI R0, -2
    CMP R0, R1
    JGE motion_advance
    MOV R0, R1
motion_advance:
    CSET R0, VELOCITY
    CGET R1, FRACTION
    ADDU R1, R0
    MOV R2, R1
    ANDI R2, 3
    CSET R2, FRACTION
    LSHI R1, -2
    GET R0, AT
    ADDU R1, R0
    GET R2, LIMIT
    CMP R1, R2
    JLE motion_no_clip
    MOV R1, R2
    LI R2, 0
    CSET R2, VELOCITY
    CSET R2, FRACTION
motion_no_clip:
    CMP R1, R0
    JGE motion_forward
    MOV R1, R0
motion_forward:
    CSET R1, PROGRESS
    CGET R0, ENTERED
    CMP R0, 0
    JNE motion_lock
    GET R0, ENTRY
    CMP R1, R0
    JLT motion_lock
    GET R0, ALLOWED
    CMP R0, 0
    JE motion_lock
    LI R0, 1
    CSET R0, ENTERED
    CGET R0, MOVEMENT
    CMP R0, LEFT
    JE motion_lock
    LI R0, 1
    CSET R0, COMMITTED
motion_lock:
    GET R0, NOTICE
    CMP R1, R0
    JLT motion_target
    LI R0, 1
    CSET R0, LOCKED
motion_target:
    GET R0, TARGET
    CMP R11, R0
    JNE motion_exit
    CGET R0, ENTERED
    CMP R0, 0
    JE motion_exit
    GET R0, CLEAR_AT
    CMP R1, R0
    JLT motion_exit
    SETI TARGET_DONE, 1
motion_exit:
    GET R0, TOTAL
    CMP R1, R0
    JLT motion_next
    ; Retire only after the last drawn position is wholly out of the scene.
    ; The margin covers the bigger vehicles and one frame of smoothing.
    CGET R2, X
    CMP R2, 120
    JLE motion_retire
    CMP R2, 672
    JGE motion_retire
    LI R2, ROUTE_EXTENSION
    ADDU R0, R2
    CMP R1, R0
    JLT motion_next
motion_retire:
    LI R0, 0
    CSET R0, LIVE
    CSET R0, BATCH
motion_next:
    ADDI R10, 16
    ADDI R11, 1
    CMP R11, ALL_SLOTS
    JLT motion_car
    GET R0, EVENT_STAGE
    CMP R0, 0
    JNE motion_return
    GET R0, FEED_USER
    CMP R0, 0
    JE motion_return
    GET R0, REQ_DIR
    LSHI R0, 2
    LI R1, STATS
    ADDU R0, R1
    LOAD R1, R0
    CMP R1, 5
    JNE motion_return
    XORI R0, 4
    LOAD R1, R0
    CMP R1, 5
    JNE motion_return
    SETI FEED_USER, 0
motion_return:
    RET

; ---- Spawn only where the current service needs cars ----------------
spawn_car:
    CMP R11, SERVICE_FIRST
    JGE motion_next
    GET R0, FAULT
    CMP R0, 0
    JNE motion_next
    GET R0, EVENT_STAGE
    CMP R0, 0
    JE spawn_normal
    CMP R0, 2
    JNE motion_next
    GET R0, EVENT_TYPE
    CMP R0, 4
    JE motion_next
    ; During A/F/C keep the ordinary approaches populated. The existing
    ; stop lines and headway rules hold the other approaches at red.
    J spawn_yes
spawn_normal:
    GET R0, PHASE
    CMP R0, DEFAULT
    JNE spawn_request
    GET R0, DIRECTION
    LSHI R0, -1
    GET R1, IDLE_AXIS
    CMP R0, R1
    JE spawn_yes
spawn_request:
    GET R0, HAVE_REQUEST
    CMP R0, 0
    JE motion_next
    GET R0, REQ_PED
    CMP R0, 0
    JE spawn_user
    GET R0, PHASE
    CMP R0, SELECT
    JE spawn_axis
    CMP R0, WALK
    JE spawn_axis
    J motion_next
spawn_user:
    GET R0, FEED_USER
    CMP R0, 0
    JNE spawn_axis
    GET R0, TARGET
    CMP R0, 31
    JNE motion_next
    GET R0, DIRECTION
    GET R1, REQ_DIR
    CMP R0, R1
    JE spawn_yes
    J motion_next
spawn_axis:
    GET R0, DIRECTION
    ANDI R0, 2
    GET R1, REQ_DIR
    ANDI R1, 2
    CMP R0, R1
    JNE motion_next
spawn_yes:
    MOV R1, R10
    LI R2, 16
    LI R0, 0
spawn_clear:
    STOR R0, R1
    ADDI R1, 1
    ADDI R2, -1
    CMP R2, 0
    JNE spawn_clear
    LI R0, 1
    CSET R0, LIVE
    CSET R0, MOVEMENT
    GET R0, DIRECTION
    LSHI R0, 2
    LI R7, STATS
    ADDU R7, R0
    LOAD R1, R7
    ADDI R7, 1
    LOAD R0, R7
    GET R2, DIRECTION
    ADDI R2, SERVICE_FIRST
    LSHI R2, 4
    LI R3, CARS
    ADDU R2, R3
    LOAD R3, R2
    CMP R3, 0
    ; Includes a suspended bus, even if no ordinary cars are present.
    JE spawn_normal_gap
spawn_behind_service:
    LI R2, 1536
    SUB R0, R2
    J spawn_tail
spawn_normal_gap:
    LI R2, 1024
    SUB R0, R2
    CMP R1, 0
    JNE spawn_tail
    LI R0, 0
spawn_tail:
    CSET R0, PROGRESS
    STOR R0, R7
    ADDI R7, -1
    ADDI R1, 1
    STOR R1, R7
    GET R0, NEXT_PAINT
    CSET R0, PAINT
    ADDI R0, 1
    CMP R0, 3
    JLT spawn_paint
    LI R0, 0
spawn_paint:
    SET R0, NEXT_PAINT
    GET R0, EVENT_STAGE
    CMP R0, 2
    JE spawn_alternate
    GET R0, HAVE_REQUEST
    CMP R0, 0
    JE spawn_alternate
    GET R0, REQ_PED
    CMP R0, 0
    JNE spawn_alternate
    GET R0, DIRECTION
    ANDI R0, 2
    GET R1, REQ_DIR
    ANDI R1, 2
    CMP R0, R1
    JNE spawn_target
    LI R0, 1
    CSET R0, BATCH
spawn_target:
    GET R0, TARGET
    CMP R0, 31
    JNE motion_next
    GET R0, DIRECTION
    GET R1, REQ_DIR
    CMP R0, R1
    JNE motion_next
    SET R11, TARGET
    GET R0, REQ_MOVE
    CSET R0, MOVEMENT
    J motion_next
spawn_alternate:
    ADDI R7, 2
    LOAD R0, R7
    MOV R1, R0
    ANDI R1, 1
    ADDI R1, 1
    CSET R1, MOVEMENT
    ADDI R0, 1
    STOR R0, R7
    J motion_next

; ---- Left turns: stage in the middle, then look for a usable gap ------
; We include an approaching car before it reaches the crossing. Waiting
; until it is beside us would let the left turn almost hit the last car.
left_gap:
    SETI GAP_OK, 1
    LI R8, CARS
    LI R9, 0
gap_peer:
    CMP R9, R11
    JE gap_next
    PGET R0, LIVE
    CMP R0, 0
    JE gap_next
    MOV R0, R9
    ANDI R0, 3
    GET R1, PEER
    CMP R0, R1
    JNE gap_own_lane
    PGET R0, ENTERED
    CMP R0, 0
    JNE gap_oncoming
    GET R0, DIRECTION
    CMP R0, 2
    JLT gap_ns
    GET R0, EW
    J gap_green
gap_ns:
    GET R0, NS
gap_green:
    CMP R0, 2
    JNE gap_next
gap_oncoming:
    PGET R0, MOVEMENT
    LI R1, 0
    CALL metadata
    LI R1, 5120
    SUB R0, R1
    PGET R3, PROGRESS
    CMP R3, R0
    JLT gap_next
    PGET R0, MOVEMENT
    CMP R0, RIGHT
    JE gap_right_end
    LI R1, 0
    CALL metadata
    LI R1, 3200
    J gap_end
gap_right_end:
    LI R1, 3
    CALL metadata
    LI R1, 1536
gap_end:
    ADDU R0, R1
    CMP R3, R0
    JGE gap_next
    SETI GAP_OK, 0
    J gap_next
gap_own_lane:
    GET R1, DIRECTION
    CMP R0, R1
    JNE gap_next
    PGET R0, ENTERED
    CMP R0, 0
    JE gap_next
    PGET R0, MOVEMENT
    CMP R0, LEFT
    JE gap_next
    LI R1, 0
    CALL metadata
    PGET R3, PROGRESS
    SUB R3, R0
    GET R0, HOLD
    GET R1, ENTRY
    SUB R0, R1
    MOV R4, R0
    LI R1, 1280
    SUB R0, R1
    CMP R3, R0
    JLE gap_next
    LI R1, 1152
    ADDU R4, R1
    CMP R3, R4
    JGE gap_next
    SETI GAP_OK, 0
gap_next:
    ADDI R8, 16
    ADDI R9, 1
    CMP R9, ALL_SLOTS
    JLT gap_peer
    RET

; ---- Following distance before entry --------------------------------
; Cars can split into separate left/outer lanes near the approach. Once
; admitted, they keep moving through the crossing rather than stop mid-road.
following_gap:
    LI R8, CARS
    LI R9, 0
follow_peer:
    CMP R9, R11
    JE follow_next
    PGET R0, LIVE
    CMP R0, 0
    JE follow_next
    MOV R0, R9
    ANDI R0, 3
    GET R1, DIRECTION
    CMP R0, R1
    JNE follow_next
    PGET R0, MOVEMENT
    LI R1, 0
    CALL metadata
    PGET R3, PROGRESS
    SUB R3, R0
    GET R4, AT
    GET R5, ENTRY
    SUB R4, R5
    SUB R3, R4
    CMP R3, 0
    JLE follow_next
    GET R4, AT
    GET R5, NOTICE
    CMP R4, R5
    JLT follow_limit
    PGET R0, MOVEMENT
    LI R1, 1
    CALL metadata
    PGET R4, PROGRESS
    CMP R4, R0
    JLT follow_limit
    PGET R0, MOVEMENT
    CGET R1, MOVEMENT
    CMP R0, LEFT
    JE follow_peer_left
    CMP R1, LEFT
    JE follow_next
    J follow_limit
follow_peer_left:
    CMP R1, LEFT
    JNE follow_next
follow_limit:
    LI R0, 1024
    ; Reserve a longer gap when either car is a truck/bus/service vehicle.
    CMP R11, SERVICE_FIRST
    JGE follow_service_gap
    CMP R9, SERVICE_FIRST
    JLT follow_gap_ready
follow_service_gap:
    LI R0, 1536
follow_gap_ready:
    SUB R3, R0
    GET R4, AT
    ADDU R4, R3
    GET R5, LIMIT
    CMP R4, R5
    JGE follow_speed
    SET R4, LIMIT
follow_speed:
    ASHI R3, -3
    GET R4, DESIRED
    CMP R3, R4
    JGE follow_next
    SET R3, DESIRED
follow_next:
    ADDI R8, 16
    ADDI R9, 1
    CMP R9, ALL_SLOTS
    JLT follow_peer
    RET

; ---- Braking cap ----------------------------------------------------
; A small square-law lookup avoids a divide or square root on this CPU.
; R0 is remaining Q6 distance; R0 returns a Q8/frame speed cap.
braking_cap:
    MOV R3, R0
    LI R0, 4
    CMP R3, 4
    JLT braking_return
    LI R0, 8
    CMP R3, 16
    JLT braking_return
    LI R0, 16
    CMP R3, 36
    JLT braking_return
    LI R0, 24
    CMP R3, 64
    JLT braking_return
    LI R0, 32
    CMP R3, 100
    JLT braking_return
    LI R0, 40
    CMP R3, 144
    JLT braking_return
    LI R0, 48
    CMP R3, 196
    JLT braking_return
    LI R0, 56
    CMP R3, 256
    JLT braking_return
    LI R0, 64
    CMP R3, 324
    JLT braking_return
    LI R0, 72
    CMP R3, 400
    JLT braking_return
    LI R0, 80
    CMP R3, 484
    JLT braking_return
    LI R0, 88
    CMP R3, 576
    JLT braking_return
    LI R0, 96
    CMP R3, 676
    JLT braking_return
    LI R0, 103
braking_return:
    RET
