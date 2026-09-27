`timescale 1ns / 1ps



module ALU_RegFile_Datapath (
    input wire clk,
    input wire reset,

    input wire read_enable_a,
    input wire [3:0] read_address_a,
    output wire [15:0] read_data_a,

    input wire read_enable_b,
    input wire [3:0] read_address_b,
    output wire [15:0] read_data_b,

    input wire write_enable,
    input wire [3:0] write_address,

    input wire [3:0] alu_op,
    input wire use_immediate,
    input wire [15:0] immediate_value,
    input wire use_carry,

    input wire external_load,
    input wire [15:0] external_data,

    input wire [4:0] flag_write_enable,

    output wire [15:0] selected_rhs,
    output wire [15:0] alu_result,
    output wire [4:0] alu_flags,
    output wire [4:0] stored_flags,
    output wire [15:0] write_back_data
);

    wire alu_carryin;

 
    assign selected_rhs=use_immediate ?immediate_value : read_data_b;

    assign alu_carryin =use_carry ?stored_flags[4] : 1'b0;

    
    assign write_back_data =external_load ? external_data : alu_result;

    RegisterFile register_file(
.clk(clk),
 .reset(reset),

.read_enable_a(read_enable_a),
 .read_address_a(read_address_a),
 .read_data_a(read_data_a),

 .read_enable_b(read_enable_b),
 .read_address_b(read_address_b),
 .read_data_b(read_data_b),

 .write_enable(write_enable),
.write_address(write_address),
.write_data(write_back_data)
    );

    ALU #(
.WIDTH(16)
    ) alu_unit (
.alu_op(alu_op),
 .lhs(read_data_a),
.rhs(selected_rhs),
 .carryin(alu_carryin),
.result(alu_result),
.flags(alu_flags)
);

FlagRegister flag_register (
  .clk(clk),
  .reset(reset),
 .new_flags(alu_flags),
  .flag_write_enable(flag_write_enable),
  .stored_flags(stored_flags)
 );

endmodule
