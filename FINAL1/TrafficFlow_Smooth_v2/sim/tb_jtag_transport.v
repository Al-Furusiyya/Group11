`timescale 1ns/1ps
// Transport-only checks. tb_system separately exercises the real CPU/firmware.
module tb_jtag_transport;
 reg clk=0,reset=0,tck=0,tdi=0,cdr=0,sdr=0,udr=0;
 reg [1:0] ir=0;
 reg allow_ack=1;
 wire received_valid; wire [247:0] received_state;wire tdo,error;
 wire cpu_done=allow_ack && received_valid;
 reg [287:0] packets[0:6];reg [191:0] reply;
 integer i;
 always #10 clk=~clk;
 jtag_display_link dut(clk,reset,cpu_done,1'b0,5'd0,tck,tdi,ir,cdr,sdr,udr,
                      tdo,received_state,received_valid,error);
 task tick;begin #17;tck=1;#17;tck=0;end endtask
 task check;
  input ok;input [799:0] message;
  begin if(ok!==1'b1)begin $display("FAIL: %0s",message);$finish;end end
 endtask
 task reset_link;
  begin ir=0;cdr=0;sdr=0;udr=0;reset=1;#100;reset=0;#100;end
 endtask
 task send;
  input [287:0] packet;input integer padding,length;integer k;
  begin
   ir=1;cdr=1;tick;cdr=0;sdr=1;
   for(k=0;k<padding;k=k+1)begin tdi=k[0];tick;end
   for(k=0;k<length;k=k+1)begin tdi=packet[k];tick;end
   sdr=0;udr=1;tick;udr=0;
  end
 endtask
 task read_reply;
  integer k;
  begin
   ir=2;cdr=1;tick;cdr=0;sdr=1;
   for(k=0;k<192;k=k+1)begin reply[k]=tdo;tick;end
   sdr=0;udr=1;tick;udr=0;
  end
 endtask
 task await_reply;
  input [7:0] sequence;integer attempts;
  begin
   attempts=0;read_reply;
   while((reply[184] || !reply[185] || reply[23:16]!=sequence) && attempts<20)begin
    read_reply;attempts=attempts+1;
   end
   check(!reply[184] && reply[185] && reply[23:16]==sequence,"completed matching response");
   check(reply[15:0]==16'h474a && reply[183:176]==3,"reply magic/version");
  end
 endtask
 initial begin
  $readmemh("sim/frames.hex",packets);
  reset_link;
  send(packets[0],0,288);await_reply(7);
  check(reply[31:24]==3 && !received_valid,"KEY0 blocks running snapshots");
  for(i=0;i<3;i=i+1)begin
   reset_link;
   send(packets[5],i,288);await_reply(6);
   check(reply[31:24]==0 && !reply[187],"idle handshake accepts 0/1/2 padding clocks");
   send(packets[0],i,288);await_reply(7);
   check(reply[31:24]==0 && !reply[187],"payload retained despite padding");
   check(received_state==packets[0][279:32],"received display payload matches");
  end
  reset_link;send(packets[5],0,287);read_reply;
  check(reply[188] && !reply[187],"interrupted reset scan is recoverable");
  send(packets[5],0,288);await_reply(6);
  send(packets[0],0,287);read_reply;
  check(reply[187] && !received_valid,"short scan rejected");
  reset_link;allow_ack=0;
  send(packets[5],0,288);#1000;
  check(received_valid,"first request awaits CPU");
  send(packets[0],0,288);read_reply;
  check(reply[187] && reply[184],"write while busy rejected");
  reset_link;allow_ack=1;
  send(packets[5],0,288);await_reply(6);
  send(packets[1],0,288);await_reply(8);
  check(reply[31:24]==1,"CRC rejection retained");
  send(packets[2],0,288);await_reply(9);
  check(reply[31:24]==2,"range rejection retained");
  send(packets[6],0,288);await_reply(12);
  check(reply[31:24]==2,"out-of-order bank rejected");
  $display("PASS: transport padding, short scan, busy, CRC, range and KEY0 handshake");
  $finish;
 end
 initial begin #2000000;$display("FAIL: transport watchdog");$finish;end
endmodule
