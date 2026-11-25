; TrafficFlow -- the traffic program that our Lab4 CPU actually runs.
;
; We keep the scene in Verilog. Everything that decides what a car does is
; down here: inputs, signals, yielding, speed, location and crossing timers.
; This is assembly, not a Verilog traffic state machine or a PC relay.
;
; A road distance uses Q6 (64 counts = one road unit). Speed uses Q8 per
; frame, with two leftover bits carried into the next frame. That keeps
; the slow acceleration from getting rounded away on our 16-bit CPU.
;
; R10 is the current car pointer; R11 is its slot. R13 is the call stack.
; R12/R14/R15 belong to assembler helpers. Other registers are scratch.
; GET/SET read/write RAM variables; CGET/CSET use the current car pointer.
; CALL/RET expand to normal Lab4 LOAD/STOR/jump instructions.

; ---- Memory and peripheral addresses ---------------------------------
.equ VARS 0x6000
.equ CARS 0x6100
.equ STATS 0x6300
.equ STACK 0x7F00
.equ ROUTES 0x3000
.equ META_TABLE 0x5500
.equ DIR_BITS 0x5520
.equ CONFLICTS 0x5530
.equ FRAME_LAST 0x6F00
.equ IO_FRAME 0xFF00
.equ IO_KEYS 0xFF01
.equ IO_KEY 0xFF02
.equ IO_COMMIT 0xFF20
.equ IO_DISPLAY 0xFF10
.equ IO_CARS 0xFF40

; ---- Model variables: one word each ----------------------------------
.equ PHASE VARS+0
.equ TIMER VARS+1
.equ RUNNING VARS+2
.equ UI_COMMAND VARS+3
.equ MENU_KIND VARS+4
.equ MENU_DIR VARS+5
.equ MENU_MOVE VARS+6
.equ DIR_VALID VARS+7
.equ TURN_VALID VARS+8
.equ INPUT_PED VARS+9
.equ INPUT_TURN VARS+10
.equ EMERGENCY_MASK VARS+11
.equ HAVE_REQUEST VARS+12
.equ REQ_DIR VARS+13
.equ REQ_MOVE VARS+14
.equ REQ_PED VARS+15
.equ FEED_USER VARS+16
.equ TARGET VARS+17
.equ TARGET_DONE VARS+18
.equ KEEP_GREEN VARS+19
.equ YELLOW_AXIS VARS+20
.equ AFTER_YELLOW VARS+21
.equ AFTER_CLEAR VARS+22
.equ LEFT_WAIT_TIME VARS+23
.equ PENDING_VALID VARS+24
.equ PENDING_DIR VARS+25
.equ PENDING_MOVE VARS+26
.equ PENDING_PED VARS+27
.equ RESUME_VALID VARS+28
.equ SAVED_PHASE VARS+29
.equ SAVED_TIMER VARS+30
.equ NEXT_PAINT VARS+31
.equ NS VARS+32
.equ EW VARS+33
.equ LEFT_MASK VARS+34
.equ WALK_MASK VARS+35
.equ OCCUPIED VARS+36
.equ OCCUPIED_OTHER VARS+37
.equ WALK_BUSY VARS+38
.equ BATCH_DONE VARS+39
.equ COMMAND VARS+40
.equ BEST VARS+41
.equ DIRECTION VARS+42
.equ ROUTE VARS+43
.equ META_PTR VARS+44
.equ AT VARS+45
.equ LIMIT VARS+46
.equ DESIRED VARS+47
.equ ALLOWED VARS+48
.equ PEER VARS+49
.equ GAP_OK VARS+50
.equ ENTRY VARS+51
.equ NOTICE VARS+52
.equ HOLD VARS+53
.equ TURN_END VARS+54
.equ CLEAR_AT VARS+55
.equ TOTAL VARS+56
.equ SECONDS VARS+57
.equ PED_PROGRESS VARS+58
.equ POSE_X VARS+59
.equ POSE_Y VARS+60
.equ TEMP VARS+61
.equ ALL_DONE VARS+62
; Extra words for priority events. Normal car records do not change.
.equ IDLE_AXIS VARS+63
.equ EVENT_STAGE VARS+64
.equ EVENT_TYPE VARS+65
.equ EVENT_DIR VARS+66
.equ EVENT_SLOT VARS+67
.equ EVENT_WAIT VARS+68
.equ EVENT_PENDING VARS+69
.equ EVENT_PENDING_DIR VARS+70
.equ BUS_PENDING VARS+71
.equ BUS_DIR VARS+72
.equ EVENT_SELECT VARS+73
.equ FAULT VARS+74
.equ EVENT_SAVED_PHASE VARS+75
.equ EVENT_SAVED_TIMER VARS+76
.equ EVENT_FREE VARS+77
.equ EVENT_BEST VARS+78
.equ BUS_PICKUP VARS+79
.equ BUS_STOP VARS+80
.equ BUS_TICKS VARS+81
.equ LEFT_PERMISSIVE VARS+82
.equ LEFT_GO VARS+83
.equ BUS_BOARDED VARS+84
.equ EVENT_ROLLING VARS+85
.equ EVENT_TURN_BUSY VARS+86
.equ ROUTE_EXTENSION 4096
.equ SERVICE_FIRST 20
.equ ALL_SLOTS 24

; ---- Car record: twenty slots, sixteen words per slot ----------------
.equ LIVE 0
.equ ENTERED 1
.equ COMMITTED 2
.equ LOCKED 3
.equ BATCH 4
.equ MOVEMENT 5
.equ PAINT 6
.equ PROGRESS 7
.equ VELOCITY 8
.equ X 9
.equ Y 10
.equ ART 11
.equ BLEND_X 12
.equ BLEND_Y 13
.equ BLEND_LEFT 14
.equ FRACTION 15
; A direction's STATS record is count, tail, alternation, then one spare.

; ---- Signal phases and route metadata offsets -----------------------
.equ IDLE 0
.equ DEFAULT 1
.equ SELECT 2
.equ USER 3
.equ LEFT_WAIT 4
.equ LEFT_GREEN 5
.equ YELLOW 6
.equ CLEAR 7
.equ WALK 8
.equ EMERGENCY 9
.equ LEFT 0
.equ STRAIGHT 1
.equ RIGHT 2

.include main.asm
.include inputs.asm
.include signals.asm
.include motion.asm
.include display.asm
.include priority.asm
.include emergency_stream.asm
.include school_bus.asm
.include left_display.asm
