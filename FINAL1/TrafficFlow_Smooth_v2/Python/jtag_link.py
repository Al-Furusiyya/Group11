"""Python -> quartus_stp -> USB-Blaster -> Virtual JTAG -> Lab4 CPU.
Uses only Python's standard library. No serial port or UART adapter is used.
"""
from collections import deque
from pathlib import Path
import os
import queue
import shutil
import subprocess
import threading
import time
from protocol import encode_frame,crc8,BANK_COUNT

ROOT=Path(__file__).resolve().parents[1]

def find_quartus_stp(explicit=None):
    if explicit:
        path=Path(explicit)
        if path.is_file():return str(path.resolve())
        found=shutil.which(explicit)
        if found:return found
        raise FileNotFoundError(f'quartus_stp not found: {explicit}')
    found=shutil.which('quartus_stp')
    if found:return found
    candidates=[]
    for var in ['QUARTUS_ROOTDIR','QUARTUS_ROOTDIR_OVERRIDE']:
        if os.environ.get(var):
            root=Path(os.environ[var]);candidates += [root/'bin64/quartus_stp.exe',root/'bin/quartus_stp.exe']
    for base in ['C:/altera_lite','C:/intelFPGA_lite','C:/intelFPGA','C:/altera']:
        root=Path(base)
        candidates += [root/'quartus/bin64/quartus_stp.exe',root/'quartus/bin/quartus_stp.exe']
        if root.is_dir():
            candidates += sorted(root.glob('*/quartus/bin64/quartus_stp.exe'),reverse=True)
            candidates += sorted(root.glob('*/quartus/bin/quartus_stp.exe'),reverse=True)
    for path in candidates:
        if path.is_file():return str(path)
    raise FileNotFoundError('Cannot find quartus_stp.exe. Use --quartus-stp "C:\\path\\quartus\\bin64\\quartus_stp.exe".')

class BoardReset(RuntimeError):
    """Board requires an idle snapshot after physical KEY0 reset."""


class JtagSession:
    def __init__(self,quartus_stp=None,cable='',device='',mode='serve',*,command=None):
        args=command or [find_quartus_stp(quartus_stp),'-t',str(ROOT/'Host/jtag_server.tcl'),mode,str(cable),str(device)]
        self.lines=queue.Queue();self.log=deque(maxlen=30)
        self.process=subprocess.Popen(args,stdin=subprocess.PIPE,stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,text=True,bufsize=1,
            env={**os.environ, 'TBB_MALLOC_DISABLE_REPLACEMENT':'1'})
        self.thread=threading.Thread(target=self._read,daemon=True);self.thread.start()
        self.description=''
        if mode=='serve':
            try:self.description=self.wait_for('JTAG_READY',30)
            except BaseException:self.close();raise
    def _read(self):
        try:
            for line in self.process.stdout:self.lines.put(line.rstrip('\r\n'))
        finally:self.lines.put(None)
    def wait_for(self,tag,timeout=8):
        deadline=time.monotonic()+timeout
        while True:
            remaining=deadline-time.monotonic()
            if remaining<=0:raise TimeoutError('Timed out waiting for '+tag+'. '+ '\n'.join(self.log))
            try:line=self.lines.get(timeout=remaining)
            except queue.Empty:raise TimeoutError('Timed out waiting for '+tag+'. '+'\n'.join(self.log)) from None
            if line is None:raise RuntimeError('Quartus JTAG process stopped. '+'\n'.join(self.log))
            self.log.append(line)
            if line.startswith('JTAG_RESET '):raise BoardReset('KEY0 reset: press 1 to run again.')
            if line.startswith('JTAG_ERROR '):raise RuntimeError(line[len('JTAG_ERROR '):])
            if line.startswith(tag+' '):return line[len(tag)+1:]
    def exchange(self,sequence,packet):
        # Quartus hex strings represent a register value. Byte zero is at the
        # least significant end, so it is shifted first (LSB-first JTAG).
        self.process.stdin.write(f'FRAME {sequence} {packet[::-1].hex()}\n');self.process.stdin.flush()
        raw=self.wait_for('JTAG_REPLY',12)
        try:return int(raw,16).to_bytes(24,'little')
        except (ValueError,OverflowError):raise RuntimeError('Invalid JTAG reply encoding') from None
    def close(self):
        process=getattr(self,'process',None)
        if process is None:return
        try:
            if process.poll() is None:
                try:process.stdin.write('QUIT\n');process.stdin.flush()
                except (OSError,ValueError):pass
                try:process.wait(timeout=2)
                except subprocess.TimeoutExpired:process.kill();process.wait(timeout=2)
        finally:
            self.thread.join(timeout=1)
            for stream in (process.stdin,process.stdout):
                if stream:
                    try:stream.close()
                    except OSError:pass
            self.process=None
    @classmethod
    def devices(cls,quartus_stp=None):
        session=cls(quartus_stp,mode='devices')
        try:
            session.wait_for('JTAG_END',30)
            return [line for line in session.log if line.startswith(('JTAG_CABLE ','JTAG_DEVICE '))]
        finally:session.close()

class JtagDisplayLink:
    def __init__(self,quartus_stp=None,cable='',device='',*,session=None):
        self.session=session or JtagSession(quartus_stp,cable,device)
        self.sequence=0;self.keys=deque()
    def send(self,state):
        # Validate the entire snapshot before sending any bank. Bank 4 commits
        # all twenty cars together at VGA blanking; banks 0..3 only stage data.
        packets=[encode_frame(state,(self.sequence+bank)&255,bank) for bank in range(BANK_COUNT)]
        for packet in packets:
            self._send_packet(packet)
    def _send_packet(self,packet):
        sequence=self.sequence
        reply=self.session.exchange(sequence,packet)
        if len(reply)!=24 or reply[:2]!=b'JG' or reply[22]!=3:
            raise RuntimeError('Wrong JTAG image or instance. Program the NEW Lab4/JTAG .sof and press KEY0.')
        if reply[23]&1 or not reply[23]&2 or reply[2]!=sequence:
            raise RuntimeError('JTAG response is not a completed matching CPU update.')
        if crc8(reply[:21])!=reply[21]:raise RuntimeError('JTAG reply CRC mismatch')
        if reply[3]==3:
            self.sequence=(sequence+1)&255
            raise BoardReset('KEY0 reset: press 1 to run again.')
        if reply[3]:raise RuntimeError(f'FPGA rejected packet (code {reply[3]}).')
        if reply[23]&12:raise RuntimeError('Keyboard FIFO overflow or malformed scan. Press KEY0 and restart.')
        count=reply[4]
        if count>16 or any(not 1<=k<=16 for k in reply[5:5+count]):
            raise RuntimeError('Invalid keyboard reply fields')
        self.keys.extend(reply[5:5+count]);self.sequence=(sequence+1)&255
    def commands(self):
        result=list(self.keys);self.keys.clear();return result
    def close(self):self.session.close()
