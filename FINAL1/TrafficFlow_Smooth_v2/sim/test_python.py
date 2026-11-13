"""Standard-library-only tests; no board or pyserial needed."""
from pathlib import Path
import sys,unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'Python'))
from protocol import Car,DisplayState,encode_frame,crc8
from control import Controller

class Tests(unittest.TestCase):
    def test_layout_and_crc(self):
        self.assertEqual(crc8(b'123456789'),0xF4) # standard CRC-8 check vector
        state=DisplayState();packet=encode_frame(state,255)
        self.assertEqual(len(packet),36)
        self.assertEqual(packet[:4],bytes([0xA5,0x5A,4,255]))
        self.assertEqual(packet[-1],crc8(packet[2:-1]))
        self.assertEqual(packet[11:15],bytes(4))
        self.assertEqual(packet[15:20],bytes(5))
    def test_ranges(self):
        for car in [Car(-1,2),Car(640,2),Car(2,480),Car(2,2,4),Car(2,2,paint=3)]:
            with self.assertRaises(ValueError):car.pack()
        for value in [-1,100]:
            s=DisplayState(seconds=[value,0,0,0])
            with self.assertRaises(ValueError):s.payload()

class FakeSession:
    def __init__(self,reply):self.reply=reply;self.sent=[]
    def exchange(self,sequence,packet):self.sent.append((sequence,packet));return self.reply
    def close(self):pass

def response(sequence=0,keys=(5,9),result=0,flags=2):
    data=bytearray(b'JG'+bytes([sequence,result,len(keys)])+bytes(keys)+bytes(16-len(keys)))
    return bytes(data)+bytes([crc8(data),3,flags])

class JtagTests(unittest.TestCase):
    def test_host_decodes_actual_rtl_replies(self):
        from jtag_link import JtagDisplayLink
        root=Path(__file__).resolve().parents[1]
        if not (root/'sim/rtl_verified.marker').exists():
            self.skipTest('Run sim/check.py with Icarus first; no current RTL results available')
        replies=[int(line,16).to_bytes(24,'little') for line in (root/'sim/replies.hex').read_text().splitlines()]
        for reply in replies:
            link=JtagDisplayLink(session=FakeSession(reply));link.sequence=reply[2]
            if reply[3]:
                with self.assertRaises(RuntimeError):link.send(DisplayState())
            else:
                link._send_packet(encode_frame(DisplayState(),link.sequence));self.assertEqual(link.commands(),list(reply[5:5+reply[4]]))
        self.assertTrue(any(reply[5:7]==bytes([5,9]) for reply in replies))

    def test_reply_crc_sequence_and_flags(self):
        from jtag_link import JtagDisplayLink
        bad_crc=bytearray(response());bad_crc[21]^=1
        for data in [bytes(bad_crc),response(sequence=1),response(flags=3),response(flags=6),response(result=2)]:
            link=JtagDisplayLink(session=FakeSession(data))
            with self.assertRaises(RuntimeError):link.send(DisplayState())
            self.assertEqual(link.sequence,0)

    def test_real_tcl_server_and_python_subprocess(self):
        from jtag_link import JtagDisplayLink,JtagSession
        import shutil
        root=Path(__file__).resolve().parents[1]
        tcl=shutil.which('tclsh')
        if not tcl:self.skipTest('tclsh not installed; optional mock Quartus API test')
        cmd=[tcl,str(root/'sim/mock_quartus.tcl'),str(root/'Host/jtag_server.tcl'),'serve','','']
        session=JtagSession(command=cmd);link=JtagDisplayLink(session=session)
        try:
            self.assertIn('5CSEMA5',session.description)
            for _ in range(260):link.send(DisplayState())
            self.assertEqual(link.sequence,20)
            self.assertEqual(link.commands(),[5,9]*1300)
        finally:link.close()
        self.assertIsNone(session.process)

    def test_tcl_reset_notification_and_idle_recovery(self):
        from jtag_link import JtagDisplayLink,JtagSession,BoardReset
        import shutil
        root=Path(__file__).resolve().parents[1];tcl=shutil.which('tclsh')
        if not tcl:self.skipTest('tclsh not installed')
        cmd=[tcl,str(root/'sim/mock_quartus.tcl'),str(root/'Host/jtag_server.tcl'),'reset_test','','']
        session=JtagSession(command=cmd);link=JtagDisplayLink(session=session)
        try:
            with self.assertRaises(BoardReset):link.send(DisplayState(ui_command=1))
            link.send(DisplayState())
            link.send(DisplayState(ui_command=1))
            self.assertEqual(link.sequence,10)
        finally:link.close()

    def test_reset_interrupting_idle_scan_recovers(self):
        from jtag_link import JtagDisplayLink,JtagSession,BoardReset
        import shutil
        root=Path(__file__).resolve().parents[1];tcl=shutil.which('tclsh')
        if not tcl:self.skipTest('tclsh not installed')
        cmd=[tcl,str(root/'sim/mock_quartus.tcl'),str(root/'Host/jtag_server.tcl'),'reset_during_idle','','']
        session=JtagSession(command=cmd);link=JtagDisplayLink(session=session)
        try:
            with self.assertRaises(BoardReset):link.send(DisplayState())
            link.send(DisplayState())
            self.assertEqual(link.sequence,5)
        finally:link.close()

    def test_device_discovery_skips_hps_for_runtime(self):
        from jtag_link import JtagSession
        import shutil
        root=Path(__file__).resolve().parents[1];tcl=shutil.which('tclsh')
        if not tcl:self.skipTest('tclsh not installed')
        cmd=[tcl,str(root/'sim/mock_quartus.tcl'),str(root/'Host/jtag_server.tcl'),'devices','','']
        session=JtagSession(command=cmd,mode='devices')
        try:
            session.wait_for('JTAG_END')
            self.assertTrue(any('JTAG_CABLE 0' in line for line in session.log))
            self.assertTrue(any('5CSEMA5' in line for line in session.log))
        finally:session.close()

if __name__=='__main__':unittest.main()
