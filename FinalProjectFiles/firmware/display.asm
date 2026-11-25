; ---- Turn road progress into screen positions -----------------------
; The route table only contains constant points. The CPU picks the point,
; interpolates between samples, and does the isometric projection itself.
draw_positions:
    GET R0, RUNNING
    CMP R0, 0
    JE positions_return
    LI R10, CARS
    LI R11, 0
positions_car:
    ; The table is unchanged. Extend its first/last straight segment instead
    ; of stopping the sprite at the old, in-screen route endpoints.
    CGET R0, MOVEMENT
    LI R1, 5
    CALL metadata
    ADDI R0, 63
    LSHI R0, -6
    LSHI R0, 6
    MOV R6, R0
    MOV R0, R11
    ANDI R0, 3
    LI R1, 3
    MUL R0, R1
    CGET R1, MOVEMENT
    ADDU R0, R1
    LSHI R0, 8
    CGET R1, PROGRESS
    CMP R1, 0
    JGE positions_nonnegative
    MOV R6, R1
    LI R1, 0
    J positions_sample
positions_nonnegative:
    CMP R1, R6
    JLE positions_inside
    MOV R2, R1
    SUB R2, R6
    MOV R1, R6
    MOV R6, R2
    J positions_sample
positions_inside:
    LI R6, 0
positions_sample:
    MOV R2, R1
    ANDI R2, 63
    LSHI R1, -6
    ADDU R0, R1
    LI R1, 3
    MUL R0, R1
    LI R7, ROUTES
    ADDU R7, R0
    LOAD R3, R7
    ADDI R7, 1
    LOAD R4, R7
    ADDI R7, 1
    LOAD R5, R7
    CSET R5, ART
    ADDI R7, 1
    LOAD R0, R7
    ADDI R7, 1
    LOAD R1, R7
    SUB R0, R3
    MUL R0, R2
    ASHI R0, -6
    ADDU R0, R3
    SUB R1, R4
    MUL R1, R2
    ASHI R1, -6
    ADDU R1, R4
    MOV R3, R0
    SUB R3, R1
    LSHI R3, 1
    LI R4, 6336
    ADDU R3, R4
    LI R4, 4096
    SUB R4, R0
    SUB R4, R1
    ; ART = SB, WB, NB, EB. Continue along its 2:1 screen diagonal.
    ASHI R6, -2
    MOV R0, R6
    LSHI R0, 1
    CMP R5, 0
    JE extension_right
    CMP R5, 3
    JE extension_right
    SUB R3, R0
    J extension_y
extension_right:
    ADDU R3, R0
extension_y:
    CMP R5, 0
    JE extension_down
    CMP R5, 1
    JE extension_down
    SUB R4, R6
    J extension_done
extension_down:
    ADDU R4, R6
extension_done:
    CGET R5, BLEND_LEFT
    CMP R5, 255
    JNE positions_blend
    CGET R0, X
    LSHI R0, 4
    SUB R0, R3
    CSET R0, BLEND_X
    CGET R0, Y
    LSHI R0, 4
    SUB R0, R4
    CSET R0, BLEND_Y
    LI R5, 32
positions_blend:
    CMP R5, 0
    JE positions_round
    CGET R0, BLEND_X
    MUL R0, R5
    ASHI R0, -5
    ADDU R3, R0
    CGET R0, BLEND_Y
    MUL R0, R5
    ASHI R0, -5
    ADDU R4, R0
    ADDI R5, -1
positions_round:
    CSET R5, BLEND_LEFT
    ADDI R3, 8
    ADDI R4, 8
    ASHI R3, -4
    ASHI R4, -4
    ; Negative X is wholly hidden behind the left menu. Keep the hardware
    ; coordinates unsigned, and clamp remote queues outside the viewport.
    CMP R3, 0
    JGE positions_x_max
    LI R3, 0
positions_x_max:
    CMP R3, 1023
    JLE positions_y_min
    LI R3, 1023
positions_y_min:
    CMP R4, 0
    JGE positions_y_max
    LI R4, 0
positions_y_max:
    CMP R4, 1023
    JLE positions_clamped
    LI R4, 1023
positions_clamped:
    CSET R3, X
    CSET R4, Y
    ADDI R10, 16
    ADDI R11, 1
    CMP R11, ALL_SLOTS
    JLT positions_car
positions_return:
    RET

; ---- Pack a complete VGA frame --------------------------------------
; We write a back buffer first. COMMIT makes it visible together at blanking.
; The hardware does not decide which light, car, or pedestrian should move.
publish:
    LI R1, IO_DISPLAY
    LI R2, 16
    LI R0, 0
publish_clear_ui:
    STOR R0, R1
    ADDI R1, 1
    ADDI R2, -1
    CMP R2, 0
    JNE publish_clear_ui
    GET R0, TIMER
    LI R1, 0
