"""Independent person/body checks and compatible WALK traffic acceptance."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'Python'))
from control import Controller,Phase,N,S,E,W,LEFT,STRAIGHT,RIGHT,STEP,crosses_walk
from test_flow import corners,polygons_overlap,assert_no_collisions
from test_traffic import until


def assert_pedestrian_clear(test,c):
    if c.phase!=Phase.WALK:return
    p=c.state.ped_progress;dx=(p*57)>>6;dy=dx>>1
    px,py=((375-dx,283-dy),(411+dx,209+dy),
           (411+dx,283-dy),(375-dx,209+dy))[c.request.direction]
    # Use the actual graphics' foot position, not the production walk cache.
    px+=3;py+=12
    x=((px-396)-2*(py-256))/4
    y=(-(px-396)-2*(py-256))/4
    person=[(x-1.5,y-1.5),(x+1.5,y-1.5),(x+1.5,y+1.5),(x-1.5,y+1.5)]
    for v in c.vehicles:
        if v and v.distance>=0:
            test.assertFalse(polygons_overlap(corners(v),person),
                             ('pedestrian collision',c.elapsed,c.request.direction,v.uid))


class WalkFlow(unittest.TestCase):
    def test_crosswalk_conflict_matrix_on_parallel_axis(self):
        allowed={N:{(N,STRAIGHT),(N,RIGHT),(S,LEFT),(S,STRAIGHT)},
                 S:{(N,LEFT),(N,STRAIGHT),(S,STRAIGHT),(S,RIGHT)},
                 E:{(E,LEFT),(E,STRAIGHT),(W,STRAIGHT),(W,RIGHT)},
                 W:{(E,STRAIGHT),(E,RIGHT),(W,LEFT),(W,STRAIGHT)}}
        for p in range(4):
            for d in range(4):
                for turn in range(3):
                    if d//2==p//2:
                        self.assertEqual(not crosses_walk(d,turn,p),(d,turn) in allowed[p],(p,d,turn))

    def test_all_walk_directions_have_moving_compatible_traffic(self):
        for p in range(4):
            c=Controller();c.handle(1);c.update(3);c.handle(11);c.handle(4+p)
            until(c,lambda:c.phase==Phase.WALK,limit=25)
            moving=set();simultaneous=False
            for _ in range(299):
                self.assertEqual(c.phase,Phase.WALK)
                ns,ew,_=c._lights()
                self.assertEqual((ns,ew),(2,0) if p//2==0 else (0,2))
                before={v.uid:v.distance for v in c.vehicles if v}
                c.update(STEP);assert_no_collisions(self,c);assert_pedestrian_clear(self,c)
                for v in c.vehicles:
                    if v and v.uid in before and v.distance>before[v.uid]+.001:
                        moving.add(v.uid)
                        simultaneous |= v.in_junction and c.state.ped_progress in range(10,60)
                    if v and v.in_junction:
                        self.assertFalse(crosses_walk(v.direction,v.movement,p))
            self.assertGreaterEqual(len(moving),4)
            self.assertTrue(simultaneous)
            c.update(STEP);self.assertEqual(c.phase,Phase.YELLOW)
            until(c,lambda:c.phase==Phase.DEFAULT,limit=30)

    def test_person_waits_for_preexisting_conflicting_turn(self):
        c=Controller();c.handle(1)
        # Allow a default right turn into the future south-side crosswalk.
        until(c,lambda:any(v and v.admitted and v.movement==RIGHT and
                          crosses_walk(v.direction,v.movement,E) for v in c.vehicles),limit=20)
        c.handle(11);c.handle(6)
        for _ in range(1200):
            c.update(STEP)
            if c.phase==Phase.WALK:
                self.assertFalse(c._walk_busy());break
            self.assertEqual(c.state.ped_walk,0)
        self.assertEqual(c.phase,Phase.WALK)


if __name__=='__main__':unittest.main()
