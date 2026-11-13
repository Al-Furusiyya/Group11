// Bundled-data request/reply mailboxes between JTAG TCK and CLOCK_50.
// The sender holds each mailbox until the opposite side acknowledges it.
// Request: protocol v4, five 36-byte banks per snapshot, shifted LSB first.
// Reply: bytes 0..1 "JG", 2 sequence, 3 result, 4 key count, 5..20 keys,
// 21 CRC8(bytes 0..20), 22 version=3, 23 flags (busy/valid/overflow/bad/reset).
module jtag_display_link (
 input wire clk,reset,cpu_frame_done,key_valid,input wire [4:0] key_command,
 input wire tck,tdi,input wire [1:0] ir,
 input wire capture_dr,shift_dr,update_dr,
 output wire tdo,output reg [247:0] received_state,
 output reg received_valid,packet_error
);
 reg [287:0] input_shift,request_payload;
 reg [191:0] status_shift;
 reg [8:0] shift_count;
 reg reset_pending;
 reg request_toggle,bad_scan;
 reg done_toggle,response_valid,key_overflow;
 (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
 reg done_meta,done_sync,valid_meta,valid_sync,overflow_meta,overflow_sync;
 (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
 reg reset_meta,reset_sync;
 (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
 reg request_meta,request_sync;
 reg [183:0] response_payload;
 wire busy=request_toggle!=done_sync;
 wire [7:0] status_flags={3'd0,reset_sync,bad_scan,overflow_sync,valid_sync,busy};
 assign tdo=(ir==2) ? status_shift[0] : 1'b0;

 always @(posedge tck or posedge reset)begin
  if(reset)begin
   input_shift<=0;request_payload<=0;status_shift<=0;shift_count<=0;
   request_toggle<=0;bad_scan<=0;
   done_meta<=0;done_sync<=0;valid_meta<=0;valid_sync<=0;
   overflow_meta<=0;overflow_sync<=0;
   reset_meta<=1;reset_sync<=1;
  end else begin
   done_meta<=done_toggle;done_sync<=done_meta;
   valid_meta<=response_valid;valid_sync<=valid_meta;
   overflow_meta<=key_overflow;overflow_sync<=overflow_meta;
   reset_meta<=reset_pending;reset_sync<=reset_meta;
   if(capture_dr)begin
    if(ir==1)begin input_shift<=0;shift_count<=0;end
    if(ir==2)status_shift<={status_flags,response_payload};
   end else if(shift_dr)begin
    if(ir==1)begin
     input_shift<={tdi,input_shift[287:1]};
      // Saturate at the payload length: other physical TAPs contribute
      // BYPASS clocks. The shift register retains the final payload bits.
      if(shift_count<9'd288)shift_count<=shift_count+1'b1;
    end
    if(ir==2)status_shift<={1'b0,status_shift[191:1]};
   end
   if(update_dr && ir==1)begin
    if(shift_count>=9'd288 && !busy)begin
     request_payload<=input_shift;request_toggle<=~request_toggle;
    // A physical reset can truncate a scan. During reset recovery the host
    // sees status bit 4 and retries an idle snapshot; do not latch that tail
    // as a permanent bad scan. Normal short/busy scans still latch an error.
    end else if(!reset_sync)bad_scan<=1;
   end
  end
 end

 reg [287:0] packet;
 reg seen_toggle;
 reg [2:0] phase;
 reg [2:0] expected_bank;
 reg [5:0] byte_index;
 reg [7:0] crc,result;
 reg [183:0] reply_work;
 reg [4:0] keys[0:15];
 reg [4:0] read_pointer,write_pointer,drain_count;
 wire [4:0] key_count=write_pointer-read_pointer;
 localparam IDLE=0,CHECK=1,WAIT_CPU=2,DRAIN=3,REPLY_CRC=4,PUBLISH=5;
 function [7:0] crc_step;
  input [7:0] current,value;
  reg [7:0] c;integer k;
  begin c=current^value;for(k=0;k<8;k=k+1)c=c[7] ? (c<<1)^8'h07 : c<<1;crc_step=c;end
 endfunction
 function valid_payload;
  input [247:0] p;
  integer k,offset;reg ok;reg [7:0] b;
  reg [15:0] cx,cy;
  begin
   ok=(p[7:0]<=3 && p[15:8]<=3 && p[23:16]<=2 &&
       p[33:32]<=2 && p[39:37]==0 && p[36:34]<=4 && p[47:40]<=2 && p[167:165]<=5);
   for(k=7;k<=10;k=k+1)begin b=p[k*8+:8];if(b[7:4]>9 || b[3:0]>9)ok=0;end
   for(k=0;k<4;k=k+1)begin
    offset=(11+k*5)*8;
    cx=p[offset+:16];cy=p[offset+16+:16];b=p[offset+32+:8];
    if(cx>639 || cy>479 || b[3:2]>2)ok=0;
   end
   valid_payload=ok;
  end
 endfunction
 localparam [247:0] RESET_STATE=248'h00000000000000000000000000000000000000000000000000000000010000;
 always @(posedge clk or posedge reset)begin
  if(reset)begin
   received_state<=RESET_STATE;received_valid<=0;packet_error<=0;
   request_meta<=0;request_sync<=0;seen_toggle<=0;done_toggle<=0;
   reset_pending<=1;response_valid<=0;response_payload<=0;packet<=0;phase<=IDLE;
   byte_index<=0;crc<=0;result<=0;reply_work<=0;expected_bank<=0;
   read_pointer<=0;write_pointer<=0;drain_count<=0;key_overflow<=0;
  end else begin
   request_meta<=request_toggle;request_sync<=request_meta;
   packet_error<=0;
   if(key_valid)begin
    if(key_count<16)begin keys[write_pointer[3:0]]<=key_command;write_pointer<=write_pointer+1'b1;end
    else begin key_overflow<=1;packet_error<=1;end
   end
   case(phase)
    IDLE:if(request_sync!=seen_toggle)begin
     // Data was held stable while the request crossed two synchronizer FFs.
     packet<=request_payload;seen_toggle<=request_sync;
     response_valid<=0;byte_index<=2;crc<=0;result<=0;phase<=CHECK;
    end
    CHECK:begin
     if(byte_index<=34)begin
      crc<=crc_step(crc,packet[byte_index*8+:8]);byte_index<=byte_index+1'b1;
     end else begin
      reply_work<=0;drain_count<=0;
      if(packet[15:0]!=16'h5aa5 || packet[23:16]!=4 || packet[287:280]!=crc)begin
       result<=1;packet_error<=1;phase<=DRAIN;
      end else if(!valid_payload(packet[32+:248]) ||
                  (packet[68:66]!=0 && packet[68:66]!=expected_bank))begin
       result<=2;packet_error<=1;phase<=DRAIN;
      end else if(reset_pending && packet[39:32]!=0 && packet[39:32]!=3)begin
       // KEY0 must leave the GUI empty even if Python was running. Ask the
       // host to reset its controller; no running snapshot reaches the CPU.
       result<=3;phase<=DRAIN;
      end else begin
       reset_pending<=0;
       received_state<=packet[32+:248];received_valid<=1;phase<=WAIT_CPU;
      end
     end
    end
    WAIT_CPU:if(cpu_frame_done)begin
     expected_bank<=(packet[68:66]==4) ? 3'd0 : packet[68:66]+3'd1;
     received_valid<=0;phase<=DRAIN;
    end
    DRAIN:begin
     if(key_count!=0 && drain_count<16)begin
      reply_work[(5+drain_count)*8+:8]<={3'd0,keys[read_pointer[3:0]]};
      read_pointer<=read_pointer+1'b1;drain_count<=drain_count+1'b1;
     end else begin
      reply_work[15:0]<=16'h474a;reply_work[23:16]<=packet[31:24];
      reply_work[31:24]<=result;reply_work[39:32]<={3'd0,drain_count};
      reply_work[183:176]<=8'd3;
      byte_index<=0;crc<=0;phase<=REPLY_CRC;
     end
    end
    REPLY_CRC:begin
     crc<=crc_step(crc,reply_work[byte_index*8+:8]);
     if(byte_index==20)begin
      reply_work[175:168]<=crc_step(crc,reply_work[byte_index*8+:8]);phase<=PUBLISH;
     end else byte_index<=byte_index+1'b1;
    end
    PUBLISH:begin
     response_payload<=reply_work;response_valid<=1;
     done_toggle<=seen_toggle;phase<=IDLE;
    end
    default:phase<=IDLE;
   endcase
  end
 end
endmodule
