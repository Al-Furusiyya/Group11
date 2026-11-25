`timescale 1ns/1ps
// Compare actual Lab4 register/flag retirement with the independent ISA runner.
module tb_cpu_trace;
 reg clk=0,reset=1;always #10 clk=~clk;
 wire [14:0] pc;wire [15:0] ir,a,b,alu,rv,addr,wd,rd,fid,count;
 wire [2:0] state;wire [4:0] flags;wire ren,wen,done,error;
 wire [247:0] ui;wire [959:0] cars;
 CPU_Part1 cpu(clk,reset,4'd0,rv,pc,ir,state,a,b,alu,flags,addr,wd,ren,wen,rd);
 traffic_io io(clk,reset,1'b0,addr,wd,ren,wen,rd,1'b0,5'd0,1'b1,ui,cars,done,error,fid,count);
 integer file,got,rows=0,i;reg retire;
 reg [15:0] expected_pc,expected_flags,expected_registers[0:15];
 initial begin file=$fopen("sim/build/trace.txt","r");if(!file)$fatal(1,"Run the ISA test first");#45;reset=0;end
 always @(posedge clk)begin
  retire=!reset && (state==3 || state==5 || state==6 || state==7);
  #1;
  if(retire)begin
   got=$fscanf(file,"%h %h",expected_pc,expected_flags);
   if(got!=2)$fatal(1,"missing trace row %0d",rows);
   for(i=0;i<16;i=i+1)begin
    got=$fscanf(file,"%h",expected_registers[i]);
    if(got!=1)$fatal(1,"bad trace register");
    if(cpu.datapath.register_file.registers[i]!==expected_registers[i])
     $fatal(1,"ISA mismatch retirement=%0d R%0d actual=%h expected=%h pc=%h",rows,i,cpu.datapath.register_file.registers[i],expected_registers[i],pc);
   end
   if(pc!==expected_pc[14:0] || flags!==expected_flags[4:0])
    $fatal(1,"PC/flag mismatch retirement=%0d pc=%h expected=%h flags=%h expected=%h",rows,pc,expected_pc,flags,expected_flags);
   if(error)$fatal(1,"CPU peripheral error");
   rows=rows+1;
   if(rows==20000)begin $display("PASS: 20000 actual Lab4 instruction retirements match independent ISA registers, flags and PC");$finish;end
  end
 end
 initial begin #10000000;$fatal(1,"trace timeout");end
endmodule
