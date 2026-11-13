`timescale 1ns/1ps
// Actual combinational HDL pixel capture. First run render_preview.py to
// generate vga_states.hex; compile with vga_scene.v; run from project root.
module tb_vga_capture;
 reg visible=1;reg [9:0] x=0,y=0;reg [247:0] state;
 reg [799:0] car_states[0:5];reg [799:0] cars;
 wire [639:0] positions;wire [99:0] attributes;
 genvar k;
 generate for(k=0;k<20;k=k+1)begin: unpack
  assign positions[k*32+:32]=cars[k*40+:32];
  assign attributes[k*5+:5]=cars[k*40+32+:5];
 end endgenerate
 reg [247:0] states[0:5];wire [7:0] r,g,b;
 wire [3:0] em=state[27:24];
 wire [1:0] ei=em[0]?0:em[1]?1:em[2]?2:3;
 integer frame,px,py,fd;reg [1023:0] filename;
 vga_scene dut(.visible(visible),.pixel_x(x),.pixel_y(y),.test_switches(3'd0),
  .menu_control(state[1:0]),.menu_kind(state[29:28]),
  .menu_direction(state[9:8]),.menu_direction_valid(state[30]),
  .menu_turn(state[17:16]),.menu_turn_valid(state[31]),.menu_emergency(ei),
  .light_ns(state[33:32]),.light_ew(state[41:40]),.ped_walk(state[51:48]),
  .left_green(state[55:52]),.phase(state[127:125]),.phase_seconds(state[167:165]),
  .ped_progress({state[247:245],state[207:205]}),
  .ped_counts_bcd({state[63:56],state[71:64],state[79:72],state[87:80]}),
  .car_positions(positions),
  .car_attributes(attributes),
  .red(r),.green(g),.blue(b));
 initial begin
  $readmemh("sim/vga_states.hex",states);
  $readmemh("sim/vga_cars.hex",car_states);
  for(frame=0;frame<6;frame=frame+1)begin
   state=states[frame];cars=car_states[frame];$sformat(filename,"sim/vga_%0d.ppm",frame);
   fd=$fopen(filename,"wb");$fwrite(fd,"P6\n640 480\n255\n");
   for(py=0;py<480;py=py+1)begin
    for(px=0;px<640;px=px+1)begin
     x=px;y=py;#1;
     if((^r===1'bx)||(^g===1'bx)||(^b===1'bx))begin
      $display("FAIL: unknown VGA pixel");$finish;
     end
     $fwrite(fd,"%c%c%c",r,g,b);
    end
   end
   $fclose(fd);
  end
  visible=0;#1;
  if({r,g,b}!==24'd0)begin $display("FAIL: blanking");$finish;end
  $display("PASS: six VGA frames captured without unknown pixels; blanking correct");
  $finish;
 end
endmodule
