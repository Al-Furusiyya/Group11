; ---- Boot and main loop ---------------------------------------------
boot:
    LI R13, STACK
    CALL reset_model
    SETI FRAME_LAST, 0xFFFF
main_poll:
    LI R1, IO_KEYS
    LOAD R0, R1
    CMP R0, 0
    JE poll_frame
    LI R1, IO_KEY
    LOAD R0, R1
    SET R0, COMMAND
    CALL priority_command
    J main_poll
poll_frame:
    LI R1, IO_FRAME
    LOAD R0, R1
    GET R1, FRAME_LAST
    CMP R0, R1
    JE main_poll
    SET R0, FRAME_LAST
    CALL lights
    CALL priority_lights
    CALL summary
    CALL priority_step
    CALL lights
    CALL priority_lights
    CALL move_cars
    CALL draw_positions
    CALL publish
    J main_poll

; Clear our model RAM in software, including cars left from an earlier run.
; The CPU and display hardware have their own reset through KEY0.
reset_model:
    LI R1, VARS
    LI R2, 0x6380
    LI R0, 0
reset_clear:
    STOR R0, R1
    ADDI R1, 1
    CMP R1, R2
    JLT reset_clear
    SETI MENU_MOVE, STRAIGHT
    SETI REQ_MOVE, STRAIGHT
    SETI PENDING_MOVE, STRAIGHT
    SETI TARGET, 31
    SETI YELLOW_AXIS, 1
    SETI AFTER_YELLOW, SELECT
    SETI IDLE_AXIS, 1
    SETI EVENT_SLOT, 31
    LI R10, CARS
    LI R11, 0
reset_cars:
    LI R0, STRAIGHT
    CSET R0, MOVEMENT
    ADDI R10, 16
    ADDI R11, 1
    CMP R11, ALL_SLOTS
    JLT reset_cars
    RET

; R0 = movement, R1 = field (entry, notice, hold, turn-end, clear, total).
; A table saves both program space and repeated geometry calculations.
metadata:
    LI R2, 6
    MUL R0, R2
    ADDU R0, R1
    LI R2, META_TABLE
    ADDU R0, R2
    LOAD R0, R0
    RET

; R0 = direction; result is the scene's N/E/S/W mask order.
direction_bit:
    LI R1, DIR_BITS
    ADDU R0, R1
    LOAD R0, R0
    RET

; Set up metadata for the current car. R10/R11 remain the current slot.
current_route:
    MOV R0, R11
    ANDI R0, 3
    SET R0, DIRECTION
    XORI R0, 1
    SET R0, PEER
    CGET R0, MOVEMENT
    LI R1, 6
    MUL R0, R1
    LI R1, META_TABLE
    ADDU R0, R1
    SET R0, META_PTR
    MOV R1, R0
    LI R2, ENTRY
    LI R3, 6
route_copy:
    LOAD R0, R1
    STOR R0, R2
    ADDI R1, 1
    ADDI R2, 1
    ADDI R3, -1
    CMP R3, 0
    JNE route_copy
    ; The larger service body needs more room before its rear is clear.
    CMP R11, SERVICE_FIRST
    JLT route_normal_clear
    GET R0, CLEAR_AT
    LI R1, 384
    ADDU R0, R1
    SET R0, CLEAR_AT
route_normal_clear:
    GET R0, DIRECTION
    LI R1, 3
    MUL R0, R1
    CGET R1, MOVEMENT
    ADDU R0, R1
    SET R0, ROUTE
    RET

; Count cars and remember the back of each queue. An admitted car owns its
; crossing space until its rear clears, even if its light changes to red.
summary:
    SETI OCCUPIED, 0
    SETI OCCUPIED_OTHER, 0
    SETI WALK_BUSY, 0
    SETI BATCH_DONE, 1
    LI R1, STATS
    LI R2, 4
    LI R0, 0
summary_clear:
    STOR R0, R1
    ADDI R1, 1
    STOR R0, R1
    ADDI R1, 3
    ADDI R2, -1
    CMP R2, 0
    JNE summary_clear
    LI R10, CARS
    LI R11, 0
summary_car:
    CGET R0, LIVE
    CMP R0, 0
    JE summary_next
    CALL current_route
    GET R0, DIRECTION
    LSHI R0, 2
    LI R1, STATS
    ADDU R1, R0
    CMP R11, SERVICE_FIRST
    JGE summary_tail_address
    LOAD R0, R1
    ADDI R0, 1
    STOR R0, R1
summary_tail_address:
    ADDI R1, 1
    LOAD R0, R1
    CGET R2, PROGRESS
    CMP R2, R0
    JGE summary_tail_done
    STOR R2, R1
summary_tail_done:
    CGET R0, ENTERED
    CMP R0, 0
    JE summary_batch
    GET R0, CLEAR_AT
    CMP R2, R0
    JGE summary_batch
    SETI OCCUPIED, 1
    GET R0, TARGET
    CMP R11, R0
    JNE summary_other
    CGET R0, MOVEMENT
    CMP R0, LEFT
    JNE summary_other
    CGET R0, COMMITTED
    CMP R0, 0
    JE summary_walk
summary_other:
    SETI OCCUPIED_OTHER, 1
summary_walk:
    GET R0, ROUTE
    LI R1, CONFLICTS
    ADDU R0, R1
    LOAD R0, R0
    GET R1, REQ_DIR
    LI R2, 1
summary_mask:
    CMP R1, 0
    JE summary_mask_done
    LSHI R2, 1
    ADDI R1, -1
    J summary_mask
summary_mask_done:
    AND R0, R2
    CMP R0, 0
    JE summary_batch
    SETI WALK_BUSY, 1
summary_batch:
    CGET R0, BATCH
    CMP R0, 0
    JE summary_next
    CGET R0, ENTERED
    CMP R0, 0
    JE summary_batch_busy
    CGET R0, PROGRESS
    GET R1, CLEAR_AT
    CMP R0, R1
    JGE summary_next
summary_batch_busy:
    SETI BATCH_DONE, 0
summary_next:
    ADDI R10, 16
    ADDI R11, 1
    CMP R11, ALL_SLOTS
    JLT summary_car
    RET
