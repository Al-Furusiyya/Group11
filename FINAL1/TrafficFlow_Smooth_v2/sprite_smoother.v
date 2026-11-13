// Cadence-adaptive, Q8 visual interpolation. No traffic decisions or packet
// changes. All planning/updating completes in 40 CLOCK_50 cycles in vblank.
// One shared reciprocal multiplier avoids forty replicated dividers/DSPs.
module sprite_smoother(
 input wire clk,reset,frame_tick,
 input wire [15:0] frame_count,
 input wire running,
 input wire [639:0] positions,
 input wire [99:0] attributes,
 output wire [639:0] drawn_positions,
 output reg [99:0] drawn_attributes
);
 reg [719:0] current_q8;
 reg [559:0] velocity_q8;
 reg [639:0] targets;
 reg [99:0] old_attributes;
 reg [15:0] seen_frame;
 reg [4:0] age,duration,remaining;
 reg busy,planning,finishing,smooth_enabled,slot_snap;
 reg [5:0] axis;
 reg signed [18:0] current_value,target_value,delta,increment;
 reg signed [32:0] product;
 reg [15:0] ox,oy,nx,ny;
 reg snap;
 genvar i;
 generate for(i=0;i<20;i=i+1)begin: output_positions
  wire [18:0] rounded_x={1'b0,current_q8[i*36+:18]}+19'd128;
  wire [18:0] rounded_y={1'b0,current_q8[i*36+18+:18]}+19'd128;
  assign drawn_positions[i*32+:16]={6'd0,rounded_x[17:8]};
  assign drawn_positions[i*32+16+:16]={6'd0,rounded_y[17:8]};
 end endgenerate
 function [12:0] reciprocal;
  input [4:0] frames;
  begin
   case(frames)
    5'd1:reciprocal=13'd4096;
    5'd2:reciprocal=13'd2048;
    5'd3:reciprocal=13'd1365;
    5'd4:reciprocal=13'd1024;
    5'd5:reciprocal=13'd819;
    5'd6:reciprocal=13'd683;
    5'd7:reciprocal=13'd585;
    5'd8:reciprocal=13'd512;
    5'd9:reciprocal=13'd455;
    5'd10:reciprocal=13'd410;
    5'd11:reciprocal=13'd372;
    5'd12:reciprocal=13'd341;
    5'd13:reciprocal=13'd315;
    5'd14:reciprocal=13'd293;
    5'd15:reciprocal=13'd273;
    5'd16:reciprocal=13'd256;
    5'd17:reciprocal=13'd241;
    5'd18:reciprocal=13'd228;
    5'd19:reciprocal=13'd216;
    5'd20:reciprocal=13'd205;
    5'd21:reciprocal=13'd195;
    5'd22:reciprocal=13'd186;
    5'd23:reciprocal=13'd178;
    5'd24:reciprocal=13'd171;
    5'd25:reciprocal=13'd164;
    5'd26:reciprocal=13'd158;
    5'd27:reciprocal=13'd152;
    5'd28:reciprocal=13'd146;
    5'd29:reciprocal=13'd141;
    5'd30:reciprocal=13'd137;
    default:reciprocal=13'd2048;
   endcase
  end
 endfunction
 always @(posedge clk or posedge reset)begin
  if(reset)begin
   current_q8<=0;velocity_q8<=0;targets<=0;drawn_attributes<=0;
   old_attributes<=0;seen_frame<=0;age<=2;duration<=2;remaining<=0;
   busy<=0;planning<=0;finishing<=0;smooth_enabled<=0;axis<=0;slot_snap<=1;
  end else begin
   if(frame_tick && age<30)age<=age+1'b1;
   if(frame_count!=seen_frame)begin
    seen_frame<=frame_count;age<=0;
    duration<=(age==0 ? 5'd2 : age);
    remaining<=(age==0 ? 5'd1 : age-1'b1);
    targets<=positions;old_attributes<=drawn_attributes;
    drawn_attributes<=attributes;smooth_enabled<=running;
    busy<=1;planning<=1;finishing<=0;axis<=0;
   end else if(busy)begin
    current_value=$signed({1'b0,current_q8[axis*18+:18]});
    target_value=$signed({1'b0,targets[axis*16+:10],8'd0});
    if(planning)begin
     ox={6'd0,current_q8[(axis>>1)*36+8+:10]};
     oy={6'd0,current_q8[(axis>>1)*36+26+:10]};
     nx=targets[(axis>>1)*32+:16];ny=targets[(axis>>1)*32+16+:16];
     // A heading change is the SAME car: never snap position on a turn.
     // Slot identity is stable in Python. Reappearance/repaint/large jump
     // still snaps, as do Pause and Reset.
     snap=(!smooth_enabled || !drawn_attributes[(axis>>1)*5+4] ||
           drawn_attributes[(axis>>1)*5+2+:3]!=old_attributes[(axis>>1)*5+2+:3] ||
           {1'b0,ox}+24<nx || {1'b0,nx}+24<ox ||
           {1'b0,oy}+12<ny || {1'b0,ny}+12<oy);
     if(axis[0])snap=slot_snap;
     else slot_snap<=snap;
     delta=target_value-current_value;
     product=delta*$signed({1'b0,reciprocal(duration)});
     increment=product>>>12;
     if(snap || duration==1)begin
      current_q8[axis*18+:18]<=target_value[17:0];
      velocity_q8[axis*14+:14]<=0;
     end else begin
      current_q8[axis*18+:18]<=current_value+increment;
      velocity_q8[axis*14+:14]<=increment[13:0];
     end
    end else if(finishing)begin
     current_q8[axis*18+:18]<=target_value[17:0];
     velocity_q8[axis*14+:14]<=0;
    end else begin
     current_q8[axis*18+:18]<=current_value+$signed(velocity_q8[axis*14+:14]);
    end
    if(axis==39)busy<=0;
    else axis<=axis+1'b1;
   end else if(frame_tick && remaining!=0)begin
    remaining<=remaining-1'b1;finishing<=(remaining==1);
    busy<=1;planning<=0;axis<=0;
   end
  end
 end
endmodule
