from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Python'))
from protocol import DisplayState,Car,encode_frame,crc8

def fixtures():
    a=DisplayState(ui_command=1,direction=2,movement=2,menu_kind=1,direction_valid=True,turn_valid=True,light_ew=2)
    a.cars=[Car(180+i*17,100+i*13,i%4,i%3) for i in range(20)]
    b=DisplayState(ui_command=2,direction=1,movement=1,menu_kind=2,direction_valid=True,ped_walk=2,seconds=[21,22,23,24],light_ns=1)
    b.cars=[Car(190+i*17,110+i*13,(i+1)%4,(i+1)%3,i%2==0) for i in range(20)]
    bad_crc=bytearray(encode_frame(a,8));bad_crc[-1]^=1
    bad_range=bytearray(encode_frame(a,9));bad_range[15:17]=(700).to_bytes(2,'little');bad_range[-1]=crc8(bad_range[2:-1])
    frames=[encode_frame(a,7),bad_crc,bad_range,encode_frame(b,10),encode_frame(a,11),encode_frame(DisplayState(),6),encode_frame(a,12,2)]
    (ROOT/'sim/frames.hex').write_text('\n'.join(bytes(v)[::-1].hex() for v in frames)+'\n')
    (ROOT/'sim/expected.hex').write_text('\n'.join(v.payload(4)[::-1].hex() for v in [a,b])+'\n')
    banks=[encode_frame(state,32+group*5+bank,bank) for group,state in enumerate([DisplayState(),a,b]) for bank in range(5)]
    (ROOT/'sim/banks.hex').write_text('\n'.join(p[::-1].hex() for p in banks)+'\n')
    (ROOT/'sim/expected_cars.hex').write_text('\n'.join(b''.join(state.payload(bank)[11:] for bank in range(5))[::-1].hex() for state in [a,b])+'\n')
    return a,b
if __name__=='__main__':fixtures()
