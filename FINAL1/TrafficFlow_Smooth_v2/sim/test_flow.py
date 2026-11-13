"""Gap acceptance, continuous flow, interruption and independent geometry checks."""
import math
import random
import sys
import time
import unittest
from unittest.mock import patch
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'Python'))
from control import (Controller,Vehicle,Request,Phase,N,S,E,W,LEFT,STRAIGHT,RIGHT,
                     STEP,SPEED,ACCEL,BRAKE,LEFT_MAX_WAIT,make_route,CLEAR_TIME)


def corners(car):
    # Independent oracle: exact route points, not the admission lookup/cache.
    (x,y),_=car.pose()
    a,_=car.route.pose(max(0,car.distance-.02))
    b,_=car.route.pose(min(car.route.total,car.distance+.02))
    vx,vy=b[0]-a[0],b[1]-a[1];length=math.hypot(vx,vy) or 1
    vx/=length;vy/=length
    return [(x+long*vx-short*vy,y+long*vy+short*vx)
            for long,short in [(-4.8,-2.2),(4.8,-2.2),(4.8,2.2),(-4.8,2.2)]]


def polygons_overlap(a,b):
    for shape in (a,b):
        for i,p in enumerate(shape):
            q=shape[(i+1)%4];axis=(q[1]-p[1],p[0]-q[0])
            u=[x*axis[0]+y*axis[1] for x,y in a]
            v=[x*axis[0]+y*axis[1] for x,y in b]
            if max(u)<=min(v)+1e-7 or max(v)<=min(u)+1e-7:return False
    return True


def assert_no_collisions(test,c):
    cars=[v for v in c.vehicles if v and v.distance>=0]
    for i,a in enumerate(cars):
        pa=a.pose()[0]
        for b in cars[i+1:]:
            pb=b.pose()[0]
            if math.dist(pa,pb)>12:continue
            test.assertFalse(polygons_overlap(corners(a),corners(b)),
                             (c.elapsed,c.phase.value,a.uid,b.uid))


def isolated(direction=N,movement=LEFT):
    c=Controller();c.handle(1);c.vehicles=[None]*20
    c.request=Request(direction,movement=movement)
    c.peer_spawned=True;c._phase(Phase.USER)
    car=Vehicle(1,direction,movement,0)
    car.distance=car.route.entry;car.locked=True
    c.vehicles[direction]=car;c.target_uid=1;c.serial=1;c.batch_uids={1}
    return c,car


