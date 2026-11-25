; ---- Keyboard commands ---------------------------------------------
; The PS/2 hardware only queues key numbers. We decide what they mean here.
; S stays south. T is straight, so those two commands cannot fight each other.
handle_command:
    GET R0, COMMAND
    CMP R0, 3
    JNE command_run
    CALL reset_model
    SETI UI_COMMAND, 3
    RET
command_run:
    CMP R0, 1
    JNE command_pause
    SETI RUNNING, 1
    SETI UI_COMMAND, 1
    GET R0, PHASE
    CMP R0, IDLE
    JNE command_return
    SETI PHASE, DEFAULT
    SETI TIMER, 420
    RET
command_pause:
    CMP R0, 2
    JNE command_running
    GET R0, PHASE
    CMP R0, IDLE
    JE command_return
    SETI RUNNING, 0
    SETI UI_COMMAND, 2
    RET
command_running:
    GET R0, RUNNING
    CMP R0, 0
    JE command_return
    GET R0, COMMAND
    CMP R0, 12
    JLT command_escape
    CMP R0, 15
    JGT command_escape
    ADDI R0, -12
    LI R1, 1
command_emergency_bit:
    CMP R0, 0
    JE command_emergency_ready
    LSHI R1, 1
    ADDI R0, -1
    J command_emergency_bit
command_emergency_ready:
    GET R0, EMERGENCY_MASK
    CMP R0, R1
    JE command_release
    SET R1, EMERGENCY_MASK
    GET R0, RESUME_VALID
    CMP R0, 0
    JNE command_emergency_hold
    GET R0, PHASE
    SET R0, SAVED_PHASE
    GET R0, TIMER
    SET R0, SAVED_TIMER
    SETI RESUME_VALID, 1
command_emergency_hold:
    SETI MENU_KIND, 3
    SETI PHASE, EMERGENCY
    SETI TIMER, 0
    RET
command_escape:
    CMP R0, 16
    JNE command_normal
    SETI INPUT_PED, 0
    SETI INPUT_TURN, 0
    SETI PENDING_VALID, 0
    GET R0, EMERGENCY_MASK
    CMP R0, 0
    JE command_return
command_release:
    SETI EMERGENCY_MASK, 0
    SETI PHASE, CLEAR
    SETI TIMER, 48
    RET
command_normal:
    GET R0, EMERGENCY_MASK
    CMP R0, 0
    JNE command_return
    GET R0, COMMAND
    CMP R0, 11
    JNE command_direction
    SETI INPUT_PED, 1
    SETI INPUT_TURN, 0
    SETI MENU_KIND, 2
    SETI DIR_VALID, 0
    SETI TURN_VALID, 0
    RET
command_direction:
    CMP R0, 4
    JLT command_movement
    CMP R0, 7
    JGT command_movement
    ADDI R0, -4
    SET R0, MENU_DIR
    SETI DIR_VALID, 1
    SETI TURN_VALID, 0
    SETI MENU_MOVE, STRAIGHT
    GET R1, INPUT_PED
    LI R2, 1
    CMP R1, 0
    JE command_dir_kind
    LI R2, 2
command_dir_kind:
    SET R2, MENU_KIND
    LI R2, 1
    SUB R2, R1
    SET R2, INPUT_TURN
    GET R2, PHASE
    CMP R2, DEFAULT
    JNE command_queue
    SET R0, REQ_DIR
    SET R1, REQ_PED
    SETI REQ_MOVE, STRAIGHT
    SETI INPUT_PED, 0
    CALL begin_request
    RET
command_queue:
    ; A queued crossing cannot be replaced by a normal car request.
    CMP R1, 0
    JNE command_queue_save
    GET R2, PENDING_VALID
    CMP R2, 0
    JE command_queue_save
    GET R2, PENDING_PED
    CMP R2, 0
    JNE command_return
command_queue_save:
    SET R0, PENDING_DIR
    SET R1, PENDING_PED
    SETI PENDING_MOVE, STRAIGHT
    SETI PENDING_VALID, 1
    SETI INPUT_PED, 0
    RET
command_movement:
    CMP R0, 8
    JLT command_return
    CMP R0, 10
    JGT command_return
    ADDI R0, -8
    SET R0, TEMP
    GET R1, INPUT_TURN
    CMP R1, 0
    JE command_return
    GET R1, PENDING_VALID
    CMP R1, 0
    JE command_active_move
    GET R1, PENDING_PED
    CMP R1, 0
    JNE command_return
    SET R0, PENDING_MOVE
    SET R0, MENU_MOVE
    SETI TURN_VALID, 1
    RET
