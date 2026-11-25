`timescale 1ns/1ps
// The CPU sends a service word. Verify that only its direction shows green
// and the four roof markings use the existing sprite/palette.
module tb_priority_scene;
 reg [9:0] px=0,py=0;
 reg [15:0] info=0;
 reg [7:0] left_info=0;
 reg [5:0] boarding=0;
 reg [767:0] positions=0;
 reg [119:0] attributes=0;
 reg [71:0] services=0;
 wire [7:0] r,g,b;
 vga_scene dut(.visible(1'b1),.pixel_x(px),.pixel_y(py),.test_switches(3'd0),
  .menu_control(2'd1),.menu_kind(2'd0),.menu_direction(2'd0),.menu_direction_valid(1'b0),
  .menu_turn(2'd0),.menu_turn_valid(1'b0),.menu_emergency(2'd0),.priority_info(info),
  .left_indicator(left_info),.boarding_progress(boarding),
  .light_ns(2'd0),.light_ew(2'd0),.left_green(4'd0),.phase(3'd7),.phase_seconds(3'd0),
  .ped_progress(6'd0),.ped_walk(4'd0),.ped_counts_bcd(32'd0),
  .car_positions(positions),.car_attributes(attributes),.car_services(services),.red(r),.green(g),.blue(b));
 integer d,t,x,y,changed,normal_area,service_area;
 reg [4:0] baseline,pixel;
 initial begin
  for(d=0;d<4;d=d+1)begin
   info=(2<<5)|(d<<3)|1;#1;
   if(dut.lamp_n!=(d==0?2:0)||dut.lamp_s!=(d==1?2:0)||
      dut.lamp_e!=(d==2?2:0)||dut.lamp_w!=(d==3?2:0))$fatal(1,"priority lamp mapping");
   info=info|14'h2000;#1;
   if(!dut.service_left)$fatal(1,"priority left arrow");
   info=info|14'h1000;#1;
   if(dut.lamp_n||dut.lamp_s||dut.lamp_e||dut.lamp_w)$fatal(1,"fault must display all red");
  end
  info=0;left_info=8'h0A;#1;
  if(dut.arrow_n!=1 || dut.arrow_s!=1 || dut.arrow_e!=0 || dut.arrow_w!=0)$fatal(1,"permissive arrows");
  left_info=8'h8A;#1;
  if(dut.arrow_n!=2 || dut.arrow_s!=1)$fatal(1,"committed left arrow not responsive");
  left_info=8'h00;#1;
  if(dut.arrow_n!=0 || dut.arrow_s!=0)$fatal(1,"left arrows did not reset");
  for(d=0;d<4;d=d+1)begin
   positions=0;attributes=0;services=0;
   positions[(20+d)*32+:32]={16'd410,16'd300};
   attributes[(20+d)*5+:5]={1'b1,2'd0,d[1:0]};
   services[(20+d)*3+:3]=4;
   info=16'h8000|(2<<5)|((20+d)<<7)|(d<<3)|4;boarding=0;left_info=8'hFF;#1;
   if(!dut.bus_boarding || dut.lamp_n || dut.lamp_s || dut.lamp_e || dut.lamp_w ||
      dut.arrow_n || dut.arrow_s || dut.arrow_e || dut.arrow_w)$fatal(1,"boarding must hold every signal red");
   if(dut.child_offset!=32)$fatal(1,"child starting position");
   if(dut.bus_x!=300 || dut.bus_y!=410)$fatal(1,"service slot anchor");
   if(!dut.bus_sign)$fatal(1,"stop sign missing during boarding");
   if((d==0||d==2) ? dut.arm_x>=dut.bus_x : dut.arm_x<=dut.bus_x)$fatal(1,"stop sign must face traffic");
   px=dut.arm_x;py=dut.arm_y+2;#1;
   if({r,g,b}!==24'hF06C68)$fatal(1,"red octagonal sign is not drawn");
   boarding=60;#1;
   if(dut.child_offset!=2)$fatal(1,"child did not reach bus");
   info=info|16'h4000;#1;
   if(!dut.bus_sign || dut.bus_boarding || dut.service_green)$fatal(1,"sign must stay out while cars stop");
   info=info&16'h3FFF;#1;
   if(dut.bus_boarding || dut.bus_sign || !dut.service_green)$fatal(1,"bus did not release");
  end
  for(t=1;t<=4;t=t+1)for(d=0;d<4;d=d+1)begin
   changed=0;normal_area=0;service_area=0;
   for(y=226;y<270;y=y+1)for(x=368;x<424;x=x+1)begin
    baseline=dut.car_pixel(x,y,396,256,d[1:0],2'd0,3'd0);
    pixel=dut.car_pixel(x,y,396,256,d[1:0],2'd0,t[2:0]);
    if(pixel[4])service_area=service_area+1;
    if(baseline[4])normal_area=normal_area+1;
    if(pixel!=baseline)changed=changed+1;
   end
   if(changed<5)$fatal(1,"missing vehicle-specific graphics");
   if(t!=3 && service_area<=normal_area)$fatal(1,"larger service silhouette not visible");
  end
  $display("PASS: 16 distinct service sprite orientations, larger silhouettes, responsive left arrows and boarding anchors");
  $finish;
 end
endmodule
