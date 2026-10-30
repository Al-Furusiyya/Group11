`timescale 1ns / 1ps

// 16-bit combinational ALU
//
// flags[4] = C: carry or borrow
// flags[3] = L: unsigned lower-than
// flags[2] = N: signed lower-than
// flags[1] = F: signed overflow
// flags[0] = Z: equal or zero
//
// Immediate and register versions of instructions use the
// same ALU operation. The datapath will select whether rhs
// comes from a register or from an immediate value.

module ALU #(
    parameter WIDTH = 16
)(
    input  wire [3:0]       alu_op,
    input  wire [WIDTH-1:0] lhs,
    input  wire [WIDTH-1:0] rhs,
    input  wire             carryin,

    output reg  [WIDTH-1:0] result,
    output reg  [4:0]       flags
);

    localparam [3:0] ZEXT = 4'h0;
    localparam [3:0] SEXT = 4'h1;
    localparam [3:0] ADD  = 4'h2;
    localparam [3:0] SUB  = 4'h3;
    localparam [3:0] AND  = 4'h4;
    localparam [3:0] OR   = 4'h5;
    localparam [3:0] XOR  = 4'h6;
    localparam [3:0] MULT = 4'h7;
    localparam [3:0] LUI  = 4'h8;
    localparam [3:0] LSH  = 4'h9;
    localparam [3:0] ASH  = 4'hA;
    localparam [3:0] PASS = 4'hB;
    localparam [3:0] NOT  = 4'hC;
    localparam [3:0] CMP  = 4'hD;
    localparam [3:0] CMPU = 4'hE;
    localparam [3:0] NOP  = 4'hF;

    reg [WIDTH:0] extended_addition;

    // Explicit sensitivity list, as requested by the instructor.
    always @(alu_op or lhs or rhs or carryin) begin

        // Default values prevent latches.
        result = {WIDTH{1'b0}};
        flags = 5'b00000;
        extended_addition = {(WIDTH+1){1'b0}};

        case (alu_op)

            // Zero-extend the lowest byte of rhs.
            ZEXT: begin
                result = {{(WIDTH-8){1'b0}}, rhs[7:0]};
            end

            // Sign-extend the lowest byte of rhs.
            SEXT: begin
                result = {{(WIDTH-8){rhs[7]}}, rhs[7:0]};
            end

            // ADD, ADDI, ADDU, ADDUI, ADDC, ADDCI,
            // ADDCU and ADDCUI use this operation.
            ADD: begin
                extended_addition =
                    {1'b0, lhs} + {1'b0, rhs} + carryin;

                result = extended_addition[WIDTH-1:0];

                // Carry out
                flags[4] = extended_addition[WIDTH];

                // Signed overflow
                flags[1] =
                    ~(lhs[WIDTH-1] ^ rhs[WIDTH-1]) &
                     (lhs[WIDTH-1] ^ result[WIDTH-1]);
            end

            // SUB and SUBI use this operation.
            SUB: begin
                result = lhs - rhs - carryin;

                // Borrow
                flags[4] =
                    ({1'b0, lhs} <
                    ({1'b0, rhs} + carryin));

                // Unsigned lower-than
                flags[3] = (lhs < rhs);

                // Signed lower-than
                flags[2] = ($signed(lhs) < $signed(rhs));

                // Signed overflow
                flags[1] =
                    (lhs[WIDTH-1] ^ rhs[WIDTH-1]) &
                    ~(result[WIDTH-1] ^ rhs[WIDTH-1]);

                // Equal
                flags[0] = (lhs == rhs);
            end

            AND: begin
                result = lhs & rhs;
            end

            OR: begin
                result = lhs | rhs;
            end

            XOR: begin
                result = lhs ^ rhs;
            end

            MULT: begin
                result = lhs * rhs;
            end

            // Load the lowest byte of rhs into the upper byte.
            LUI: begin
                result = {rhs[7:0], {(WIDTH-8){1'b0}}};
            end

            // Positive rhs shifts left.
            // Negative rhs shifts right.
            LSH: begin
                if (rhs[WIDTH-1] == 1'b0)
                    result = lhs << rhs;
                else
                    result = lhs >> ((~rhs) + 1'b1);
            end

            // Positive rhs shifts left.
            // Negative rhs performs arithmetic right shift.
            ASH: begin
                if (rhs[WIDTH-1] == 1'b0)
                    result = lhs << rhs;
                else
                    result = $signed(lhs) >>> ((~rhs) + 1'b1);
            end

            // MOV and MOVI use this operation.
            PASS: begin
                result = rhs;
            end

            NOT: begin
                result = ~lhs;
            end

            // Signed comparison
            CMP: begin
                result = {WIDTH{1'b0}};

                // Signed lhs < rhs
                flags[2] = ($signed(lhs) < $signed(rhs));

                // lhs == rhs
                flags[0] = (lhs == rhs);
            end

            // Unsigned comparison
            CMPU: begin
                result = {WIDTH{1'b0}};

                // Unsigned lhs < rhs
                flags[3] = (lhs < rhs);

                // lhs == rhs
                flags[0] = (lhs == rhs);
            end

            // NOP/WAIT does not perform an operation.
            NOP: begin
                result = {WIDTH{1'b0}};
                flags = 5'b00000;
            end

            default: begin
                result = {WIDTH{1'b0}};
                flags = 5'b00000;
            end

        endcase
    end

endmodule