class Flow(unittest.TestCase):
    def test_green_opposing_streams_never_stop_inside(self):
        c,a=isolated(N,STRAIGHT)
        b=Vehicle(2,S,STRAIGHT,1);b.distance=b.route.entry-20;b.speed=SPEED
        a.distance-=20;a.speed=SPEED
        c.vehicles[S]=b;c.batch_uids.add(2)
        together=False
        for _ in range(60*6):
            c.update(STEP);assert_no_collisions(self,c)
            together |= a.in_junction and b.in_junction
            if a.distance<a.route.clear:self.assertAlmostEqual(a.speed,SPEED)
            if b.distance<b.route.clear:self.assertAlmostEqual(b.speed,SPEED)
        self.assertTrue(together)
        self.assertTrue(a.admitted and b.admitted)

    def test_empty_green_left_enters_on_first_step(self):
        for d in range(4):
            c,car=isolated(d)
            c.update(STEP)
            self.assertTrue(car.admitted)
            self.assertGreater(car.distance,car.route.entry)
            self.assertEqual(c.state.left_green,0)

    def test_yield_rechecks_every_tick_then_goes_when_gap_opens(self):
        for d in range(4):
            c,car=isolated(d)
            peer=(S,N,W,E)[d]
            other=Vehicle(2,peer,STRAIGHT,1)
            other.distance=other.route.entry-20;other.speed=SPEED;other.admitted=False
            c.vehicles[peer]=other;c.batch_uids.add(2)
            car.admitted=True;car.distance=car.route.hold
            self.assertTrue(c._safe_entry(car))
            self.assertFalse(c._safe_turn(car))
            for _ in range(300):
                before=car.turn_committed
                c.update(STEP);assert_no_collisions(self,c)
                if car.turn_committed:
                    self.assertFalse(before)
                    self.assertGreaterEqual(other.distance,other.route.entry+44)
                    self.assertLess(c.elapsed,LEFT_MAX_WAIT)
                    break
            self.assertTrue(car.turn_committed)
            # Once committed, even emergency red cannot park it in the box.
            c.handle(12)
            previous=car.distance
            for _ in range(480):
                c.update(STEP)
                self.assertGreater(car.distance,previous)
                previous=car.distance
                if not car.in_junction:break
            self.assertFalse(car.in_junction)

    @patch('control.LEFT_MAX_WAIT',0.25)
    def test_protected_fallback_yellow_clearance_and_no_starvation(self):
        # Shorten only the starvation deadline to force this normally rare
        # path while the standard five-car opposing platoon is still present.
        c=Controller();c.handle(1);c.handle(4);c.handle(8)
        seen=set();target=c._target()
        for _ in range(60*25):
            c.update(STEP);seen.add(c.phase)
            assert_no_collisions(self,c)
            if c.phase==Phase.LEFT_GREEN:
                self.assertEqual(c.state.left_green,8)
                self.assertEqual((c.state.light_ns,c.state.light_ew),(0,0))
                if not target.admitted:self.assertFalse(c._occupied())
            if target.admitted and not target.in_junction:break
        self.assertIn(Phase.YELLOW,seen)
        self.assertIn(Phase.CLEAR,seen)
        self.assertTrue(target.admitted)
        self.assertLess(c.elapsed,20)

    def test_left_queue_does_not_block_outer_lane(self):
        c=Controller();c.handle(1);c.handle(4);c.handle(8)
        target=c._target();passed=False
        for _ in range(60*18):
            c.update(STEP);assert_no_collisions(self,c)
            if not target.turn_committed:
                passed |= any(v.uid!=target.uid and v.admitted for v in c._queue(N))
        self.assertTrue(passed)

    def test_new_acceleration_and_braking_are_bounded_on_approach(self):
        c,car=isolated(N,STRAIGHT);c._phase(Phase.EMERGENCY,0)
        car.distance-=40;car.speed=SPEED
        last=car.speed
        for _ in range(240):
            c.update(STEP)
            self.assertLessEqual(car.distance,car.route.entry+1e-8)
            self.assertLessEqual(car.speed-last,ACCEL*STEP+1e-7)
            # Discrete contact clamp allowed only within one integration step.
            if car.route.entry-car.distance>0.02:
                self.assertGreaterEqual(car.speed-last,-BRAKE*STEP-1e-7)
            last=car.speed
        self.assertLess(car.speed,.01)

    def test_seeded_busy_requests_all_vehicle_pairs_and_interruptions(self):
        for seed in (7,42,20261112):
            rng=random.Random(seed);c=Controller();c.handle(1)
            for tick in range(60*180):
                if tick%101==0:
                    if c.emergency:c.handle(16)
                    elif tick%505==0:c.handle(12+rng.randrange(4))
                    elif tick%303==0:
                        c.handle(11);c.handle(4+rng.randrange(4))
                    else:
                        c.handle(4+rng.randrange(4));c.handle(8+rng.randrange(3))
                c.update(STEP);assert_no_collisions(self,c)
                self.assertFalse(c.state.light_ns==2 and c.state.light_ew==2)
                if c.state.ped_walk:
                    from test_walk_flow import assert_pedestrian_clear
                    assert_pedestrian_clear(self,c)
                    self.assertFalse(c._walk_busy())
            c.handle(16)
            # Requests must finish rather than leave a permanently locked phase.
            c.update(120)
            self.assertEqual(c.phase,Phase.DEFAULT)

    def test_late_request_with_all_five_routes_locked_is_not_lost(self):
        for d in (E,W):
            c=Controller();c.handle(1);c.update(6)
            # Previously committed routes need not be physically at notice.
            for v in c._queue(d):v.locked=True
            self.assertTrue(all(v.locked for v in c._queue(d)))
            c.handle(4+d);c.handle(8)
            self.assertIsNone(c.target_uid)
            for _ in range(60*40):
                c.update(STEP);assert_no_collisions(self,c)
                if c.phase==Phase.DEFAULT:break
            self.assertEqual(c.phase,Phase.DEFAULT)
            self.assertTrue(any(e[1]=='enter' and e[3]==d and e[4]==LEFT for e in c.events))

    def test_emergency_freezes_and_resumes_walker_progress(self):
        c=Controller();c.handle(1);c.handle(11);c.handle(7)
        for _ in range(600):
            c.update(STEP)
            if c.phase==Phase.WALK:break
        self.assertEqual(c.phase,Phase.WALK)
        c.update(1.25);remaining=c.remaining;progress=c.state.ped_progress
        c.handle(14);c.update(10);c.handle(16);c.update(CLEAR_TIME)
        self.assertEqual(c.phase,Phase.WALK)
        self.assertAlmostEqual(c.remaining,remaining)
        self.assertEqual(c.state.ped_progress,progress)
        self.assertFalse(c._walk_busy())
        c.update(remaining)
        self.assertEqual(c.phase,Phase.YELLOW)

    def test_protected_center_wait_excludes_target_from_clearance(self):
        for d in range(4):
            c,car=isolated(d)
            car.admitted=True;car.distance=car.route.hold
            peer=(S,N,W,E)[d]
            other=Vehicle(2,peer,STRAIGHT,1)
            other.distance=other.route.entry+20;other.speed=SPEED;other.admitted=True
            c.vehicles[peer]=other;c.batch_uids.add(2)
            c.after_clear=Phase.LEFT_GREEN;c._phase(Phase.CLEAR,CLEAR_TIME)
            for _ in range(600):
                c.update(STEP);assert_no_collisions(self,c)
                if c.phase==Phase.LEFT_GREEN:break
                self.assertFalse(car.turn_committed)
            self.assertEqual(c.phase,Phase.LEFT_GREEN)
            self.assertFalse(other.in_junction)
            self.assertEqual((c.state.light_ns,c.state.light_ew),(0,0))
            c.update(STEP)
            self.assertTrue(car.turn_committed)

    def test_live_sprite_slots_do_not_shift_when_other_cars_exit(self):
        c=Controller();c.handle(1);known={};exits=False
        for _ in range(60*40):
            c.update(STEP)
            for slot,v in enumerate(c.vehicles):
                if not v:continue
                if v.uid in known:self.assertEqual(slot,known[v.uid])
                known[v.uid]=slot
            exits |= any(e[1]=='exit' for e in c.events)
        self.assertTrue(exits)

    def test_center_braking_has_no_velocity_jump_and_holds_wheels_straight(self):
        c=Controller();c.handle(1);c.handle(4);c.handle(8)
        car=c._target();last=car.speed;held=False
        for _ in range(60*15):
            c.update(STEP)
            self.assertGreaterEqual(car.speed-last,-BRAKE*STEP-1e-6)
            self.assertLessEqual(car.speed-last,ACCEL*STEP+1e-6)
            if car.admitted and not car.turn_committed and car.speed<.01:
                self.assertAlmostEqual(car.distance,car.route.hold,delta=.01)
                self.assertEqual(car.pose()[1],N);held=True
            last=car.speed
            if car.turn_committed:break
        self.assertTrue(held)

    def test_slow_link_partition_preserves_deterministic_motion(self):
        a,b=Controller(),Controller()
        for c in (a,b):c.handle(1);c.handle(6);c.handle(8)
        a.update(30)
        for _ in range(300):b.update(.1)
        self.assertEqual(a.events,b.events)
        self.assertEqual(a.state.cars,b.state.cars)


if __name__=='__main__':unittest.main()
