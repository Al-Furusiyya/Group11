`timescale 1ns / 1ps

module alu_logic_shift (
    input  wire [15:0] a,          // Operand A (typically Rdest)
    input  wire [15:0] b,          // Operand B (Rsrc or shift amount)
    input  wire [3:0]  op,         // Operation selector
    output reg  [15:0] result,     // Computation result
    output wire        flag_z      // Zero flag: 1 if result == 0
);

    localparam OP_AND  = 4'b0000; // Bitwise AND
    localparam OP_OR   = 4'b0001; // Bitwise OR
    localparam OP_XOR  = 4'b0010; // Bitwise XOR
    localparam OP_NOT  = 4'b0011; // Bitwise NOT (~b)
    localparam OP_MOV  = 4'b0100; // Passthrough b (MOV / MOVI)
    localparam OP_LSH  = 4'b0101; // Logical Shift (Positive = Left, Negative = Right)
    localparam OP_ASHU = 4'b0110; // Arithmetic Shift (Preserves sign when right-shifting)
    localparam OP_LUI  = 4'b0111; // Load Upper Immediate ({b[7:0], 8'h00})

    wire signed [4:0] shift_amt = b[4:0];

    always @(*) begin
        case (op)
            OP_AND:  result = a & b;
            OP_OR:   result = a | b;
            OP_XOR:  result = a ^ b;
            OP_NOT:  result = ~b;
            OP_MOV:  result = b;
            OP_LUI:  result = {b[7:0], 8'h00};

            OP_LSH: begin
                if (shift_amt >= 0)
                    result = a << shift_amt;
                else
                    result = a >> (-shift_amt);
            end

            OP_ASHU: begin
                if (shift_amt >= 0)
                    result = a <<< shift_amt;
                else
                    result = $signed(a) >>> (-shift_amt);
            end

            default: result = 16'h0000;
        endcase
    end

    assign flag_z = (result == 16'h0000);

endmodule