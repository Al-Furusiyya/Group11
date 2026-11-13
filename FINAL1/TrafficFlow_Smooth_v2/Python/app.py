"""Run from the project root: python Python/app.py devices | check | run."""
import argparse
import queue
import threading
import time
from protocol import DisplayState
from jtag_link import JtagDisplayLink,JtagSession,BoardReset
from control import Controller

KEYS={'1':1,'2':2,'3':3,'n':4,'s':5,'e':6,'w':7,'l':8,'left':8,
      't':9,'straight':9,'up':9,'space':9,'r':10,'right':10,'p':11,
      'a':12,'f':13,'c':14,'b':15,'esc':16,'escape':16}

def console_input(commands):
    while True:
        try:text=input()
        except EOFError:return
        text=text.strip().lower()
        if text in ('q','quit','exit'):commands.put(None);return
        tokens=text.split()
        if tokens and all(token in KEYS for token in tokens):
            for token in tokens:commands.put(KEYS[token])
        else:print('Use 1/2/3, n/s/e/w then l/t/r, p then direction, a/f/c/b, esc, or quit; Enter to send.')

def main():
    parser=argparse.ArgumentParser(description='Python controls the logic; FPGA draws VGA.')
    parser.add_argument('action',choices=['devices','check','run'])
    parser.add_argument('--quartus-stp',help='optional full path to quartus_stp.exe')
    parser.add_argument('--cable',default='',help='cable index from devices, or unique name substring')
    parser.add_argument('--device',default='',help='JTAG device index from devices, or unique name substring')
    parser.add_argument('--auto-run',action='store_true',help='start in RUN without typing 1')
    parser.add_argument('--demo',action='store_true',help='compatibility alias; the full traffic simulation always animates')
    args=parser.parse_args()
    if args.action=='devices':
        lines=JtagSession.devices(args.quartus_stp)
        if not lines:print('No USB-Blaster/JTAG cable detected.')
        for line in lines:print(line)
        return
    link=JtagDisplayLink(args.quartus_stp,args.cable,args.device)

    try:
        if args.action=='check':
            link.send(DisplayState())
            print('PASS: Python -> USB-Blaster/JTAG -> Lab4 CPU -> VGA frame commit -> acknowledgement.')
            return
        # A known idle frame completes the physical-reset handshake.
        link.send(DisplayState())
        controller=Controller()
        if args.auto_run:controller.handle(1)
        commands=queue.Queue()
        threading.Thread(target=console_input,args=(commands,),daemon=True).start()
        print('Ready. PS/2: 1 RUN, 2 PAUSE, 3 RESET. Console commands need Enter; quit closes.')
        print('N/S/E/W selects travel direction; L/T/R chooses L/S/R on screen. P then direction crosses. A/F/C/B emergency; same key or Esc releases.')
        previous=time.monotonic()
        running=True
        while running:
            start=time.monotonic()
            dt=min(0.1,start-previous);previous=start
            for command in link.commands():controller.handle(command)
            while not commands.empty():
                command=commands.get_nowait()
                if command is None:running=False;break
                controller.handle(command)
            if not running:break
            try:
                link.send(controller.update(dt))
            except BoardReset as error:
                controller.reset()
                while not commands.empty():commands.get_nowait()
                link.send(controller.state)
                print(error)
            time.sleep(max(0.0,1/30-(time.monotonic()-start)))
    finally:
        if args.action=='run':
            try:link.send(DisplayState())
            except (OSError,TimeoutError,RuntimeError):pass
        link.close()

if __name__=='__main__':
    try:main()
    except KeyboardInterrupt:print('\nStopped.')
    except (OSError,TimeoutError,RuntimeError) as e:raise SystemExit(str(e))
