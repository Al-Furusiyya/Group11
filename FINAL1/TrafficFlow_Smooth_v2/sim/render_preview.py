"""Software reference images for visual review, NOT a capture of FPGA output.
Requires optional Pillow and NumPy. Uses the HDL font/sprite ROM and Python
controller. Real-pixel HDL capture is provided separately by tb_vga_capture.v.
"""
from pathlib import Path
import re
import sys
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Python'))
from control import Controller, Phase, STEP
HDL=(ROOT/'vga_scene.v').read_text()
PALETTE=['000000','292B30','DCE0D8','8C9494','E4C94C','F06C68','482728','40D8A0',
         '18382C','4C4420','38D0BC','208C80','B34C50','A48C30','C0E0E0','ECF0E4']
COLORS=[tuple(bytes.fromhex(c)) for c in PALETTE]
FONT={int(k,16):int(v,16) for k,v in re.findall(r"8'h([0-9A-F]+): glyph = 35'h([0-9A-F]+)",HDL)}
ROM={int(k):int(v,16) for k,v in re.findall(r"7'd(\d+): car_row = 96'h([0-9A-F]+)",HDL)}


def render(s):
    yy,xx=np.indices((480,640));u=2*(yy-256)-(xx-396);v=2*(yy-256)+(xx-396)
    au,av=np.abs(u),np.abs(v);a=np.zeros((480,640),dtype=np.uint8)
    road=xx>153
    def ink(mask,color):a[mask&road]=color
    ink((au<=63)|(av<=63),2);ink((au<=60)|(av<=60),1)
    ink(((au>=1)&(au<=2)&(av>=114))|((av>=1)&(av<=2)&(au>=114)),4)
    ink((((au>=29)&(au<=31)&(av>=114))|((av>=29)&(av<=31)&(au>=114)))&((xx&15)<8),2)
    ink(((au<=56)&(av>=84)&(av<=100)&(((u+56)&15)<8))|
        ((av<=56)&(au>=84)&(au<=100)&(((v+56)&15)<8)),2)
    ink(((u>=4)&(u<=57)&(v>=-110)&(v<=-107))|
        ((u>=-57)&(u<=-4)&(v>=107)&(v<=110))|
        ((v>=-57)&(v<=-4)&(u>=-110)&(u<=-107))|
        ((v>=4)&(v<=57)&(u>=107)&(u<=110)),2)
    def arrow(f,r,left):
        ar=np.abs(r);bend=np.abs(f-2)
        if left:return ((ar<=1)&(f>=-16)&(f<=3))|((f>=1)&(f<=3)&(r>=-10)&(r<=0))|((r>=-10)&(r<=-4)&(bend<=r+10))
        return ((ar<=1)&(f>=-16)&(f<=15))|((f>=9)&(f<=17)&(ar<=17-f))|((f>=1)&(f<=3)&(r>=0)&(r<=10))|((r>=4)&(r<=10)&(bend<=10-r))
    for f,r in [(v+132,u),(132-v,-u),(u+132,-v),(132-u,v)]:
        ink(arrow(f,r-15,True)|arrow(f,r-45,False),2)
    im=Image.fromarray(np.array(COLORS,dtype=np.uint8)[a]);draw=ImageDraw.Draw(im)
    def box(x,y,w,h,c,scale=1):draw.rectangle((x*scale,y*scale,(x+w)*scale-1,(y+h)*scale-1),fill=COLORS[c])
    def text(x,y,message,c=2,scale=2):
        for i,char in enumerate(message):
            bits=FONT.get(ord(char),0)
            for row in range(7):
                for col in range(5):
                    if bits&(1<<(34-row*5-col)):box(x+i*6+col,y+row,1,1,c,scale)
    def focus(x,y,w,h,c=10):
        box(x+1,y,w-2,1,c,2);box(x+1,y+h-1,w-2,1,c,2)
        box(x,y+1,1,h-2,c,2);box(x+w-1,y+1,1,h-2,c,2)
    def person(x,y,c):
        for dx,dy,w,h in [(2,0,3,3),(2,4,3,5),(0,4,7,2),(1,8,2,5),(4,8,2,5)]:box(x+dx,y+dy,w,h,c)
    # Decode each sprite's actual wire representation, including high-bit metadata.
    order=sorted(range(len(s.cars)),key=lambda slot:s.cars[slot].y)
    # Same two depth-sorted candidates and transparent fallback as HDL.
    front=np.full((480,640),-1,dtype=np.int16)
    back=np.full((480,640),-1,dtype=np.int16)
    for slot in order:
        car=s.cars[slot]
        if car.visible:
            area=np.s_[max(0,car.y-16):min(480,car.y+8),max(0,car.x-15):min(640,car.x+17)]
            back[area]=front[area];front[area]=slot
    for depth,owner in [(0,back),(1,front)]:
      for slot in order:
        car=s.cars[slot]
        attr=car.pack()[4];heading=attr&3;paint=(attr>>2)&3
        if not attr&16:continue
        mapping={1:[11,12,13][paint],2:[10,5,4][paint],3:14,4:15,5:0}
        for sy in range(24):
            bits=ROM.get(heading*32+sy,0)
            for sx in range(32):
                color=(bits>>((31-sx)*3))&7
                px,py=car.x-15+sx,car.y-16+sy
                if color and 0<=px<640 and 0<=py<480 and owner[py,px]==slot:
                    box(px,py,1,1,mapping[color])
    for x,y,phase,left in [(360,184,s.light_ns,bool(s.left_green&2)),(422,184,s.light_ew,bool(s.left_green&1)),
                           (310,335,s.light_ew,bool(s.left_green&4)),(470,335,s.light_ns,bool(s.left_green&8))]:
        box(x+5,y+23,1,3,3);box(x,y,11,23,2);box(x+1,y+1,9,21,0)
        for k,(on,off) in enumerate([(5,6),(4,9),(7,8)]):box(x+3,y+3+6*k,5,5,on if phase==k else off)
        lx=x;ly=y-13
        box(lx+5,ly+11,1,2,3);box(lx,ly,11,11,2);box(lx+1,ly+1,9,9,0)
        for sy in range(11):
            for sx in range(11):
                if (sy==5 and 2<=sx<=8) or (sx==3 and 4<=sy<=6) or (sx==4 and 3<=sy<=7):
                    conflict_mask={360:2,422:4,310:1,470:8}[x]
                    box(lx+sx,ly+sy,1,1,7 if left else 4 if phase==2 and not(s.ped_walk&conflict_mask) else 5)
    for x,y,mask in [(378,203,1),(408,203,2),(378,285,8),(408,285,4)]:
        if not s.ped_walk&mask:person(x,y,2)
    dx=s.ped_progress*57>>6;dy=dx>>1
    for mask,x,y in [(8,375-dx,283-dy),(2,411+dx,209+dy),(4,411+dx,283-dy),(1,375-dx,209+dy)]:
        if s.ped_walk&mask:person(x,y,7)
    for i,(x,y,label,mask) in enumerate([(133,16,'N',8),(235,16,'E',4),(250,207,'S',2),(112,207,'W',1)]):
        box(x,y,30,29,3,2);box(x+1,y+1,28,27,0,2);text(x+3,y+4,label+'B')
        # Timer-card silhouette at the same 2x UI scale.
        for dx2,dy2,w,h in [(2,0,3,3),(2,4,3,5),(0,4,7,2),(1,8,2,5),(4,8,2,5)]:box(x+19+dx2,y+3+dy2,w,h,7 if s.ped_walk&mask else 5,2)
        text(x+9,y+18,f'{s.seconds[i]:02d}',4)
    box(169,16,60,29,1,2);focus(169,16,60,29,11)
    text(175,21,'PAUSED' if s.ui_command==2 else ['READY','FLOW','CHOOSE','YIELD','LEFT','CLEAR','WALK','HOLD'][s.phase],10)
    text(189,33,str(s.phase_seconds),4);text(201,33,'SEC',4)
    for x,y,t in [(101,67,'N'),(299,65,'E'),(102,191,'W'),(299,184,'S')]:text(x,y,t,3)
    box(7,10,14,26,2,2);box(8,11,12,24,0,2)
    for y,h,c in [(13,6,5),(21,5,4),(28,5,7)]:box(10,y,8,h,c,2)
    text(27,13,'TRAFFIC');text(27,25,'CONTROL')
    for y in (94,140,188):box(7,y,61,1,3,2)
    for k,label in enumerate(['RUN','PAUSE','RESET']):
        y=45+k*16;selected=s.ui_command==k+1
        box(7,y,61,13,[8,9,6][k] if selected else 1,2);box(47,y+2,20,9,0,2)
        text(12,y+3,label);text(49,y+3,f'[{k+1}]',4)
        if selected:focus(7,y,61,13,[10,4,5][k])
    for group,y in [(1,102),(2,166)]:
        for k,label in enumerate(['NB','SB','EB','WB']):
            x=7+k*16;selected=s.menu_kind==group and s.direction_valid and s.direction==k
            box(x,y,13,14,8 if selected else 1,2);text(x+1,y+3,label)
            if selected:focus(x,y,13,14)
    for k,label in enumerate(['L','S','R']):
        x=11+k*20;selected=s.menu_kind==1 and s.turn_valid and s.movement==k
        box(x,121,17,14,8 if selected else 1,2);text(x+6,124,label)
        if selected:focus(x,121,17,14)
    # Reference-only compact heading rendered with Pillow's built-in font;
    # the FPGA uses the compact_glyph ROM in vga_scene.v.
    draw.text((58,284),'S [T]',fill=COLORS[3])
    draw.text((18,302),'PEDESTRIAN [P]',fill=COLORS[4 if s.menu_kind==2 else 10])
    if s.menu_kind==2:focus(7,148,61,12)
    text(11,197,'EMERGENCY',5);text(14,207,'SERVICES',5)
    for k,label in enumerate('AFCB'):
        x=7+k*16;selected=s.menu_kind==3 and s.emergency==(1<<k)
        box(x,222,13,14,6 if selected else 1,2);text(x+4,225,label)
        if selected:focus(x,222,13,14,5)
    box(75,0,1,240,3,2)
    return im


