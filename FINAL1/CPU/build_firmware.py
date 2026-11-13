"""Small assembler for this relay firmware, using the uploaded Lab4 ISA.
No CPU instruction encodings are changed. Run from any folder with Python.
"""
from pathlib import Path
code=[];labels={};fixups=[];listing=[]
def emit(word,text):
    listing.append((len(code),text));code.append(word)
def label(name):labels[name]=len(code)
def movi(r,n):emit(0xd000|(r<<8)|(n&255),f'MOVI R{r}, {n&255:#04x}')
def lui(r,n):emit(0xf000|(r<<8)|(n&255),f'LUI R{r}, {n&255:#04x}')
def ori(r,n):emit(0x2000|(r<<8)|(n&255),f'ORI R{r}, {n&255:#04x}')
def load(r,a):emit(0x4000|(r<<8)|a,f'LOAD R{r}, [R{a}]')
def store(r,a):emit(0x4040|(r<<8)|a,f'STOR R{r}, [R{a}]')
def addi(r,n):emit(0x6000|(r<<8)|(n&255),f'ADDUI R{r}, {n}')
def cmpi(r,n):emit(0xb000|(r<<8)|(n&255),f'CMPI R{r}, {n}')
def branch(cond,target):
    fixups.append((len(code),cond,target));emit(0,f'B{ {0:"EQ",1:"NE",14:"UC"}[cond]} {target}')
for r,address in [(8,0x3e0),(9,0x3e1),(10,0x3e2),(11,0x3e3),(12,0x3e4),(13,0x3e5)]:
    lui(r,address>>8);ori(r,address&255)
movi(14,1)
label('poll')
load(0,11);cmpi(0,0);branch(0,'poll_packet')
load(0,12);store(0,13)
label('poll_packet')
load(0,8);cmpi(0,0);branch(0,'poll')
lui(1,3);ori(1,0xc0);lui(2,3);ori(2,0xd0);movi(3,16)
label('copy')
load(0,1);store(0,2);addi(1,1);addi(2,1);addi(3,-1);cmpi(3,0);branch(1,'copy')
store(14,10)
label('wait_frame')
load(0,9);cmpi(0,0);branch(1,'wait_frame');branch(14,'poll')
for pc,cond,target in fixups:
    offset=labels[target]-(pc+1)
    if not -128<=offset<=127:raise ValueError('branch outside signed 8-bit range')
    code[pc]=0xc000|(cond<<8)|(offset&255)
root=Path(__file__).resolve().parent
# Initialize the full BRAM for deterministic simulation and synthesis.
(root/'traffic_firmware.hex').write_text('\n'.join(f'{word:04X}' for word in code+[0]*(1024-len(code)))+'\n')
lines=['; Lab4 CPU relay. CPU addresses are WORD addresses.','; Input 0x3C0..3CF -> display staging 0x3D0..3DF.','; PS/2 events also pass through the CPU.']
for pc,text in listing:
    for name,position in labels.items():
        if position==pc:lines.append(name+':')
    lines.append(f'{pc:03X}: {code[pc]:04X}    {text}')
(root/'traffic_firmware.lst').write_text('\n'.join(lines)+'\n')
print(f'Built {len(code)} Lab4 instructions; RAM words 0x3C0..0x3FF reserved for I/O.')
