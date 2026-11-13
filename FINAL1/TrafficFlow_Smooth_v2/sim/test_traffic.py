"""Behavioral acceptance tests for the requested traffic simulation."""
from pathlib import Path
import math
import random
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'Python'))
from control import (Controller, Phase, N, S, E, W, LEFT, STRAIGHT, RIGHT,
                     PERIOD, STEP, WIRE_INDEX, make_route, project, SELECT_TIME, YELLOW_TIME, CLEAR_TIME)
from protocol import DisplayState, encode_frame


def advance(c, seconds):
    return c.update(seconds)


def until(c, predicate, limit=90):
    for _ in range(round(limit/STEP)):
        if predicate():
            return
        c.update(STEP)
    raise AssertionError('Timed out in '+c.phase.value)


class TrafficTests(unittest.TestCase):
    def assert_safe(self, c):
        s = c.state
        self.assertFalse(s.light_ns == 2 and s.light_ew == 2)
        from test_flow import assert_no_collisions
        assert_no_collisions(self,c)
        if s.left_green or s.emergency:
            self.assertEqual((s.light_ns, s.light_ew), (0, 0))
        if s.ped_walk:
            self.assertEqual(s.left_green, 0)
            self.assertFalse(c._walk_busy())
            from test_walk_flow import assert_pedestrian_clear
            assert_pedestrian_clear(self,c)
        self.assertIn(s.phase_seconds, range(6))
        self.assertTrue(all(0 <= v <= 5 for v in s.seconds))
        self.assertEqual(len(encode_frame(s, 0)), 36)

    def test_idle_and_reset_are_empty(self):
        c = Controller()
        for key in [4, 8, 11, 6, 12]:
            c.handle(key)
        c.update(10)
        self.assertFalse(any(v.visible for v in c.state.cars))
        self.assertEqual((c.state.light_ns, c.state.light_ew, c.state.left_green), (0,0,0))
        c.handle(1); c.update(4); c.handle(3)
        self.assertEqual(c.phase, Phase.IDLE)
        self.assertFalse(any(v.visible for v in c.state.cars))
        self.assertEqual(c.state.ui_command, 3)
        c.reset()
        self.assertEqual(c.state.ui_command, 0)

    def test_default_only_ew_and_alternating_right_turns(self):
        c = Controller(); c.handle(1)
        for _ in range(40*60):
            c.update(STEP); self.assert_safe(c)
            self.assertEqual((c.state.light_ns,c.state.light_ew), (0,2))
            self.assertIsNone(c.vehicles[N]); self.assertIsNone(c.vehicles[S])
        for d in (E,W):
            turns = [e[4] for e in c.events if e[1]=='spawn' and e[3]==d]
            self.assertGreaterEqual(len(turns), 3)
            self.assertEqual(turns, [STRAIGHT if i%2==0 else RIGHT for i in range(len(turns))])

    def test_all_direction_turn_pairs_return_to_default(self):
        for d in range(4):
            for movement in range(3):
                with self.subTest(direction=d, movement=movement):
                    c=Controller(); c.handle(1); c.update(1)
                    c.handle(4+d); c.handle(8+movement)
                    until(c, lambda:c.phase==Phase.DEFAULT)
                    entries=[e for e in c.events if e[1]=='enter' and e[3]==d]
                    self.assertTrue(any(e[4]==movement for e in entries), entries)
                    self.assert_safe(c)

    def test_short_choice_window_follows_yellow_without_slow_mode(self):
        c=Controller();c.handle(1);c.handle(4)
        self.assertEqual(c.phase,Phase.YELLOW)
        self.assertEqual(c.state.light_ew,1)
        c.update(YELLOW_TIME)
        self.assertEqual(c.phase,Phase.SELECT)
        car=c._target();before=car.distance
        c.handle(10)
        self.assertEqual(car.movement,RIGHT)
        c.update(SELECT_TIME)
        self.assertEqual(c.phase,Phase.USER)
        self.assertGreater(car.distance-before,6*SELECT_TIME)
        c.handle(8)
        self.assertEqual(car.movement,RIGHT)

    def test_late_valid_left_choice_does_not_teleport_car(self):
        c=Controller();c.handle(1);c.update(1.8);c.handle(6)
        car=c._target();self.assertIsNotNone(car)
        before=car.pose()[0];c.handle(8)
        self.assertEqual(car.pose()[0],before)
        c.update(STEP)
        after=car.pose()[0]
        self.assertLess(math.hypot(after[0]-before[0],after[1]-before[1]),1)

    def test_no_choice_defaults_straight(self):
        c=Controller();c.handle(1);c.handle(4);c.update(5)
        self.assertEqual(c._target().movement,STRAIGHT)
        self.assertEqual(c.phase,Phase.USER)

    def test_notice_boundary_locks_route(self):
        c=Controller();c.handle(1);c.update(3)
        old=c.vehicles[E]
        self.assertTrue(old.locked)
        before=old.movement
        c.handle(6);c.handle(8)
        self.assertEqual(old.movement,before)
        # The first unlocked follower can now accept the request immediately.
        until(c,lambda:c.target_uid is not None)
        self.assertNotEqual(c.target_uid,old.uid)
        self.assertEqual(c._target().movement,LEFT)
        until(c,lambda:c.phase==Phase.DEFAULT)

    def test_left_yields_to_stream_and_uses_gap_without_fixed_wait(self):
        c=Controller();c.handle(1);c.handle(4);c.handle(8)
        until(c,lambda:c.phase==Phase.LEFT_WAIT)
        start=c.elapsed;car=c._target()
        self.assertTrue(car.admitted)
        self.assertAlmostEqual(car.distance,car.route.hold,delta=.25)
        until(c,lambda:car.turn_committed)
        self.assertLess(c.elapsed-start,5)
        self.assertEqual((c.state.light_ns,c.state.light_ew),(2,0))
        self.assertEqual(c.state.left_green,0)
        self.assertTrue(any(e[1]=='enter' and e[2]==car.uid for e in c.events))

    def test_pause_freezes_motion_timers_and_resume(self):
        c=Controller();c.handle(1);c.handle(4);c.update(2)
        remaining=c.remaining
        c.handle(2);before=[c.state.payload(b) for b in range(5)];elapsed=c.elapsed
        c.update(120)
        self.assertEqual([c.state.payload(b) for b in range(5)],before);self.assertEqual(c.elapsed,elapsed)
        c.handle(1);c.update(1)
        self.assertAlmostEqual(c.remaining,max(0,remaining-1))
        self.assertGreater(c._target().distance,12)

    def test_running_again_does_not_restart(self):
        c=Controller();c.handle(1);c.handle(4);c.update(2)
        phase,remaining=c.phase,c.remaining
        c.handle(1)
        self.assertEqual(c.phase,phase);self.assertAlmostEqual(c.remaining,remaining)

    def test_pedestrians_in_all_travel_directions(self):
        for direction in range(4):
            c=Controller();c.handle(1);c.update(3)
            c.handle(11);c.handle(4+direction)
            until(c,lambda:c.phase==Phase.WALK)
            self.assertEqual(c.state.ped_walk,1<<(3-WIRE_INDEX[direction]))
            self.assertEqual(c.state.seconds[WIRE_INDEX[direction]],5)
            start=c.elapsed
            for _ in range(299):
                c.update(STEP);self.assert_safe(c)
            self.assertGreater(c.state.ped_progress,60)
            c.update(STEP)
            self.assertEqual(c.phase,Phase.YELLOW)
            self.assertAlmostEqual(c.elapsed-start,5)
            self.assertEqual(c.state.ped_walk,0)
            until(c,lambda:c.phase==Phase.DEFAULT)

    def test_emergency_all_four_and_release(self):
        for key in range(12,16):
            c=Controller();c.handle(1);c.update(3);c.handle(key)
            for _ in range(400):
                c.update(STEP);self.assert_safe(c)
            self.assertEqual(c.phase,Phase.EMERGENCY)
            self.assertEqual(c.state.emergency,1<<(key-12))
            self.assertFalse(c._occupied())
            c.handle(key)
            self.assertEqual(c.phase,Phase.CLEAR)
            c.update(5)
            self.assertEqual(c.phase,Phase.DEFAULT)
            self.assertEqual(c.state.emergency,0)

    def test_emergency_resumes_left_request(self):
        c=Controller();c.handle(1);c.handle(4);c.handle(8)
        until(c,lambda:c.phase==Phase.LEFT_WAIT)
        phase,remaining,wait=c.phase,c.remaining,c.left_wait
        c.handle(12);c.update(8);c.handle(16)
        c.update(CLEAR_TIME)
        self.assertEqual(c.phase,phase)
        self.assertAlmostEqual(c.remaining,remaining)
        self.assertAlmostEqual(c.left_wait,wait)
        until(c,lambda:c.phase==Phase.DEFAULT)

    def test_emergency_during_release_clearance_preserves_request(self):
        c=Controller();c.handle(1);c.handle(4);c.handle(8)
        until(c,lambda:c.phase==Phase.LEFT_WAIT)
        c.handle(12);c.update(1);c.handle(12);c.update(CLEAR_TIME/2)
        c.handle(13);c.update(1);c.handle(13)
        until(c,lambda:c.resume is None,limit=20)
        self.assertIn(c.phase,(Phase.LEFT_WAIT,Phase.USER))
        until(c,lambda:c.phase==Phase.DEFAULT)

    def test_latest_queued_request_is_served(self):
        c=Controller();c.handle(1);c.handle(4);c.handle(8)
        c.handle(5);c.handle(6);c.handle(10)
        self.assertEqual(c.pending.direction,E)
        until(c,lambda:c.request is not None and c.request.direction==E)
        self.assertEqual(c.request.movement,RIGHT)
        until(c,lambda:c.phase==Phase.DEFAULT)

    def test_step_partition_invariance(self):
        a,b=Controller(),Controller()
        for c in (a,b):c.handle(1);c.handle(4);c.handle(8)
        a.update(22)
        for _ in range(220):b.update(.1)
        self.assertEqual([a.state.payload(i) for i in range(5)], [b.state.payload(i) for i in range(5)])
        self.assertEqual(a.events,b.events)

    def test_invalid_time_rejected(self):
        c=Controller()
        for value in [-1,float('inf'),float('nan')]:
            with self.assertRaises(ValueError):c.update(value)

    def test_paths_start_at_opposite_compass_edge(self):
        for d in range(4):
            for turn in range(3):
                route=make_route(d,turn)
                point,heading=route.pose(0)
                self.assertEqual(heading,d)
                for p in route.points:
                    x,y=project(p)
                    self.assertTrue(169<=x<=639 and 0<=y<=479)
                _,end_heading=route.pose(route.total)
                expected=d if turn==STRAIGHT else ((W,E,N,S)[d] if turn==LEFT else (E,W,S,N)[d])
                self.assertEqual(end_heading,expected)

    def test_randomized_commands_safety_and_packet_ranges(self):
        rng=random.Random(20261112)
        c=Controller();c.handle(1)
        for i in range(18000):
            if i%47==0:c.handle(rng.randint(1,16))
            c.update(STEP);self.assert_safe(c)

    def test_reset_and_metadata_wire_layout(self):
        s=DisplayState(left_green=8,phase=4,phase_seconds=5,ped_progress=43)
        p=s.payload()
        self.assertEqual(p[6],0x80)
        self.assertEqual(p[15]>>5,4)
        self.assertEqual(p[20]>>5,5)
        self.assertEqual((p[25]>>5)|((p[30]>>5)<<3),43)
        root=Path(__file__).resolve().parents[1]
        value=int.from_bytes(DisplayState().payload(),'little')
        for name in ['CPU/traffic_io.v','JTAG/jtag_display_link.v']:
            import re
            literal=re.search(r"RESET_STATE=248'h([0-9a-f]+)",(root/name).read_text()).group(1)
            self.assertEqual(int(literal,16),value)

    def test_south_key_and_straight_label_use_distinct_codes(self):
        from app import KEYS
        self.assertEqual(KEYS['s'],5);self.assertEqual(KEYS['t'],9)
        root=Path(__file__).resolve().parents[1]
        self.assertIn('text_pixel(x,y,37,124,1,"S")',(root/'vga_scene.v').read_text())

    def test_host_recognizes_board_reset(self):
        from jtag_link import JtagDisplayLink,BoardReset
        from test_python import FakeSession,response
        link=JtagDisplayLink(session=FakeSession(response(result=3)))
        with self.assertRaises(BoardReset):link.send(DisplayState(ui_command=1))
        self.assertEqual(link.sequence,1)


if __name__=='__main__':unittest.main()
