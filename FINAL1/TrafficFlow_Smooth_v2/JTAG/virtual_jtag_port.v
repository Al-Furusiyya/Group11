// Built-in Quartus megafunction. No external top-level JTAG pins are required.
// Virtual IR 1: write a 288-bit display packet. IR 2: read 192-bit status.
module virtual_jtag_port (
 input wire tdo,output wire tck,tdi,output wire [1:0] ir,
 output wire capture_dr,shift_dr,update_dr
);
 sld_virtual_jtag #(
  .sld_auto_instance_index("NO"),.sld_instance_index(0),.sld_ir_width(2)
 ) tap (
  .tdo(tdo),.ir_out(2'b00),.tck(tck),.tdi(tdi),.ir_in(ir),
  .virtual_state_cdr(capture_dr),.virtual_state_sdr(shift_dr),.virtual_state_udr(update_dr)
 );
endmodule
