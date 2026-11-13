# Protocol v4 / reply v3

Packet bytes: `A5 5A`, version **4**, sequence (0..255), 31-byte display bank,
CRC-8 over version through payload. Total: **36 bytes / 288 bits**. CRC is
polynomial 0x07, initial zero; the standard `123456789` check value is 0xF4.
Python reverses the byte array when forming the Quartus hexadecimal register
value; byte zero shifts first, least-significant bit first.

## 31-byte display bank

| Byte | Meaning |
|---|---|
| 0 | UI control: 0 idle, 1 run, 2 pause, 3 reset |
| 1 | GUI travel direction: 0 NB, 1 SB, 2 EB, 3 WB |
| 2 | Movement: 0 left, 1 straight (physical T), 2 right |
| 3 | Emergency mask bits 3:0; menu kind 5:4; direction-valid 6; turn-valid 7 |
| 4 | Bits 1:0 NB/SB main signal; bits 4:2 bank 0..4; bits 7:5 zero |
| 5 | EB/WB main signal |
| 6 | Bits 3:0 pedestrian mask, bits 7:4 left-green mask; each N,E,S,W high-to-low |
| 7..10 | NB, EB, SB, WB two-digit packed BCD countdowns |
| 11..15 | Sprite slot 0: x little-endian 16, y little-endian 16, attributes |
| 16..20 | Sprite slot 1 |
| 21..25 | Sprite slot 2 |
| 26..30 | Sprite slot 3 |

Sprite attributes bits 1:0: southeast/southwest/northwest/northeast orientation;
bits 3:2 paint (0 mint, 1 coral, 2 gold); bit 4 visible. Slots are independent,
used in NB,SB,EB,WB order within each bank. Banks 0..4 contain the first
through fifth car in each direction. Slot order does not determine orientation.

The remaining attribute bits carry display metadata:

| Byte bits 7:5 | Value | HDL payload bits |
|---|---|---|
| 15 | Phase: 0 ready, 1 flow, 2 choose, 3 wait, 4 left, 5 clear, 6 walk, 7 hold | 127:125 |
| 20 | Phase countdown, 0..5 | 167:165 |
| 25 | Pedestrian progress low three bits | 207:205 |
| 30 | Pedestrian progress high three bits | 247:245 |

Every bank repeats the same UI/timer metadata. The host sends banks 0..4 with
consecutive modulo-256 packet sequence numbers, then starts the next snapshot
at bank 0. Each bank contains four car records, giving twenty cars total.

The CPU still copies exactly 16 words per bank (80 per complete snapshot); the high unused byte of word 15 is zero.
No ISA, instruction-memory-size, or CPU firmware layout change is required.

## 24-byte response

Bytes 0..1: `JG`; byte 2: sequence; byte 3: result; byte 4: key count;
bytes 5..20: up to 16 commands; byte 21: CRC of bytes 0..20; byte 22: version
**3**; byte 23: busy bit 0, valid bit 1, keyboard overflow bit 2, bad scan bit 3, reset-pending bit 4.
Result: 0 success, 1 packet header/version/CRC, 2 range or bank order, **3 physical reset
requires an idle snapshot**. Result 3 is handled by the host, not treated as a
successful display update. Bad scan/overflow requires KEY0. Reset-pending is polled before writes and
during acknowledgement waits; it also recovers a scan truncated by KEY0.
An interrupted short scan while reset-pending is not latched as a bad scan.

The scan counter saturates at 288. Extra physical-chain bypass clocks are
allowed; a short scan or write while busy is still rejected. CRC/header/range
checks remain enabled. The TCK mailbox holds its payload until CPU/frame ACK
crosses back through synchronizers. Data becomes visible only after CPU stores
and a VGA frame-boundary commit of bank 4. Banks 0..3 acknowledge after CPU
staging without waiting for video blanking. Out-of-order banks are rejected
before CPU access; a new bank 0 restarts an abandoned partial snapshot.
KEY0 clears both partial and displayed car banks. An old v3 SOF cannot use
this v4 host: recompile and program the updated RTL before running Python.

PS/2 command codes: 1 Run, 2 Pause, 3 Reset, 4 N, 5 S, 6 E, 7 W, 8 L,
9 T (straight), 10 R, 11 P, 12 A, 13 F, 14 C, 15 B, 16 Esc.
