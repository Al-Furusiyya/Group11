`timescale 1ns / 1ps

// Connects the Register File, ALU, and Flag Register.
//
// Register A supplies the left ALU operand.
// Register B or the immediate value supplies the right ALU operand.
// The ALU result can be written back into the Register File.
// External data can also be written into the Register File for testing.
// ALU flags can be stored inside the Flag Register.

module ALU_RegFile_Datapath (
    input wire clk,
    input wire reset,

    // Register File read port A
    input wire read_enable_a,
    input wire [3:0] read_address_a,
    output wire [15:0] read_data_a,

    // Register File read port B
    input wire read_enable_b,
    input wire [3:0] read_address_b,
    output wire [15:0] read_data_b,

    // Register File write port
    input wire write_enable,
    input wire [3:0] write_address,

    // ALU controls
    input wire [3:0] alu_op,
    input wire use_immediate,
    input wire [15:0] immediate_value,
    input wire use_carry,

    // External data is used to load starting values
    input wire external_load,
    input wire [15:0] external_data,

    // Selects which flags are stored
    input wire [4:0] flag_write_enable,

    // Datapath outputs
    output wire [15:0] selected_rhs,
    output wire [15:0] alu_result,
    output wire [4:0] alu_flags,
    output wire [4:0] stored_flags,
    output wire [15:0] write_back_data
);

    wire alu_carryin;

    // Select the ALU's right-side operand.
    //
    // use_immediate = 0: use Register File port B
    // use_immediate = 1: use immediate_value
    assign selected_rhs =
        use_immediate ? immediate_value : read_data_b;

    // Select whether the ALU should use the previously stored carry.
    //
    // use_carry = 0: carry into ALU is zero
    // use_carry = 1: use the stored C flag
    assign alu_carryin =
        use_carry ? stored_flags[4] : 1'b0;

    // Select the data written into the Register File.
    //
    // external_load = 0: write the ALU result
    // external_load = 1: write external_data
    assign write_back_data =
        external_load ? external_data : alu_result;

    // 16-register Register File
    RegisterFile register_file (
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

    // 16-bit combinational ALU
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

    // Stores selected ALU flags
    FlagRegister flag_register (
        .clk(clk),
        .reset(reset),
        .new_flags(alu_flags),
        .flag_write_enable(flag_write_enable),
        .stored_flags(stored_flags)
    );

endmodule