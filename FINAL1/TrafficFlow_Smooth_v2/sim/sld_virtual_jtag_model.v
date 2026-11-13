// Test-only stand-in for the vendor Virtual JTAG primitive.
// Tests drive this interface directly; real Quartus uses its built-in IP.
module sld_virtual_jtag #(
 parameter sld_auto_instance_index="NO",parameter sld_instance_index=0,
 parameter sld_ir_width=2
)(
 input wire tdo,input wire [sld_ir_width-1:0] ir_out,
 output reg tck,tdi,output reg [sld_ir_width-1:0] ir_in,
 output reg virtual_state_cdr,virtual_state_sdr,virtual_state_udr
);
 initial begin
  tck=0;tdi=0;ir_in=0;virtual_state_cdr=0;virtual_state_sdr=0;virtual_state_udr=0;
 end
endmodule
