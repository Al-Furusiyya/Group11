// Peripherals are accessed only by the uploaded Lab4 CPU's LOAD/STOR bus.
// Python data cannot reach display_state without CPU register writes + COMMIT.
module traffic_io (
 input wire clk,reset,frame_tick,
 input wire [9:0] address,input wire [15:0] write_data,
 input wire read_enable,write_enable,output reg [15:0] read_data,
 input wire [247:0] received_state,input wire received_valid,
 input wire key_valid,input wire [4:0] key_command,
 output reg uplink_key_valid,output reg [4:0] uplink_key_command,
 output reg [247:0] display_state,output reg frame_done,output reg error_seen,
 output reg [15:0] frame_count,
 output reg [799:0] display_cars
);
 localparam [247:0] RESET_STATE=248'h00000000000000000000000000000000000000000000000000000000010000;
 reg [255:0] staging;
 reg [799:0] staged_cars;
 reg [2:0] expected_bank;
 wire [2:0] bank=staging[36:34];
 reg commit_pending;
 reg [4:0] keys[0:15];
 reg [4:0] read_pointer,write_pointer;
 wire [4:0] key_count=write_pointer-read_pointer;
 wire pop_key=read_enable && address==10'h3e4 && key_count!=0;
 always @(*)begin
  read_data=16'd0;
  if(address>=10'h3c0 && address<=10'h3cf)
   read_data=({8'd0,received_state} >> (address[3:0]*16));
  else case(address)
   10'h3e0:read_data={15'd0,received_valid};
   10'h3e1:read_data={15'd0,commit_pending};
   10'h3e3:read_data={15'd0,(key_count!=0)};
   10'h3e4:read_data=(key_count!=0) ? {11'd0,keys[read_pointer[3:0]]} : 16'd0;
   10'h3e6:read_data=frame_count;
   default:read_data=16'd0;
  endcase
 end
 always @(posedge clk or posedge reset)begin
  if(reset)begin
   staging<={8'd0,RESET_STATE};display_state<=RESET_STATE;commit_pending<=0;
   frame_done<=0;error_seen<=0;frame_count<=0;
   staged_cars<=0;display_cars<=0;expected_bank<=0;
   read_pointer<=0;write_pointer<=0;uplink_key_valid<=0;uplink_key_command<=0;
  end else begin
   frame_done<=0;uplink_key_valid<=0;
   if(key_valid)begin
    if(key_count<16 || pop_key)begin
     keys[write_pointer[3:0]]<=key_command;write_pointer<=write_pointer+1'b1;
    end else error_seen<=1;
   end
   if(pop_key)read_pointer<=read_pointer+1'b1;
   if(write_enable)begin
    if(address>=10'h3d0 && address<=10'h3df)begin
     if(!commit_pending)staging[address[3:0]*16+:16]<=write_data;
     else error_seen<=1;
    end
    if(address==10'h3e2 && write_data[0])begin
     if(received_valid && !commit_pending)commit_pending<=1;
     else error_seen<=1;
    end
    if(address==10'h3e5 && write_data>=1 && write_data<=16)begin
     uplink_key_command<=write_data[4:0];uplink_key_valid<=1;
    end
   end
   if(commit_pending && (bank!=4 || frame_tick))begin
    commit_pending<=0;frame_done<=1;
    if(bank>4 || (bank!=0 && bank!=expected_bank))begin
     error_seen<=1;expected_bank<=0;
    end else begin
     if(bank==0)staged_cars<= {640'd0,staging[247:88]};
     else staged_cars[bank*160+:160]<=staging[247:88];
     if(bank==4)begin
      // One atomic VGA update after all five banks passed through the CPU.
      display_cars<={staging[247:88],staged_cars[639:0]};
      display_state<=staging[247:0];frame_count<=frame_count+1'b1;
      expected_bank<=0;
     end else expected_bank<=bank+3'd1;
    end
   end
  end
 end
endmodule
