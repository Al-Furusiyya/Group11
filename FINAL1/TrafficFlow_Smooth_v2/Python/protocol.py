"""Protocol v4: five 31-byte banks, carried through the original Lab4 CPU.

Byte 6 high nibble is N/E/S/W left-green; low nibble is pedestrian walk.
Car attribute high bits carry phase, countdown, and crossing animation.
The sprite attributes remain in bits 4:0. See PROTOCOL.md for exact offsets.
"""
from dataclasses import dataclass, field
import struct

PAYLOAD_SIZE=31
CAR_COUNT=20
BANK_COUNT=5

def crc8(data):
    crc=0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc=((crc<<1)^0x07)&255 if crc&128 else (crc<<1)&255
    return crc

def bcd(value):
    if not isinstance(value,int) or not 0<=value<=99: raise ValueError('seconds must be integers 0..99')
    return (value//10)*16+value%10

@dataclass
class Car:
    x:int
    y:int
    direction:int=0
    paint:int=0
    visible:bool=True
    def pack(self):
        if not(0<=self.x<=639 and 0<=self.y<=479 and 0<=self.direction<=3 and 0<=self.paint<=2):
            raise ValueError('car outside 640x480 grid or invalid direction/paint')
        return struct.pack('<HHB',self.x,self.y,self.direction|(self.paint<<2)|(int(self.visible)<<4))

def default_cars():
    return [Car(0,0,visible=False) for _ in range(CAR_COUNT)]

@dataclass
class DisplayState:
    menu_kind:int=0
    direction_valid:bool=False
    turn_valid:bool=False
    ui_command:int=0
    direction:int=0
    movement:int=1
    emergency:int=0
    light_ns:int=0
    light_ew:int=0
    ped_walk:int=0
    left_green:int=0
    phase:int=0
    phase_seconds:int=0
    ped_progress:int=0
    seconds:list=field(default_factory=lambda:[0,0,0,0]) # N E S W
    cars:list=field(default_factory=default_cars)
    def payload(self, bank=0):
        if not isinstance(bank,int) or not 0<=bank<BANK_COUNT:raise ValueError('bank must be 0..4')
        if not(0<=self.ui_command<=3 and 0<=self.direction<=3 and 0<=self.movement<=2 and
               0<=self.emergency<=15 and 0<=self.menu_kind<=3 and 0<=self.light_ns<=2 and 0<=self.light_ew<=2 and 0<=self.ped_walk<=15 and
               0<=self.left_green<=15 and 0<=self.phase<=7 and 0<=self.phase_seconds<=5 and 0<=self.ped_progress<=63):
            raise ValueError('invalid display state')
        if len(self.seconds)!=4 or len(self.cars)!=CAR_COUNT:raise ValueError('exactly 4 counters and 20 car slots are required')
        attributes=(self.phase,self.phase_seconds,self.ped_progress&7,self.ped_progress>>3)
        packed=[]
        for car,extra in zip(self.cars[bank*4:bank*4+4],attributes):
            raw=bytearray(car.pack());raw[4] |= extra<<5;packed.append(bytes(raw))
        return bytes([self.ui_command,self.direction,self.movement,(self.emergency | (self.menu_kind<<4) | (int(self.direction_valid)<<6) | (int(self.turn_valid)<<7)),self.light_ns|(bank<<2),self.light_ew,self.ped_walk|(self.left_green<<4),
                      *map(bcd,self.seconds)])+b''.join(packed)

def encode_frame(state,sequence,bank=0):
    body=bytes([4,sequence&255])+state.payload(bank)
    return b'\xA5\x5A'+body+bytes([crc8(body)])
