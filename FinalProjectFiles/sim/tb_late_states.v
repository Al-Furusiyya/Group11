`timescale 1ns/1ps
// Cold boot is covered separately. These RAM checkpoints bring the real CPU
// straight to later traffic states so we can cross-check turns/WALK efficiently.
module tb_late_states;
 reg clk=0,reset=1,tick=0,kv=0;reg [4:0] command=0;
 always #10 clk=~clk;
 wire [14:0] pc;wire [15:0] ir,a,b,alu,rv,addr,wd,rd,fid,count;
 wire [2:0] state;wire [4:0] flags;wire ren,wen,done,error;
 wire [247:0] ui;wire [959:0] cars;
 CPU_Part1 cpu(clk,reset,4'd0,rv,pc,ir,state,a,b,alu,flags,addr,wd,ren,wen,rd);
 traffic_io io(clk,reset,tick,addr,wd,ren,wen,rd,kv,command,1'b0,ui,cars,done,error,fid,count);
 reg [15:0] data[0:34336];reg [255:0] padded;
 integer c,f,i,base,expected,wait_cycles,main_pc,file,got;
 reg [255:0] label_name;reg [15:0] address;
 initial begin
  $readmemh("sim/build/checkpoints.hex",data);
  if(data[0]!=32)$fatal(1,"checkpoint fixture count");
  file=$fopen("firmware/symbols.txt","r");main_pc=-1;
  while(!$feof(file))begin
   got=$fscanf(file,"%s %h",label_name,address);
   if(got==2 && label_name=="main_poll")main_pc=address;
  end
  $fclose(file);if(main_pc<0)$fatal(1,"main_poll symbol missing");
  for(c=0;c<32;c=c+1)begin
   @(negedge clk);reset=1;tick=0;kv=0;repeat(3)@(negedge clk);
   base=1+c*1073;
   for(i=0;i<896;i=i+1)cpu.memory.ram[16'h6000+i]=data[base+1+i];
   cpu.memory.ram[16'h6F00]=16'hFFFF;
   cpu.program_counter.pc=main_pc;
   cpu.datapath.register_file.registers[13]=16'h7F00;
   reset=0;
   if(data[base]!=0)begin command=data[base][4:0];kv=1;@(negedge clk);kv=0;end
   for(f=0;f<2;f=f+1)begin
    wait_cycles=0;
    while(!io.commit_pending)begin @(negedge clk);wait_cycles=wait_cycles+1;if(wait_cycles>840000)$fatal(1,"late-state CPU deadline case=%0d",c);end
    @(negedge clk);tick=1;@(negedge clk);tick=0;
    padded={8'd0,ui};expected=base+897+f*88;
    for(i=0;i<16;i=i+1)if(padded[i*16+:16]!==data[expected+i])$fatal(1,"late-state UI case=%0d frame=%0d word=%0d",c,f,i);
    for(i=0;i<24;i=i+1)begin
     if(cars[i*40+:16]!==data[expected+16+i*3] || cars[i*40+16+:16]!==data[expected+17+i*3] || {8'd0,cars[i*40+32+:8]}!==data[expected+18+i*3])
      $fatal(1,"late-state sprite case=%0d frame=%0d slot=%0d",c,f,i);
    end
    if(error)$fatal(1,"late-state peripheral error");
   end
  end
  $display("PASS: actual Lab4 RTL matches 32 executed-firmware checkpoints over 64 late frames, including rolling service crossings and far-side boarding");$finish;
 end
 initial begin #200000000;$fatal(1,"late-state timeout");end
endmodule
