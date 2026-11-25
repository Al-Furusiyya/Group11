; ---- Signal output from the current phase ---------------------------
; Zero is red, one is amber, two is green. We never give both axes green.
lights:
    SETI NS, 0
    SETI EW, 0
    SETI LEFT_MASK, 0
    SETI WALK_MASK, 0
    GET R0, PHASE
    CMP R0, DEFAULT
    JE lights_default
    CMP R0, SELECT
    JE lights_select
    CMP R0, USER
    JE lights_axis
    CMP R0, LEFT_WAIT
    JE lights_axis
    CMP R0, WALK
    JE lights_walk
    CMP R0, LEFT_GREEN
    JE lights_left
    CMP R0, YELLOW
    JE lights_yellow
    RET
lights_default:
    GET R0, IDLE_AXIS
    CMP R0, 0
    JE lights_default_ns
    SETI EW, 2
    RET
lights_default_ns:
    SETI NS, 2
    RET
lights_select:
    GET R0, KEEP_GREEN
    CMP R0, 0
    JE lights_return
lights_axis:
    GET R0, REQ_DIR
    ANDI R0, 2
    CMP R0, 0
    JNE lights_ew
    SETI NS, 2
    RET
lights_ew:
    SETI EW, 2
    RET
lights_walk:
    GET R0, REQ_DIR
    CALL direction_bit
    SET R0, WALK_MASK
    J lights_axis
lights_left:
    GET R0, REQ_DIR
    CALL direction_bit
    SET R0, LEFT_MASK
    RET
lights_yellow:
    GET R0, YELLOW_AXIS
    CMP R0, 0
    JE lights_yellow_ns
    SETI EW, 1
    RET
lights_yellow_ns:
    SETI NS, 1
lights_return:
    RET

; ---- One signal step per video frame --------------------------------
signals:
    GET R0, RUNNING
    CMP R0, 0
    JE signals_return
    GET R0, TIMER
    CMP R0, 0
    JE signals_dispatch
    ADDI R0, -1
    SET R0, TIMER
signals_dispatch:
    GET R0, PHASE
    CMP R0, DEFAULT
    JE signals_default
    CMP R0, YELLOW
    JE signals_yellow
    CMP R0, SELECT
    JE signals_select
    CMP R0, USER
    JE signals_user
    CMP R0, LEFT_WAIT
    JE signals_user
    CMP R0, LEFT_GREEN
    JE signals_protected
    CMP R0, WALK
    JE signals_walk
    CMP R0, CLEAR
    JE signals_clear
signals_return:
    RET
signals_default:
    GET R0, TIMER
    CMP R0, 0
    JNE signals_return
    ; Seven seconds of green, then the usual amber and all-red clearance.
    GET R0, IDLE_AXIS
    SET R0, YELLOW_AXIS
    XORI R0, 1
    SET R0, IDLE_AXIS
    SETI PHASE, YELLOW
    SETI TIMER, 72
    SETI AFTER_YELLOW, CLEAR
    RET
signals_yellow:
    GET R0, TIMER
    CMP R0, 0
    JNE signals_return
    GET R0, AFTER_YELLOW
    CMP R0, SELECT
    JNE signals_yellow_clear
    SETI PHASE, SELECT
    SETI TIMER, 120
    RET
signals_yellow_clear:
    SET R0, AFTER_CLEAR
    SETI PHASE, CLEAR
    SETI TIMER, 48
    RET
signals_select:
    GET R0, TIMER
    CMP R0, 0
    JNE signals_return
    GET R0, REQ_PED
    CMP R0, 0
    JNE signals_select_walk
    GET R0, KEEP_GREEN
    CMP R0, 0
    JNE signals_select_user
    GET R0, OCCUPIED
    CMP R0, 0
    JNE signals_return
signals_select_user:
    SETI PHASE, USER
    SETI TIMER, 300
    RET
signals_select_walk:
    GET R0, WALK_BUSY
    CMP R0, 0
    JNE signals_return
    SETI PHASE, WALK
    SETI TIMER, 300
    RET
