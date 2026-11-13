"""Five-car queue and complete twenty-sprite transport regressions."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'Python'))
from control import Controller, Phase, N, S, E, W, STRAIGHT, LEFT, RIGHT, STEP, QUEUE_GAP
from protocol import DisplayState, Car, encode_frame, crc8
from jtag_link import JtagDisplayLink, BoardReset
from test_python import response
from test_traffic import until


class Queues(unittest.TestCase):
    def test_five_cars_per_active_direction_and_only_leader_chooses(self):
        for direction in range(4):
            for turn in (LEFT, STRAIGHT, RIGHT):
                with self.subTest(direction=direction,turn=turn):
                    c=Controller();c.handle(1);c.handle(4+direction);c.handle(8+turn)
                    target=c._target()
                    self.assertEqual(target.uid,c._queue(direction)[0].uid)
                    self.assertEqual(target.movement,turn)
                    batch={v.uid for v in c.vehicles if v and v.uid in c.batch_uids}
                    self.assertEqual(len(batch),10)
                    self.assertEqual(len(c._queue(direction)),5)
                    self.assertTrue(all(v.movement==STRAIGHT for v in c._queue(direction)[1:]))
                    until(c,lambda:c.phase==Phase.DEFAULT,limit=120)
                    entered=[e for e in c.events if e[1]=='enter' and e[2] in batch]
                    self.assertEqual({e[2] for e in entered},batch)
                    self.assertEqual([e[4] for e in entered if e[2]==target.uid],[turn])
                    self.assertTrue(all(e[4]==STRAIGHT for e in entered if e[2]!=target.uid))

    def test_busy_default_replenishes_and_queues_keep_spacing(self):
        c=Controller();c.handle(1)
        peak_visible=0
        for _ in range(60*60):
            c.update(STEP)
            peak_visible=max(peak_visible,sum(v.visible for v in c.state.cars))
            for d in (E,W):
                queue=c._queue(d)
                self.assertGreaterEqual(len(queue),4)
                self.assertLessEqual(len(queue),5)
                for lead,follow in zip(queue,queue[1:]):
                    if not follow.admitted and not lead.admitted:
                        gap=(follow.route.entry-follow.distance)-(lead.route.entry-lead.distance)
                        self.assertGreaterEqual(gap,QUEUE_GAP-1e-7)
            self.assertFalse(c._queue(N) or c._queue(S))
        self.assertGreaterEqual(peak_visible,8)

    def test_only_target_changes_during_choice(self):
        c=Controller();c.handle(1);c.handle(4)
        ids=[v.uid for v in c._queue(N)]
        for cmd in (8,10,9,8):
            c.handle(cmd);c.update(.2)
            self.assertEqual([v.uid for v in c._queue(N)],ids)
            self.assertTrue(all(v.movement==STRAIGHT for v in c._queue(N)[1:]))

    def test_twenty_cars_survive_banking_crc_sequence_wrap_and_keys(self):
        state=DisplayState()
        state.cars=[Car(180+i*17,100+i*13,i%4,i%3,i%2==0) for i in range(20)]
        class Session:
            def __init__(self):self.sent=[]
            def exchange(self,seq,packet):
                self.sent.append((seq,packet));return response(sequence=seq,keys=(5,9))
        session=Session();link=JtagDisplayLink(session=session);link.sequence=254
        link.send(state)
        self.assertEqual([seq for seq,_ in session.sent],[254,255,0,1,2])
        self.assertEqual(link.sequence,3)
        self.assertEqual(link.commands(),[5,9]*5)
        for bank,(_,packet) in enumerate(session.sent):
            self.assertEqual(packet[2],4)
            self.assertEqual(packet[8]>>2,bank)
            self.assertEqual(packet[-1],crc8(packet[2:-1]))
            for i in range(4):
                actual=bytearray(packet[15+5*i:20+5*i]);actual[4]&=31
                self.assertEqual(actual,state.cars[bank*4+i].pack())

    def test_bad_last_car_is_rejected_before_first_bank(self):
        state=DisplayState();state.cars[-1].x=640
        class Session:
            def exchange(self,*args):raise AssertionError('partial invalid snapshot transmitted')
        with self.assertRaises(ValueError):JtagDisplayLink(session=Session()).send(state)

    def test_reset_during_bank_restarts_next_snapshot_at_zero(self):
        class Session:
            def __init__(self):self.banks=[];self.reset_once=True
            def exchange(self,seq,packet):
                bank=packet[8]>>2;self.banks.append(bank)
                if bank==2 and self.reset_once:
                    self.reset_once=False;return response(sequence=seq,result=3)
                return response(sequence=seq,keys=())
        session=Session();link=JtagDisplayLink(session=session)
        with self.assertRaises(BoardReset):link.send(DisplayState(ui_command=1))
        link.send(DisplayState())
        self.assertEqual(session.banks,[0,1,2,0,1,2,3,4])


if __name__=='__main__':unittest.main()