def snapshots():
    import copy
    c=Controller();result=[('01_idle',copy.deepcopy(c.state))]
    c.handle(1);c.update(12);result.append(('02_default',copy.deepcopy(c.state)))
    from test_traffic import until
    c.handle(4);c.handle(8);c.update(1.8);result.append(('03_choose_left',copy.deepcopy(c.state)))
    until(c,lambda:c.phase==Phase.LEFT_WAIT)
    result.append(('04_center_yield',copy.deepcopy(c.state)))
    target=c._target()
    until(c,lambda:target.turn_committed)
    c.update(1.2);result.append(('05_gap_turn',copy.deepcopy(c.state)))
    until(c,lambda:c.phase==Phase.DEFAULT)
    c.handle(11);c.handle(7)
    until(c,lambda:c.phase==Phase.WALK)
    c.update(2.5);result.append(('06_wb_pedestrian',copy.deepcopy(c.state)))
    return result


if __name__=='__main__':
    output=ROOT/'docs'/'previews';output.mkdir(parents=True,exist_ok=True)
    sheet=Image.new('RGB',(1280,3*510),(20,24,28));d=ImageDraw.Draw(sheet)
    frames=snapshots()
    (ROOT/'sim/vga_states.hex').write_text('\n'.join(state.payload()[::-1].hex() for _,state in frames)+'\n')
    (ROOT/'sim/vga_cars.hex').write_text('\n'.join(b''.join(c.pack() for c in state.cars)[::-1].hex() for _,state in frames)+'\n')
    for i,(name,state) in enumerate(frames):
        im=render(state);im.save(output/(name+'.png'))
        x=(i%2)*640;y=(i//2)*510
        sheet.paste(im,(x,y+30));d.text((x+10,y+8),name,fill='white')
    sheet.save(output/'contact_sheet.png')
    print('Software reference previews:',output)