signals_user:
    GET R11, TARGET
    CMP R11, 31
    JE signals_batch
    MOV R10, R11
    LSHI R10, 4
    LI R0, CARS
    ADDU R10, R0
    CGET R0, LIVE
    CMP R0, 0
    JE signals_batch
    CGET R0, MOVEMENT
    CMP R0, LEFT
    JNE signals_batch
    CGET R0, COMMITTED
    CMP R0, 0
    JNE signals_batch
    CGET R0, ENTERED
    CMP R0, 0
    JE signals_return
    CGET R0, PROGRESS
    LI R1, 6218
    CMP R0, R1
    JLT signals_return
    CGET R0, VELOCITY
    CMP R0, 3
    JGT signals_return
    GET R0, LEFT_WAIT_TIME
    ADDI R0, 1
    SET R0, LEFT_WAIT_TIME
    LI R1, 300
    SUB R1, R0
    SET R1, TIMER
    SETI PHASE, LEFT_WAIT
    CMP R0, 300
    JLT signals_return
    SETI PHASE, YELLOW
    SETI TIMER, 72
    GET R0, REQ_DIR
    LSHI R0, -1
    SET R0, YELLOW_AXIS
    SETI AFTER_YELLOW, LEFT_GREEN
    RET
signals_batch:
    GET R0, PHASE
    CMP R0, LEFT_WAIT
    JNE signals_batch_finish
    SETI PHASE, USER
    SETI TIMER, 300
    RET
signals_batch_finish:
    GET R0, TARGET_DONE
    CMP R0, 0
    JE signals_return
    GET R0, BATCH_DONE
    CMP R0, 0
    JE signals_return
    J signals_end_axis
signals_protected:
    GET R0, TARGET_DONE
    CMP R0, 0
    JE signals_return
    SETI PHASE, USER
    SETI TIMER, 300
    RET
signals_walk:
    GET R0, TIMER
    CMP R0, 0
    JNE signals_return
signals_end_axis:
    SETI PHASE, YELLOW
    SETI TIMER, 72
    GET R0, REQ_DIR
    LSHI R0, -1
    SET R0, YELLOW_AXIS
    SETI AFTER_YELLOW, CLEAR
    RET
signals_clear:
    GET R0, TIMER
    CMP R0, 0
    JNE signals_return
    GET R0, AFTER_CLEAR
    CMP R0, LEFT_GREEN
    JNE signals_clear_all
    GET R0, RESUME_VALID
    CMP R0, 0
    JNE signals_clear_all
    GET R0, OCCUPIED_OTHER
    J signals_clear_check
signals_clear_all:
    GET R0, OCCUPIED
signals_clear_check:
    CMP R0, 0
    JNE signals_return
    GET R0, RESUME_VALID
    CMP R0, 0
    JE signals_clear_left
    SETI RESUME_VALID, 0
    GET R0, SAVED_PHASE
    SET R0, PHASE
    GET R0, SAVED_TIMER
    SET R0, TIMER
    RET
signals_clear_left:
    GET R0, AFTER_CLEAR
    CMP R0, LEFT_GREEN
    JNE signals_pending
    SETI PHASE, USER
    GET R0, TARGET
    CMP R0, 31
    JE signals_left_ready
    MOV R10, R0
    LSHI R10, 4
    LI R0, CARS
    ADDU R10, R0
    CGET R0, COMMITTED
    CMP R0, 0
    JNE signals_left_ready
    SETI PHASE, LEFT_GREEN
signals_left_ready:
    SETI TIMER, 300
    SETI AFTER_CLEAR, IDLE
    RET
signals_pending:
    GET R0, PENDING_VALID
    CMP R0, 0
    JE signals_default_return
    SETI PENDING_VALID, 0
    GET R0, PENDING_DIR
    SET R0, REQ_DIR
    GET R0, PENDING_MOVE
    SET R0, REQ_MOVE
    GET R0, PENDING_PED
    SET R0, REQ_PED
    CALL begin_request
    RET
signals_default_return:
    SETI PHASE, DEFAULT
    SETI TIMER, 420
    SETI HAVE_REQUEST, 0
    SETI TARGET, 31
    SETI TARGET_DONE, 0
    SETI MENU_KIND, 0
    SETI DIR_VALID, 0
    SETI TURN_VALID, 0
    SETI INPUT_TURN, 0
    RET
