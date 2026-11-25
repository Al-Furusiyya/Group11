; ---- A/F/C traffic stream --------------------------------------------
; Emergency cars join the road instead of waiting for an empty scene.
; A normal car in front gets green and can clear. The cars behind keep
; their own route and following gap; other approaches continue queuing.
; B still uses the separate school-bus pickup sequence.

; If the approach has no waiting car at all, put one regular car near
; the road entrance. This gives the emergency a lead car even when the
; request is made immediately after Run on an otherwise empty approach.
emergency_seed_lead:
    GET R0, EVENT_TYPE
    CMP R0, 4
    JE stream_return
    GET R8, EVENT_DIR
    LSHI R8, 4
    LI R0, CARS
    ADDU R8, R0
    LI R9, 5
    LI R6, 0
stream_find:
    PGET R0, LIVE
    CMP R0, 0
    JE stream_free
    PGET R0, ENTERED
    CMP R0, 0
    JE stream_return
    J stream_find_next
stream_free:
    MOV R6, R8
stream_find_next:
    ADDI R8, 64
    ADDI R9, -1
    CMP R9, 0
    JNE stream_find
    CMP R6, 0
    JE stream_return
    MOV R10, R6
    MOV R1, R6
    LI R2, 16
    LI R0, 0
stream_clear:
    STOR R0, R1
    ADDI R1, 1
    ADDI R2, -1
    CMP R2, 0
    JNE stream_clear
    LI R0, 1
    CSET R0, LIVE
    CSET R0, MOVEMENT
    LI R0, -1024
    CSET R0, PROGRESS
    GET R1, EVENT_DIR
    LSHI R1, 2
    LI R2, STATS
    ADDU R1, R2
    LOAD R2, R1
    ADDI R2, 1
    STOR R2, R1
    ADDI R1, 1
    STOR R0, R1
stream_return:
    RET

emergency_start_roll:
    SETI EVENT_ROLLING, 1
    J emergency_check_turns

; A straight vehicle already in front in the same lane is compatible:
; it keeps moving at normal speed and the larger headway is sufficient.
; A turning car ahead might cross our lane. Until its rear clears, ease
; toward the stop line and don't admit the service into that turn.
; The previous all-red stage already cleared any other approach.
; Preserve R10/R11 (the active service car) for event_passing.
emergency_check_turns:
    SETI EVENT_TURN_BUSY, 0
    CGET R0, ENTERED
    CMP R0, 0
    JNE stream_return
    CGET R6, PROGRESS
    LI R0, 4352
    SUB R6, R0
    GET R8, EVENT_DIR
    LSHI R8, 4
    LI R0, CARS
    ADDU R8, R0
    LI R9, 5
stream_turn_loop:
    PGET R0, LIVE
    CMP R0, 0
    JE stream_turn_next
    PGET R7, MOVEMENT
    CMP R7, STRAIGHT
    JE stream_turn_next
    MOV R0, R7
    LI R1, 4
    CALL metadata
    PGET R3, PROGRESS
    CMP R3, R0
    JGE stream_turn_next
    MOV R0, R7
    LI R1, 0
    CALL metadata
    SUB R3, R0
    CMP R3, R6
    JLE stream_turn_next
    SETI EVENT_TURN_BUSY, 1
    RET
stream_turn_next:
    ADDI R8, 64
    ADDI R9, -1
    CMP R9, 0
    JNE stream_turn_loop
    RET

; Smooth out the approach when a slower turning lead is still clearing.
emergency_approach_pace:
    GET R0, EVENT_TYPE
    CMP R0, 4
    JE stream_return
    GET R0, EVENT_TURN_BUSY
    CMP R0, 0
    JE stream_return
    CGET R0, ENTERED
    CMP R0, 0
    JNE stream_return
    SETI DESIRED, 60
    RET
