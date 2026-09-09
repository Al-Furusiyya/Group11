`timescale 1ns / 1ps

// 16-bit combinational ALU
// flags[4:0] = C, L, N, F, Z
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

    localparam [3:0] ZEXT = 4'b0000;
    localparam [3:0] SEXT = 4'b0001;
    localparam [3:0] ADD  = 4'b0010;
    localparam [3:0] SUB  = 4'b0011;
    localparam [3:0] AND  = 4'b0100;
    localparam [3:0] OR   = 4'b0101;
    localparam [3:0] XOR  = 4'b0110;
    localparam [3:0] MULT = 4'b0111;
    localparam [3:0] LUI  = 4'b1000;
    localparam [3:0] LSH  = 4'b1001;
    localparam [3:0] ASH  = 4'b1010;
    localparam [3:0] PASS = 4'b1011;
    localparam [3:0] NOT  = 4'b1100;

    reg [WIDTH:0] extended_addition;

    // Explicit sensitivity list, as requested by the instructor.
    always @(alu_op or lhs or rhs or carryin) begin
        result = {WIDTH{1'b0}};
        flags = 5'b00000;
        extended_addition = {(WIDTH+1){1'b0}};

        case (alu_op)
            ZEXT: begin
                result = {{(WIDTH-8){1'b0}}, rhs[7:0]};
            end

            SEXT: begin
                result = {{(WIDTH-8){rhs[7]}}, rhs[7:0]};
            end

            ADD: begin
                extended_addition = {1'b0, lhs} + {1'b0, rhs} + carryin;
                result = extended_addition[WIDTH-1:0];
                flags[4] = extended_addition[WIDTH];
                flags[1] = ~(lhs[WIDTH-1] ^ rhs[WIDTH-1]) &
                           (lhs[WIDTH-1] ^ result[WIDTH-1]);
            end

            SUB: begin
                result = lhs - rhs - carryin;
                flags[4] = ({1'b0, lhs} < ({1'b0, rhs} + carryin));
                flags[3] = (lhs < rhs);
                flags[2] = ($signed(lhs) < $signed(rhs));
                flags[1] = (lhs[WIDTH-1] ^ rhs[WIDTH-1]) &
                           ~(result[WIDTH-1] ^ rhs[WIDTH-1]);
                flags[0] = (lhs == rhs);
            end

            AND:  result = lhs & rhs;
            OR:   result = lhs | rhs;
            XOR:  result = lhs ^ rhs;
            MULT: result = lhs * rhs;

            LUI: begin
                result = {rhs[7:0], {(WIDTH-8){1'b0}}};
            end

            LSH: begin
                if (rhs[WIDTH-1] == 1'b0)
                    result = lhs << rhs;
                else
                    result = lhs >> ((~rhs) + 1'b1);
            end

            ASH: begin
                if (rhs[WIDTH-1] == 1'b0)
                    result = lhs << rhs;
                else
                    result = $signed(lhs) >>> ((~rhs) + 1'b1);
            end

            PASS: result = rhs;
            NOT:  result = ~lhs;

            default: begin
                result = {WIDTH{1'b0}};
                flags = 5'b00000;
            end
        endcase
    end

endmodule
