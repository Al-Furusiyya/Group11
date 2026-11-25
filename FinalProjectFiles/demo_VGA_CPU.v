// The Lab4 CPU runs the traffic program in firmware/traffic.asm.
// Here we only connect its input/display peripherals to our existing VGA scene.
module demo_VGA_CPU (
 input wire CLOCK_50,input wire [0:0] KEY,input wire [2:0] SW,
 input wire PS2_CLK,PS2_DAT,
 output wire [9:0] LEDR,output wire [7:0] VGA_R,VGA_G,VGA_B,
 output wire VGA_HS,VGA_VS,VGA_CLK,VGA_BLANK_N,VGA_SYNC_N
);
 wire reset=~KEY[0];
 wire visible,raw_hs,raw_vs;
 wire [7:0] raw_r,raw_g,raw_b;
 reg [7:0] output_r,output_g,output_b;
 reg output_hs,output_vs,output_blank;
 wire [767:0] drawn_positions;
 wire [119:0] drawn_attributes;
 wire [9:0] pixel_x,pixel_y;
 wire [247:0] state;
 wire [959:0] cars;
 wire [767:0] car_positions;
 wire [119:0] car_attributes;
 wire [71:0] car_services; // identity lives in each CPU slot, not the event type
 genvar car_slot;
 generate for(car_slot=0;car_slot<24;car_slot=car_slot+1)begin: unpack_cars
  assign car_positions[car_slot*32+:32]=cars[car_slot*40+:32];
  assign car_attributes[car_slot*5+:5]=cars[car_slot*40+32+:5];
  assign car_services[car_slot*3+:3]=cars[car_slot*40+37+:3];
 end endgenerate
 wire [7:0] scan_code,key_code;
 wire scan_valid,frame_error,key_pressed,command_valid;
 wire [4:0] command;
 wire state_valid,cpu_io_error;
 wire [15:0] io_address;
 wire [14:0] cpu_pc;
 wire [15:0] video_frame_id;
 wire [15:0] io_write_data,io_read_data,cpu_instruction,debug_register_value;
 wire [15:0] cpu_a,cpu_b,cpu_alu,frame_count;
 wire [4:0] cpu_flags;
 wire [2:0] cpu_phase;
 wire io_read,io_write;
 wire frame_tick=(pixel_x==0 && pixel_y==480 && VGA_CLK);
 reg event_toggle,error_seen;
 wire [3:0] emergency=state[27:24];
 wire [1:0] emergency_index=emergency[0] ? 2'd0 : emergency[1] ? 2'd1 : emergency[2] ? 2'd2 : 2'd3;
 vga_timing timing(CLOCK_50,reset,VGA_CLK,pixel_x,pixel_y,visible,raw_hs,raw_vs);
 PS2Keyboard keyboard(CLOCK_50,reset,PS2_CLK,PS2_DAT,scan_code,scan_valid,frame_error,key_code,key_pressed);
 KeyboardCommands keys(key_code,key_pressed,command_valid,command);
 CPU_Part1 cpu (
  .clk(CLOCK_50),.reset(reset),.debug_register_select({1'b0,SW}),
  .debug_register_value(debug_register_value),.pc(cpu_pc),.instruction(cpu_instruction),
  .state(cpu_phase),.read_data_a(cpu_a),.read_data_b(cpu_b),.alu_result(cpu_alu),
  .stored_flags(cpu_flags),.io_address(io_address),.io_write_data(io_write_data),
  .io_read(io_read),.io_write(io_write),.io_read_data(io_read_data)
 );
 traffic_io peripherals(CLOCK_50,reset,frame_tick,io_address,io_write_data,
  io_read,io_write,io_read_data,command_valid,command,SW[0],state,cars,
  state_valid,cpu_io_error,video_frame_id,frame_count);
 sprite_smoother smooth_sprites(CLOCK_50,reset,frame_tick,frame_count,
  state[1:0]==2'd1,car_positions,car_attributes,drawn_positions,drawn_attributes);
 vga_scene scene(
  .visible(visible),.pixel_x(pixel_x),.pixel_y(pixel_y),.test_switches(SW),
  .menu_control(state[1:0]),.menu_kind(state[29:28]),
  .menu_direction(state[9:8]),.menu_direction_valid(state[30]),
  .menu_turn(state[17:16]),.menu_turn_valid(state[31]),.menu_emergency(emergency_index),
  .priority_info(state[111:96]),
  .left_indicator(state[215:208]),
  .boarding_progress(state[229:224]),
  .light_ns(state[33:32]),.light_ew(state[41:40]),.ped_walk(state[51:48]),
   .left_green(state[55:52]),.phase(state[127:125]),.phase_seconds(state[167:165]),
   .ped_progress({state[247:245],state[207:205]}),
  .ped_counts_bcd({state[63:56],state[71:64],state[79:72],state[87:80]}),
  .car_positions(drawn_positions),.car_attributes(drawn_attributes),.car_services(car_services),
  .red(raw_r),.green(raw_g),.blue(raw_b)
 );
 always @(posedge CLOCK_50 or posedge reset)begin
  if(reset)begin event_toggle<=0;error_seen<=0;end
  else begin
   if(state_valid)event_toggle<=~event_toggle;
   if(frame_error || cpu_io_error)error_seen<=1;
  end
 end
 assign LEDR[7:0]=key_code;
 assign LEDR[8]=event_toggle; // toggles on completed CPU display frames
 assign LEDR[9]=error_seen;   // sticky keyboard or CPU display I/O error; KEY[0] clears
 // Register the entire VGA pixel together on the DAC clock's falling
 // edge. The matching RGB/sync/blank pixel is stable before its rising
 // sampling edge. This adds one pixel of internal latency, not a skew
 // between image and sync. The existing divided-clock SDC stays valid.
 always @(posedge CLOCK_50 or posedge reset)begin
  if(reset)begin
   output_r<=0;output_g<=0;output_b<=0;
   output_hs<=1;output_vs<=1;output_blank<=0;
  end else if(VGA_CLK)begin
   output_r<=raw_r;output_g<=raw_g;output_b<=raw_b;
   output_hs<=raw_hs;output_vs<=raw_vs;output_blank<=visible;
  end
 end
 assign VGA_R=output_r;assign VGA_G=output_g;assign VGA_B=output_b;
 assign VGA_HS=output_hs;assign VGA_VS=output_vs;
 assign VGA_BLANK_N=output_blank;assign VGA_SYNC_N=1'b0;
endmodule