publish_seconds:
    CMP R0, 0
    JLE publish_seconds_ready
    ADDI R1, 1
    ADDI R0, -60
    J publish_seconds
publish_seconds_ready:
    SET R1, SECONDS
    GET R0, MENU_DIR
    LSHI R0, 8
    GET R1, UI_COMMAND
    OR R0, R1
    LI R1, IO_DISPLAY
    STOR R0, R1
    GET R0, TURN_VALID
    LSHI R0, 1
    GET R1, DIR_VALID
    OR R0, R1
    LSHI R0, 2
    GET R1, MENU_KIND
    OR R0, R1
    LSHI R0, 4
    GET R1, EMERGENCY_MASK
    OR R0, R1
    LSHI R0, 8
    GET R1, MENU_MOVE
    OR R0, R1
    LI R1, IO_DISPLAY+1
    STOR R0, R1
    GET R0, EW
    LSHI R0, 8
    GET R1, NS
    OR R0, R1
    LI R1, IO_DISPLAY+2
    STOR R0, R1

    GET R3, SECONDS
    MOV R4, R3
    MOV R5, R3
    MOV R6, R3
    GET R0, PHASE
    CMP R0, WALK
    JNE publish_counts
    GET R0, WALK_MASK
    MOV R1, R0
    ANDI R1, 8
    CMP R1, 0
    JNE publish_count_e
    LI R3, 0
publish_count_e:
    MOV R1, R0
    ANDI R1, 4
    CMP R1, 0
    JNE publish_count_s
    LI R4, 0
publish_count_s:
    MOV R1, R0
    ANDI R1, 2
    CMP R1, 0
    JNE publish_count_w
    LI R5, 0
publish_count_w:
    ANDI R0, 1
    CMP R0, 0
    JNE publish_counts
    LI R6, 0
publish_counts:
    GET R0, LEFT_MASK
    LSHI R0, 4
    GET R1, WALK_MASK
    OR R0, R1
    LSHI R3, 8
    OR R0, R3
    LI R1, IO_DISPLAY+3
    STOR R0, R1
    LSHI R5, 8
    OR R4, R5
    LI R1, IO_DISPLAY+4
    STOR R4, R1
    LI R1, IO_DISPLAY+5
    STOR R6, R1
    CALL priority_display
    CALL school_bus_display
    CALL left_display

    GET R1, PHASE
    LI R0, 0
    CMP R1, DEFAULT
    JE publish_phase_one
    CMP R1, USER
    JE publish_phase_one
    LI R0, 2
    CMP R1, SELECT
    JE publish_phase
    LI R0, 3
    CMP R1, LEFT_WAIT
    JE publish_phase
    LI R0, 4
    CMP R1, LEFT_GREEN
    JE publish_phase
    LI R0, 5
    CMP R1, YELLOW
    JE publish_phase
    CMP R1, CLEAR
    JE publish_phase
    LI R0, 6
    CMP R1, WALK
    JE publish_phase
    LI R0, 7
    CMP R1, EMERGENCY
    JE publish_phase
    LI R0, 0
    J publish_phase
publish_phase_one:
    LI R0, 1
publish_phase:
    LSHI R0, 13
    LI R1, IO_DISPLAY+7
    STOR R0, R1
    GET R0, SECONDS
    LSHI R0, 5
    LI R1, IO_DISPLAY+10
    STOR R0, R1
    LI R0, 0
    GET R1, PHASE
    CMP R1, WALK
    JNE publish_ped_progress
    LI R0, 300
    GET R1, TIMER
    SUB R0, R1
    LI R1, 27
    MUL R0, R1
    LSHI R0, -7
publish_ped_progress:
    SET R0, PED_PROGRESS
    MOV R2, R0
    ANDI R0, 7
    LSHI R0, 13
    LI R1, IO_DISPLAY+12
    STOR R0, R1
    LSHI R2, -3
    LSHI R2, 5
    LI R1, IO_DISPLAY+15
    STOR R2, R1

    LI R10, CARS
    LI R11, 0
    LI R7, IO_CARS
publish_car:
    CGET R0, X
    STOR R0, R7
    ADDI R7, 1
    CGET R0, Y
    STOR R0, R7
    ADDI R7, 1
    CGET R0, PAINT
    LSHI R0, 2
    CGET R1, ART
    OR R0, R1
    CGET R1, LIVE
    CMP R1, 0
    JE publish_car_attribute
    ORI R0, 16
publish_car_attribute:
    STOR R0, R7
    ADDI R7, 1
    ADDI R10, 16
    ADDI R11, 1
    CMP R11, ALL_SLOTS
    JLT publish_car
    LI R1, IO_COMMIT
    LI R0, 1
    STOR R0, R1
wait_commit:
    LOAD R0, R1
    CMP R0, 0
    JNE wait_commit
    RET
