; ---- Left-arrow display ---------------------------------------------
; Use the same road and pedestrian permissions as motion.asm. Amber means
; a left turn can approach and yield. Green means the protected phase or a
; committed left car is taking its turn. Red means no new left entry.
; These are indicators only; they never change ALLOWED or COMMITTED.
left_display:
    SETI LEFT_PERMISSIVE, 0
    GET R0, LEFT_MASK
    SET R0, LEFT_GO
    LI R11, 0
left_display_dir:
    MOV R0, R11
    ANDI R0, 2
    CMP R0, 0
    JE left_display_ns
    GET R0, EW
    J left_display_green
left_display_ns:
    GET R0, NS
left_display_green:
    CMP R0, 2
    JNE left_display_next
    GET R0, HAVE_REQUEST
    GET R1, REQ_PED
    AND R0, R1
    CMP R0, 0
    JE left_display_allow
    GET R0, PHASE
    CMP R0, SELECT
    JE left_display_conflict
    CMP R0, WALK
    JNE left_display_allow
left_display_conflict:
    ; Left route is direction*3 + 0. Same conflict table as motion.asm.
    MOV R0, R11
    LI R1, 3
    MUL R0, R1
    LI R1, CONFLICTS
    ADDU R0, R1
    LOAD R0, R0
    GET R1, REQ_DIR
    LI R2, 1
left_display_bit:
    CMP R1, 0
    JE left_display_bit_ready
    LSHI R2, 1
    ADDI R1, -1
    J left_display_bit
left_display_bit_ready:
    AND R0, R2
    CMP R0, 0
    JNE left_display_next
left_display_allow:
    MOV R0, R11
    CALL direction_bit
    GET R1, LEFT_PERMISSIVE
    OR R0, R1
    SET R0, LEFT_PERMISSIVE
left_display_next:
    ADDI R11, 1
    CMP R11, 4
    JLT left_display_dir
    ; A service has its own approach green while cars ahead of it clear.
    ; Reflect that same permission on the approach's left arrow.
    GET R0, FAULT
    CMP R0, 0
    JNE left_display_scan
    GET R0, EVENT_STAGE
    CMP R0, 2
    JNE left_display_scan
    GET R0, BUS_PICKUP
    CMP R0, 2
    JE left_display_scan
    CMP R0, 3
    JE left_display_scan
    GET R10, EVENT_SLOT
    LSHI R10, 4
    LI R0, CARS
    ADDU R10, R0
    CGET R0, ENTERED
    CMP R0, 0
    JE left_display_priority_allow
    GET R0, EVENT_TYPE
    CMP R0, 4
    JE left_display_scan
    CGET R0, PROGRESS
    LI R1, 9600
    CMP R0, R1
    JLT left_display_scan
left_display_priority_allow:
    GET R0, EVENT_DIR
    CALL direction_bit
    SET R0, LEFT_PERMISSIVE

    ; A committed car inside the crossing gets green on its own arrow.
    ; If the normal axis or pedestrian permission is red, keep it red.
left_display_scan:
    LI R0, LEFT
    LI R1, 4
    CALL metadata
    MOV R6, R0
    LI R10, CARS
    LI R11, 0
left_display_car:
    CGET R0, LIVE
    CMP R0, 0
    JE left_display_car_next
    CGET R0, MOVEMENT
    CMP R0, LEFT
    JNE left_display_car_next
    CGET R0, ENTERED
    CMP R0, 0
    JE left_display_car_next
    CGET R0, COMMITTED
    CMP R0, 0
    JE left_display_car_next
    CGET R0, PROGRESS
    CMP R0, R6
    JGE left_display_car_next
    MOV R0, R11
    ANDI R0, 3
    CALL direction_bit
    GET R1, LEFT_PERMISSIVE
    AND R0, R1
    GET R1, LEFT_GO
    OR R0, R1
    SET R0, LEFT_GO
left_display_car_next:
    ADDI R10, 16
    ADDI R11, 1
    CMP R11, ALL_SLOTS
    JLT left_display_car
    GET R0, LEFT_GO
    LSHI R0, 4
    GET R1, LEFT_PERMISSIVE
    OR R0, R1
    LI R1, IO_DISPLAY+13
    STOR R0, R1
    RET