command_active_move:
    GET R1, HAVE_REQUEST
    CMP R1, 0
    JE command_return
    GET R1, REQ_PED
    CMP R1, 0
    JNE command_return
    GET R1, PHASE
    CMP R1, SELECT
    JE command_edit
    CMP R1, YELLOW
    JNE command_return
    GET R1, AFTER_YELLOW
    CMP R1, SELECT
    JNE command_return
command_edit:
    GET R1, TARGET
    CMP R1, 31
    JE command_edit_vars
    MOV R10, R1
    LSHI R10, 4
    LI R2, CARS
    ADDU R10, R2
    CGET R2, LOCKED
    CMP R2, 0
    JNE command_return
    CSET R0, MOVEMENT
    LI R2, 255
    CSET R2, BLEND_LEFT
command_edit_vars:
    SET R0, REQ_MOVE
    SET R0, MENU_MOVE
    SETI TURN_VALID, 1
command_return:
    RET

; ---- Start a finite user service ------------------------------------
; Pick the closest car that has not locked its approach. Already admitted
; cars keep their route. We do not teleport one onto a different turn.
begin_request:
    SETI HAVE_REQUEST, 1
    SETI TARGET, 31
    SETI TARGET_DONE, 0
    SETI LEFT_WAIT_TIME, 0
    SETI BEST, -32768
    GET R0, REQ_DIR
    SET R0, MENU_DIR
    LSHI R0, -1
    GET R1, NS
    CMP R0, 0
    JE request_green
    GET R1, EW
request_green:
    SETI KEEP_GREEN, 0
    CMP R1, 2
    JNE request_axis
    SETI KEEP_GREEN, 1
request_axis:
    SETI YELLOW_AXIS, 0
    GET R0, EW
    CMP R0, 2
    JNE request_kind
    SETI YELLOW_AXIS, 1
request_kind:
    GET R0, REQ_PED
    LI R1, 1
    SUB R1, R0
    SET R1, FEED_USER
    ADDI R0, 1
    SET R0, MENU_KIND
    SETI DIR_VALID, 1
    GET R0, REQ_MOVE
    SET R0, MENU_MOVE
    SETI TURN_VALID, 0
    CMP R0, STRAIGHT
    JE request_scan_setup
    SETI TURN_VALID, 1
request_scan_setup:
    LI R10, CARS
    LI R11, 0
request_scan:
    LI R0, 0
    CSET R0, BATCH
    CGET R0, LIVE
    CMP R0, 0
    JE request_scan_next
    MOV R0, R11
    ANDI R0, 2
    GET R1, REQ_DIR
    ANDI R1, 2
    CMP R0, R1
    JNE request_scan_next
    LI R0, 1
    CSET R0, BATCH
    CGET R0, ENTERED
    CGET R1, LOCKED
    OR R0, R1
    CMP R0, 0
    JNE request_scan_next
    MOV R0, R11
    ANDI R0, 3
    GET R1, REQ_DIR
    CMP R0, R1
    JNE request_scan_next
    CGET R0, PROGRESS
    GET R1, BEST
    CMP R0, R1
    JLE request_scan_next
    SET R0, BEST
    SET R11, TARGET
request_scan_next:
    ADDI R10, 16
    ADDI R11, 1
    CMP R11, 20
    JLT request_scan
    GET R0, REQ_PED
    CMP R0, 0
    JNE request_phase
    LI R10, CARS
    LI R11, 0
request_routes:
    CGET R0, LIVE
    CMP R0, 0
    JE request_routes_next
    MOV R0, R11
    ANDI R0, 2
    GET R1, REQ_DIR
    ANDI R1, 2
    CMP R0, R1
    JNE request_routes_next
    CGET R0, ENTERED
    CGET R1, LOCKED
    OR R0, R1
    CMP R0, 0
    JNE request_routes_next
    LI R0, STRAIGHT
    GET R1, TARGET
    CMP R11, R1
    JNE request_set_route
    GET R0, REQ_MOVE
request_set_route:
    CGET R1, MOVEMENT
    CMP R0, R1
    JE request_routes_next
    CSET R0, MOVEMENT
    LI R0, 255
    CSET R0, BLEND_LEFT
request_routes_next:
    ADDI R10, 16
    ADDI R11, 1
    CMP R11, 20
    JLT request_routes
request_phase:
    SETI PHASE, SELECT
    SETI TIMER, 120
    GET R0, KEEP_GREEN
    CMP R0, 0
    JNE request_return
    GET R0, NS
    GET R1, EW
    OR R0, R1
    CMP R0, 2
    JNE request_return
    SETI PHASE, YELLOW
    SETI TIMER, 72
    SETI AFTER_YELLOW, SELECT
request_return:
    RET
