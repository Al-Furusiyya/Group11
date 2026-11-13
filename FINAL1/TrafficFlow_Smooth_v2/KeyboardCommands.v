// Transport encoding only. Python owns input sequences and traffic decisions.
module KeyboardCommands (
 input wire [7:0] key_code,input wire key_pressed,
 output wire command_valid,output reg [4:0] command
);
 always @(*) begin
  case(key_code)
   8'h16:command=1; // 1
   8'h1e:command=2; // 2
   8'h26:command=3; // 3
   8'h31:command=4; // N
   8'h1b:command=5; // S = South only
   8'h24:command=6; // E
   8'h1d:command=7; // W
   8'h4b:command=8; // L
   8'h2c:command=9; // T = straight
   8'h2d:command=10; // R
   8'h4d:command=11; // P
   8'h1c:command=12; // A
   8'h2b:command=13; // F
   8'h21:command=14; // C
   8'h32:command=15; // B
   8'h76:command=16; // Esc
   default:command=0;
  endcase
 end
 assign command_valid=key_pressed && command!=0;
endmodule
