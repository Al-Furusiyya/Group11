`timescale 1ns / 1ps


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
    localparam [3:0] CMP  = 4'b1101;
    localparam [3:0] CMPU = 4'b1110;
    localparam [3:0] NOP  = 4'b1111;

    reg [WIDTH:0] extended_addition;

    always @(alu_op or lhs or rhs or carryin) begin

        // Default values prevent latches.
        result = {WIDTH{1'b0}};
        flags = 5'b00000;
        extended_addition = {(WIDTH+1){1'b0}};

        case (alu_op)

            // Zero-extend the lowest 8 bits of rhs.
            ZEXT: begin
                result = {{(WIDTH-8){1'b0}}, rhs[7:0]};
            end

            // Sign-extend the lowest 8 bits of rhs.
            SEXT: begin
                result = {{(WIDTH-8){rhs[7]}}, rhs[7:0]};
            end

            /*
             * ADD, ADDI, ADDU, ADDUI:
             *     carryin should be 0.
             *
             * ADDC, ADDCI, ADDCU, ADDCUI:
             *     carryin supplies the previous carry flag.
             *
             * The later instruction decoder controls which flags
             * are written into the PSR.
             */
            ADD: begin
                extended_addition =
                    {1'b0, lhs} + {1'b0, rhs} + carryin;

                result = extended_addition[WIDTH-1:0];

                // Carry
                flags[4] = extended_addition[WIDTH];

                // Signed overflow
                flags[1] =
                    ~(lhs[WIDTH-1] ^ rhs[WIDTH-1]) &
                     (lhs[WIDTH-1] ^ result[WIDTH-1]);
            end

            /*
             * SUB and SUBI.
             *
             * This C is set when a borrow occurs. from demo
             */
            SUB: begin
                result = lhs - rhs - carryin;

                // Borrow
                flags[4] =
                    ({1'b0, lhs} < ({1'b0, rhs} + carryin));

                // Unsigned comparison information
                flags[3] = (lhs < rhs);

                // Signed comparison information
                flags[2] = ($signed(lhs) < $signed(rhs));

                // Signed subtraction overflow
                flags[1] =
                    (lhs[WIDTH-1] ^ rhs[WIDTH-1]) &
                    ~(result[WIDTH-1] ^ rhs[WIDTH-1]);

                // Equality
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

            // The lowest WIDTH bits of the product are returned.
            MULT: begin
                result = lhs * rhs;
            end

            // Load the lowest 8 bits of rhs into the upper byte.
            LUI: begin
                result = {rhs[7:0], {(WIDTH-8){1'b0}}};
            end

            /*
             * Logical shift:
             * positive rhs = shift left
             * negative rhs = logical shift right
             */
            LSH: begin
                if (rhs[WIDTH-1] == 1'b0)
                    result = lhs << rhs;
                else
                    result = lhs >> ((~rhs) + 1'b1);
            end

            /*
             * Arithmetic shift:
             * positive rhs = shift left
             * negative rhs = arithmetic shift right
             */
            ASH: begin
                if (rhs[WIDTH-1] == 1'b0)
                    result = lhs << rhs;
                else
                    result =
                        $signed(lhs) >>> ((~rhs) + 1'b1);
            end

            // MOV/pass-through operation.
            PASS: begin
                result = rhs;
            end

            NOT: begin
                result = ~lhs;
            end

            /*
             * Signed comparison.
             * The destination result is not used.
             */
            CMP: begin
                result = {WIDTH{1'b0}};

                // N: signed lhs is less than signed rhs
                flags[2] = ($signed(lhs) < $signed(rhs));

                // Z: operands are equal
                flags[0] = (lhs == rhs);
            end

            /*
             * Unsigned comparison.
             * The destination result is not used.
             */
            CMPU: begin
                result = {WIDTH{1'b0}};

                // L: unsigned lhs is less than unsigned rhs
                flags[3] = (lhs < rhs);

                // Z: operands are equal
                flags[0] = (lhs == rhs);
            end

         
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