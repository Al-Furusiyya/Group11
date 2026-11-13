`timescale 1ns/1ps
module tb_sprite_smoother;
 reg clk=0,reset=1,tick=0,running=1;
 reg [15:0] count=0;
 reg [639:0] positions=0;
 reg [99:0] attributes=0;
 wire [639:0] drawn;
 wire [99:0] attrs;
 integer i,n;reg [15:0] before_x;
 always #10 clk=~clk;
 sprite_smoother dut(clk,reset,tick,count,running,positions,attributes,drawn,attrs);
 task settle;begin repeat(45)@(negedge clk);end endtask
 task commit;
  begin @(negedge clk);count=count+1;settle();end
 endtask
 task frame;
  begin @(negedge clk);tick=1;@(negedge clk);tick=0;settle();end
 endtask
 task expect_x;
  input integer value;
  begin if(drawn[15:0]!==value)$fatal(1,"x=%0d expected=%0d",drawn[15:0],value);end
 endtask
 initial begin
  #25;reset=0;
  for(i=0;i<20;i=i+1)begin
   positions[i*32+:16]=200+i*10;positions[i*32+16+:16]=200;
   attributes[i*5+:5]=5'b10000;
  end
  commit();
  if(drawn!==positions || attrs!==attributes)$fatal(1,"new sprites must snap");
  frame();frame();
  for(i=0;i<20;i=i+1)begin
   positions[i*32+:16]=204+i*10;positions[i*32+16+:16]=202;
  end
  commit();
  for(i=0;i<20;i=i+1)begin
   if(drawn[i*32+:16]!==202+i*10 || drawn[i*32+16+:16]!==16'd201)
    $fatal(1,"missing midpoint slot %0d",i);
  end
  frame();if(drawn!==positions)$fatal(1,"did not complete interpolation");
  frame(); // two frame cadence, same vehicle changes heading during turn
  positions[15:0]=208;attributes[1:0]=1;commit();expect_x(206);
  frame();expect_x(208);
  // Five-frame transport cadence, uniform negative motion. Round Q8 values
  // rather than throwing away fractional position at every new snapshot.
  repeat(4)frame();positions[15:0]=198;commit();expect_x(206);
  for(n=1;n<=4;n=n+1)begin frame();expect_x(206-2*n);end
  repeat(6)frame();expect_x(198); // no extrapolation on missing packets
  // Three-frame cadence uses a shared reciprocal, not rounded midpoints.
  // First resynchronize at the newly measured interval, then test exact 3.
  positions[15:0]=204;commit();
  repeat(3)frame();positions[15:0]=210;commit();
  before_x=drawn[15:0];
  frame();if(drawn[15:0]<before_x)$fatal(1,"reversed during rebase");
  frame();expect_x(210);
  // Fractional rebasing: an arriving snapshot must not discard Q8 state.
  frame();positions[15:0]=211;commit();
  frame();positions[15:0]=212;commit();
  if(drawn[15:0]<210 || drawn[15:0]>212)$fatal(1,"fractional rebase overshoot");
  positions[15:0]=400;commit();expect_x(400); // new/reused slot must snap
  positions[15:0]=404;attributes[4:2]=3'b101;commit();expect_x(404);
  running=0;positions[15:0]=408;commit();
  if(drawn!==positions)$fatal(1,"pause must snap/freeze");
  attributes=0;commit();if(attrs!==100'd0)$fatal(1,"reset state must hide cars");
  @(negedge clk);count=16'hffff;settle();
  attributes[4:0]=5'b10000;positions[15:0]=420;commit();
  if(!attrs[4] || drawn[15:0]!==16'd420)$fatal(1,"frame counter wrap ignored new snapshot");
  reset=1;#1;if(attrs!==0 || drawn!==0)$fatal(1,"physical reset");
  $display("PASS: adaptive Q8 interpolation, twenty slots, negative/variable cadence, heading, rebase, stall, pause/reset/wrap");$finish;
 end
endmodule
