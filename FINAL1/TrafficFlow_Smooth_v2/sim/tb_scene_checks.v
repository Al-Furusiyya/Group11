`timescale 1ns/1ps
module tb_scene_checks;
 reg [9:0] x=0,y=0;
 reg [3:0] walk=0,lefts=0;
 reg [5:0] progress=0;
 reg [1:0] ns=0,ew=0;
 wire [7:0] r,g,b;
 vga_scene dut(.visible(1'b1),.pixel_x(x),.pixel_y(y),.test_switches(3'd0),
 .menu_control(2'd0),.menu_kind(2'd0),.menu_direction(2'd0),.menu_direction_valid(1'b0),
 .menu_turn(2'd0),.menu_turn_valid(1'b0),.menu_emergency(2'd0),
 .light_ns(ns),.light_ew(ew),.left_green(lefts),.phase(3'd6),.phase_seconds(3'd5),
 .ped_progress(progress),.ped_walk(walk),.ped_counts_bcd(32'd0),
 .car_positions(640'd0),.car_attributes(100'd0),.red(r),.green(g),.blue(b));
 task green_head;
  input integer px,py;
  begin x=px+2;y=py;#1;
   if({r,g,b}!==24'h40D8A0)$fatal(1,"pedestrian absent at %0d,%0d",px,py);
  end
 endtask
 initial begin
  // Every direction starts and finishes on its far/opposite crosswalk.
  walk=8;progress=0;green_head(375,283);progress=63;green_head(319,255);
  walk=2;progress=0;green_head(411,209);progress=63;green_head(467,237);
  walk=4;progress=0;green_head(411,283);progress=63;green_head(467,255);
  walk=1;progress=0;green_head(375,209);progress=63;green_head(319,237);
  walk=0;ns=2;x=364;y=175;#1;
  if({r,g,b}!==24'hE4C94C)$fatal(1,"permissive arrow not amber above main light");
  lefts=2;#1;
  if({r,g,b}!==24'h40D8A0)$fatal(1,"protected arrow not green");
  lefts=0;ns=0;#1;
  if({r,g,b}!==24'hF06C68)$fatal(1,"red arrow wrong");
  ns=2;walk=8;x=474;y=327;#1;
  if({r,g,b}!==24'hF06C68)$fatal(1,"NB left must yield to west crossing");
  x=364;y=176;#1;
  if({r,g,b}!==24'hE4C94C)$fatal(1,"compatible SB left indication must remain amber");
  ns=0;ew=2;walk=4;x=426;y=176;#1;
  if({r,g,b}!==24'hF06C68)$fatal(1,"WB left must yield to south crossing");
  $display("PASS: all pedestrian directions/endpoints, WB far crosswalk, arrows above lights");$finish;
 end
endmodule
