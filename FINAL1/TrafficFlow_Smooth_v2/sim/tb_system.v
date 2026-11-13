`timescale 1ns/1ps
// Full FPGA top: scans -> CDC -> packet validation -> real Lab4 instructions
// -> memory-mapped stores -> blanking commit -> scan reply; PS/2 goes via CPU.
module tb_system;
 reg clk=0;reg [0:0] key=0;reg psclk=1,psdata=1,frame=0;
 reg tck=0,tdi=0;reg [1:0] ir=0;reg cdr=0,sdr=0,udr=0;
 wire [9:0] leds;wire [7:0] r,g,b;wire hs,vs,pclk,blank,sync;
 reg [287:0] packets[0:6],banks[0:14];reg [247:0] expected[0:1];reg [247:0] initial_state;
 reg [799:0] expected_cars[0:1],initial_cars;
 reg [191:0] response;integer i,n,stores=0,commits=0,keys=0,reply_file;
 always #10 clk=~clk;
 demo_VGA_Python dut(clk,key,3'd0,psclk,psdata,leds,r,g,b,hs,vs,pclk,blank,sync);
 always @(posedge clk)begin
  if(dut.io_write && dut.io_address>=10'h3d0 && dut.io_address<=10'h3df)stores=stores+1;
  if(dut.state_valid)commits=commits+1;
  if(dut.uplink_key_valid)keys=keys+1;
 end
 task check;
  input condition;input [799:0] message;
  begin if(condition!==1'b1)begin $display("FAIL: %0s",message);$finish;end end
 endtask
 task tick;
  begin #17;tck=1;#17;tck=0;end
 endtask
 task send_packet;
  input [287:0] value;integer k;
  begin
   ir=1;cdr=1;tick;cdr=0;sdr=1;
   tdi=0;tick; // upstream/downstream physical BYPASS padding
   for(k=0;k<288;k=k+1)begin tdi=value[k];tick;end
   sdr=0;udr=1;tick;udr=0;
  end
 endtask
 task read_reply;
  integer k;
  begin
   ir=2;cdr=1;tick;cdr=0;sdr=1;
   for(k=0;k<192;k=k+1)begin response[k]=dut.tdo;tick;end
   sdr=0;udr=1;tick;udr=0;
  end
 endtask
 task await_reply;
  input [7:0] seq;integer tries;
  begin
   tries=0;read_reply;
   while((response[184] || !response[185] || response[23:16]!=seq) && tries<20)begin
    read_reply;tries=tries+1;
   end
   check(!response[184] && response[185] && response[23:16]==seq,"matching completed reply");
   check(response[15:0]==16'h474a && response[183:176]==3,"reply signature/version");
   $fwrite(reply_file,"%048h\n",response);
  end
 endtask
 task wait_cpu_copy;
  integer cycles;
  begin
   cycles=0;
   while(!dut.peripherals.commit_pending && cycles<5000)begin @(negedge clk);cycles=cycles+1;end
   check(dut.peripherals.commit_pending,"Lab4 CPU copied state and issued COMMIT");
  end
 endtask
 task commit_frame;
  begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(10)@(negedge clk);end
 endtask
 task ps_bit;
  input value;
  begin psdata=value;#10000;psclk=0;#20000;psclk=1;#10000;end
 endtask
 task ps_byte;
  input [7:0] value;integer k;
  begin
   ps_bit(0);for(k=0;k<8;k=k+1)ps_bit(value[k]);ps_bit(~(^value));ps_bit(1);
   psdata=1;#60000;
  end
 endtask
 task snapshot;
  input integer base;
  input check_keys;
  integer bank_no,previous_frames;
  reg [247:0] old_state;
  reg [799:0] old_cars;
  begin
   old_state=dut.state;old_cars=dut.cars;previous_frames=dut.peripherals.frame_count;
   for(bank_no=0;bank_no<5;bank_no=bank_no+1)begin
    send_packet(banks[base+bank_no]);
    if(bank_no==4)begin
     wait_cpu_copy;
     check(dut.state===old_state && dut.cars===old_cars,"all twenty sprites wait for final blanking");
     commit_frame;
    end
    await_reply(banks[base+bank_no][31:24]);
    check(response[31:24]==0,"bank acknowledged through CPU");
    if(bank_no<4)begin
     check(dut.state===old_state && dut.cars===old_cars,"partial banks never reach VGA");
     check(dut.peripherals.frame_count==previous_frames,"partial banks do not increment display count");
    end
    if(check_keys && bank_no==0)
     check(response[39:32]==2 && response[47:40]==5 && response[55:48]==9,"S/T events returned in first bank reply");
   end
   check(dut.peripherals.frame_count==previous_frames+1,"five banks commit one frame");
  end
 endtask
 initial begin
  force dut.jtag_port.tap.tck=tck;force dut.jtag_port.tap.tdi=tdi;
  force dut.jtag_port.tap.ir_in=ir;force dut.jtag_port.tap.virtual_state_cdr=cdr;
  force dut.jtag_port.tap.virtual_state_sdr=sdr;force dut.jtag_port.tap.virtual_state_udr=udr;
  force dut.frame_tick=frame;
  $readmemh("sim/frames.hex",packets);$readmemh("sim/banks.hex",banks);
  $readmemh("sim/expected.hex",expected);$readmemh("sim/expected_cars.hex",expected_cars);
  reply_file=$fopen("sim/replies.hex","w");
  #100;key=1;repeat(10)@(negedge clk);
  initial_state=dut.state;
  send_packet(packets[0]);await_reply(7);
  check(response[31:24]==3 && !dut.received_valid,"running packet blocked after KEY0");
  snapshot(0,0);
  check(!dut.link.reset_pending && dut.cars==0,"idle snapshot acknowledges KEY0 and clears all cars");
  repeat(10)@(negedge clk);stores=0;commits=0;
  force dut.cpu.control.state=3'd0;repeat(10)@(negedge clk);
  initial_cars=dut.cars;
  send_packet(banks[5]);repeat(300)@(negedge clk);
  check(dut.received_valid,"packet reached CPU mailbox");
  commit_frame;read_reply;
  check(dut.cars===initial_cars && response[184] && stores==0,"CPU held: no bypass and no ACK");
  release dut.cpu.control.state;
  await_reply(37);
  check(stores==16 && dut.cars===initial_cars,"first bank copied by CPU but not displayed");
  for(n=1;n<5;n=n+1)begin
   send_packet(banks[5+n]);
   if(n==4)begin wait_cpu_copy;check(dut.cars===initial_cars,"final bank staged");commit_frame;end
   await_reply(37+n);
   check(response[31:24]==0,"remaining bank accepted");
   if(n<4)check(dut.cars===initial_cars,"no partial display");
  end
  check(stores==80 && commits==5,"sixteen CPU stores per bank, five bank ACKs");
  check(dut.state===expected[0] && dut.cars===expected_cars[0],"all twenty car records match Python");
  send_packet(packets[1]);await_reply(8);
  check(response[31:24]==1 && stores==80,"bad CRC rejected before CPU access");
  send_packet(packets[2]);await_reply(9);
  check(response[31:24]==2 && stores==80,"bad coordinates rejected before CPU access");
  send_packet(packets[6]);await_reply(12);
  check(response[31:24]==2 && stores==80,"out-of-order bank rejected before CPU access");
  snapshot(10,0);
  check(stores==160 && dut.state===expected[1] && dut.cars===expected_cars[1],"second complete twenty-car snapshot");
  // Actual keyboard wires: held S repeats once, then T.
  ps_byte(8'h1b);ps_byte(8'h1b);ps_byte(8'hf0);ps_byte(8'h1b);
  ps_byte(8'h2c);ps_byte(8'hf0);ps_byte(8'h2c);
  repeat(1000)@(negedge clk);
  check(keys==2,"CPU forwards distinct S/T events");
  snapshot(5,1);
  check(stores==240 && commits==15 && dut.peripherals.frame_count==4,"80 CPU stores per complete display update");
  check(dut.cars===expected_cars[0],"twenty cars updated after PS2 traffic");
  // Restart a partially received snapshot at bank zero without displaying it.
  send_packet(banks[10]);await_reply(42);
  check(dut.cars===expected_cars[0],"abandoned bank remains invisible");
  snapshot(5,0);
  check(dut.cars===expected_cars[0],"bank zero restarts assembly safely");
  // Partial banks are also discarded by physical reset.
  send_packet(banks[10]);await_reply(42);
  key=0;#100;
  check(dut.state===initial_state && dut.cars==0 && dut.peripherals.staged_cars==0,"KEY0 clears all twenty cars and partial banks");
  check(dut.cpu_pc==0 && !dut.received_valid && !dut.peripherals.commit_pending,"KEY0 resets CPU and pending transfers");
  $fclose(reply_file);
  $display("PASS: JTAG scans -> actual Lab4 CPU -> five banks -> atomic twenty-car VGA commit");
  $display("PASS: stall, CRC/range/order, restart, PS2 forwarding and KEY0 reset");
  $finish;
 end
 initial begin #30000000;$display("FAIL: full-system watchdog");$finish;end
endmodule
