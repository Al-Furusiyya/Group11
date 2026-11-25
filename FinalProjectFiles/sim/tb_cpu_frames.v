`timescale 1ns/1ps
// The CPU calculates each frame here. There is no traffic-controller module.
module tb_cpu_frames;
 reg clk=0,reset=1,tick=0,kv=0,cpu_enable=1,auto_run=0;
 reg [4:0] command=0;always #10 clk=~clk;
 wire cpu_clk=clk && cpu_enable;
 wire [14:0] pc;wire [15:0] ir,a,b,alu,rv,addr,wd,rd,fid,count;
 wire [2:0] state;wire [4:0] flags;wire ren,wen,done,error;
 wire [247:0] ui;wire [959:0] cars;
 CPU_Part1 cpu(cpu_clk,reset,4'd0,rv,pc,ir,state,a,b,alu,flags,addr,wd,ren,wen,rd);
 traffic_io io(clk,reset,tick,addr,wd,ren,wen,rd,kv,command,auto_run,ui,cars,done,error,fid,count);
 reg [15:0] golden[0:2815];
 reg [71:0] written_cars=0;reg [15:0] written_ui=0;
 reg [247:0] previous_ui=0;reg [959:0] previous_cars=0;reg [15:0] previous_count=0;
 reg allowed;integer cycles=0,last_commit=0,peak=0,f,i,index;
 always @(posedge clk)begin
  allowed=tick;
  if(!reset)begin
   cycles=cycles+1;
   if(wen && addr>=16'hFF40 && addr<16'hFF88)written_cars[addr-16'hFF40]=1;
   if(wen && addr>=16'hFF10 && addr<=16'hFF1F)written_ui[addr-16'hFF10]=1;
   if(wen && addr==16'hFF20)begin
    if(written_cars!==72'hFFFFFFFFFFFFFFFFFF || written_ui!==16'hFFFF)$fatal(1,"CPU did not write a whole frame");
    if(cycles-last_commit>840000)$fatal(1,"CPU missed the native VGA budget");
    if(cycles-last_commit>peak)peak=cycles-last_commit;
   end
  end
  #1;
  if(!reset)begin
   if(count!=previous_count)begin
    if(!allowed)$fatal(1,"display changed outside blanking");
    written_cars=0;written_ui=0;last_commit=cycles;
   end else if(ui!==previous_ui || cars!==previous_cars)$fatal(1,"partial display update");
   if(error)$fatal(1,"peripheral error");
  end else begin written_cars=0;written_ui=0;last_commit=cycles;end
  previous_ui=ui;previous_cars=cars;previous_count=count;
 end
 task key;input [4:0] c;
  begin @(negedge clk);command=c;kv=1;@(negedge clk);kv=0;end
 endtask
 task commit_frame;input integer expected_frame;
  integer wait_cycles;reg [255:0] padded;
  begin
   wait_cycles=0;
   while(!io.commit_pending)begin @(negedge clk);wait_cycles=wait_cycles+1;if(wait_cycles>840000)$fatal(1,"no CPU commit");end
   @(negedge clk);tick=1;@(negedge clk);tick=0;
   padded={8'd0,ui};
   for(i=0;i<16;i=i+1)if(padded[i*16+:16]!==golden[(expected_frame-1)*88+i])$fatal(1,"CPU UI mismatch frame=%0d word=%0d actual=%h expected=%h",expected_frame,i,padded[i*16+:16],golden[(expected_frame-1)*88+i]);
   for(i=0;i<24;i=i+1)begin
    index=(expected_frame-1)*88+16+i*3;
    if(cars[i*40+:16]!==golden[index] || cars[i*40+16+:16]!==golden[index+1] || {8'd0,cars[i*40+32+:8]}!==golden[index+2])
     $fatal(1,"CPU sprite mismatch frame=%0d slot=%0d",expected_frame,i);
   end
  end
 endtask
 initial begin
  $readmemh("sim/build/frames.hex",golden);#45;reset=0;key(1);
  for(f=1;f<=32;f=f+1)begin
   if(f==5)begin key(4);key(9);end
   if(f==10)key(2);
   if(f==13)key(1);
   if(f==25)key(3);
   if(f==28)key(1);
   commit_frame(f);
  end
  $display("PASS: 32 complete CPU-generated frames match ISA reference; all 88 display words; atomic blanking commits");
  $display("PASS: measured RTL work fits native frame budget; peak=%0d / 840000 CLOCK_50 cycles",peak);
  while(state!=0)@(negedge clk);
  cpu_enable=0;
  repeat(10)begin repeat(50)@(negedge clk);tick=1;@(negedge clk);tick=0;end
  if(count!=32 || fid!=42)$fatal(1,"CPU-stop/frame-counter separation failed");
  $display("PASS: stopping the CPU stops traffic updates while the peripheral/video frame counter continues");
  reset=1;cpu_enable=1;auto_run=1;repeat(4)@(negedge clk);reset=0;
  commit_frame(1);commit_frame(2);
  $display("PASS: physical reset and SW0 start reproduce clean firmware startup");$finish;
 end
 initial begin #200000000;$fatal(1,"frame test timeout");end
endmodule
