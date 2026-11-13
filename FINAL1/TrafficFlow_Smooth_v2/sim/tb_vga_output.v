`timescale 1ns/1ps
module tb_vga_output;
 reg clk=0;reg [0:0] key=0;
 wire [7:0] r,g,b;wire hs,vs,pc,blank,sync;
 wire [9:0] leds;
 reg [26:0] expected,previous;
 reg falling;
 integer i;
 always #10 clk=~clk;
 demo_VGA_Python dut(clk,key,3'b0,1'b1,1'b1,leds,r,g,b,hs,vs,pc,blank,sync);
 initial begin
  #25;key=1;
  for(i=0;i<1700;i=i+1)begin
   @(posedge clk);
   falling=pc;
   expected={dut.raw_r,dut.raw_g,dut.raw_b,dut.raw_hs,dut.raw_vs,dut.visible};
   previous={r,g,b,hs,vs,blank};
   #1;
   if(falling && {r,g,b,hs,vs,blank}!==expected)$fatal(1,"RGB/sync/blank pixel skew");
   if(!falling && {r,g,b,hs,vs,blank}!==previous)$fatal(1,"pixel changed at DAC rising edge");
   if((^{r,g,b,hs,vs,blank})===1'bx)$fatal(1,"unknown registered pixel");
  end
  $display("PASS: registered RGB/sync/blank match and remain stable at DAC sampling edge");$finish;
 end
endmodule
