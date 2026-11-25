`timescale 1ns/1ps
module tb_keyboard_cpu;
 reg clk=0,reset=1,psclk=1,psdat=1,tick=0;
 always #10 clk=~clk;
 wire [7:0] scan,code;wire scan_valid,frame_error,pressed,key_valid;
 wire [4:0] command;
 PS2Keyboard keyboard(clk,reset,psclk,psdat,scan,scan_valid,frame_error,code,pressed);
 KeyboardCommands decode(code,pressed,key_valid,command);
 wire [14:0] pc;wire [15:0] ir,a,b,alu,rv,addr,wd,rd,fid,count;
 wire [2:0] state;wire [4:0] flags;wire ren,wen,done,error;
 wire [247:0] ui;wire [959:0] cars;
 CPU_Part1 cpu(clk,reset,4'd0,rv,pc,ir,state,a,b,alu,flags,addr,wd,ren,wen,rd);
 traffic_io io(clk,reset,tick,addr,wd,ren,wen,rd,key_valid,command,1'b0,ui,cars,done,error,fid,count);
 always @(negedge clk)if(reset)tick<=0;else tick<=io.commit_pending && !tick;
 task bit_ps2;input value;
  begin psdat=value;psclk=1;repeat(30)@(negedge clk);psclk=0;repeat(30)@(negedge clk);psclk=1;end
 endtask
 task send_key;input [7:0] value;integer i;
  begin bit_ps2(0);for(i=0;i<8;i=i+1)bit_ps2(value[i]);bit_ps2(~^value);bit_ps2(1);psdat=1;repeat(100)@(negedge clk);end
 endtask
 task frames;input integer n;integer target;
  begin target=count+n;while(count<target)@(negedge clk);end
 endtask
 initial begin
  #45;reset=0;frames(2);
  if(ui[7:0]!=0)$fatal(1,"not idle after boot");
  send_key(8'h16);frames(3);
  if(ui[7:0]!=1 || cpu.memory.ram[16'h6002]!=1)$fatal(1,"Run did not execute in CPU");
  send_key(8'h31);send_key(8'h2c);frames(3);
  if(cpu.memory.ram[16'h600D]!=0 || cpu.memory.ram[16'h600E]!=1)$fatal(1,"N/T mapping");
  send_key(8'h4B);frames(3);
  if(cpu.memory.ram[16'h600E]!=0)$fatal(1,"left edit did not execute");
  send_key(8'h1B);frames(3);
  if(cpu.memory.ram[16'h6019]!=1 || cpu.memory.ram[16'h601A]!=1)$fatal(1,"S must be south; T must be straight");
  send_key(8'h4D);send_key(8'h1D);frames(3);
  if(cpu.memory.ram[16'h6019]!=3 || cpu.memory.ram[16'h601B]!=1)$fatal(1,"P/W crossing request");
  send_key(8'h1C);frames(3);
  if(ui[33:32]!=0 || ui[41:40]!=0 || ui[98:96]!=1)$fatal(1,"CPU ambulance clearance");
  send_key(8'h22);frames(3);
  if(!ui[108] || ui[33:32]!=0 || ui[41:40]!=0)$fatal(1,"fault must be all red");
  send_key(8'h76);frames(3);
  if(ui[108])$fatal(1,"CPU fault release");
  send_key(8'h1E);frames(3);if(ui[7:0]!=2)$fatal(1,"Pause");
  send_key(8'h26);frames(3);if(ui[7:0]!=3)$fatal(1,"Reset");
  if(frame_error || error)$fatal(1,"PS2/peripheral error");
  $display("PASS: real PS2 receiver -> Lab4 firmware: Run, N/T/L, South, P/W, emergency, Esc, Pause, Reset");$finish;
 end
 initial begin #200000000;$fatal(1,"keyboard test timeout");end
endmodule
