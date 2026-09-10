`timescale 1ns / 1ps

module alu (
    input  wire [15:0] alu_in_a,      
    input  wire [15:0] alu_in_b,    
    input  wire [4:0]  alu_op,        
    input  wire        c_in,        
    output reg  [15:0] alu_out,    
    output reg  [4:0]  alu_flags,     
    output reg  [4:0]  flag_write_en  
);

    wire [15:0] arith_result;
    wire        arith_c, arith_f, arith_z, arith_l, arith_n;
    reg  [3:0]  arith_op;

    wire [15:0] logic_result;
    wire        logic_z;
    reg  [3:0]  logic_op;

    alu_arithmetic u_arith (
        .a(alu_in_a),
        .b(alu_in_b),
        .op(arith_op),
        .c_in(c_in),
        .result(arith_result),
        .flag_c(arith_c),
        .flag_f(arith_f),
        .flag_z(arith_z),
        .flag_l(arith_l),
        .flag_n(arith_n)
    );

    alu_logic_shift u_logic (
        .a(alu_in_a),
        .b(alu_in_b),
        .op(logic_op),
        .result(logic_result),
        .flag_z(logic_z)
    );

    always @(alu_in_a, alu_in_b, alu_op, c_in) begin
        arith_op      = 4'b0000;
        logic_op      = 4'b0000;
        alu_out       = 16'h0000;
        alu_flags     = 5'b00000;
        flag_write_en = 5'b00000;

        case (alu_op)
            // NOP / WAIT
            5'd0: begin
                alu_out       = 16'h0000;
                alu_flags     = 5'b00000;
                flag_write_en = 5'b00000; // Do not touch flags
            end

            // ADD / ADDI
            5'd1: begin
                arith_op      = 4'b0000;
                alu_out       = arith_result;
                alu_flags[4]  = arith_c;  // C
                alu_flags[3]  = arith_f;  // F
                flag_write_en = 5'b11000; // Update C and F only
            end

            // ADDU / ADDUI (Unsigned ADD: no flags updated)
            5'd2: begin
                arith_op      = 4'b0001;
                alu_out       = arith_result;
                flag_write_en = 5'b00000;
            end

            // ADDC / ADDCI (Add with carry)
            5'd3: begin
                arith_op      = 4'b0010;
                alu_out       = arith_result;
                alu_flags[4]  = arith_c;
                alu_flags[3]  = arith_f;
                flag_write_en = 5'b11000;
            end

            // SUB / SUBI
            5'd4: begin
                arith_op      = 4'b0011;
                alu_out       = arith_result;
                alu_flags[4]  = arith_c;
                alu_flags[3]  = arith_f;
                flag_write_en = 5'b11000;
            end

            // SUBC / SUBCI
            5'd5: begin
                arith_op      = 4'b0100;
                alu_out       = arith_result;
                alu_flags[4]  = arith_c;
                alu_flags[3]  = arith_f;
                flag_write_en = 5'b11000;
            end

            // CMP / CMPI (Signed Comparison)
            5'd6: begin
                arith_op      = 4'b0101;
                alu_out       = 16'h0000; // Result is discarded
                alu_flags[2]  = arith_z;  // Z
                alu_flags[1]  = arith_l;  // L
                alu_flags[0]  = arith_n;  // N
                flag_write_en = 5'b00111; // Update Z, L, N
            end

            // CMPU / CMPUI (Unsigned Comparison)
            5'd7: begin
                arith_op      = 4'b0101;     // Reuses the same op-code as CMP/CMPI, as op 0101 does the same process for both signed and unsigned.
                alu_out       = 16'h0000;
                alu_flags[2]  = arith_z;
                alu_flags[1]  = arith_l;
                flag_write_en = 5'b00110; // Update Z, L
            end

            // AND / ANDI
            5'd8: begin
                logic_op      = 4'b0000;
                alu_out       = logic_result;
                alu_flags[2]  = logic_z;
                flag_write_en = 5'b00100; // Update Z flag
            end

            // OR / ORI
            5'd9: begin
                logic_op      = 4'b0001;
                alu_out       = logic_result;
                alu_flags[2]  = logic_z;
                flag_write_en = 5'b00100;
            end

            // XOR / XORI
            5'd10: begin
                logic_op      = 4'b0010;
                alu_out       = logic_result;
                alu_flags[2]  = logic_z;
                flag_write_en = 5'b00100;
            end

            // NOT
            5'd11: begin
                logic_op      = 4'b0011;
                alu_out       = logic_result;
                alu_flags[2]  = logic_z;
                flag_write_en = 5'b00100;
            end

            // MOV / MOVI
            5'd12: begin
                logic_op      = 4'b0100;
                alu_out       = logic_result;
                flag_write_en = 5'b00000;
            end

            // LSH / LSHI
            5'd13: begin
                logic_op      = 4'b0101;
                alu_out       = logic_result;
                flag_write_en = 5'b00000;
            end

            // ASHU / ASHUI
            5'd14: begin
                logic_op      = 4'b0110;
                alu_out       = logic_result;
                flag_write_en = 5'b00000;
            end

            // LUI
            5'd15: begin
                logic_op      = 4'b0111;
                alu_out       = logic_result;
                flag_write_en = 5'b00000;
            end

            // ADDCU / ADDCUI 
            5'd16: begin
                arith_op      = 4'b0010; // same math as OP_ADDC, c_in still used
                alu_out       = arith_result;
                flag_write_en = 5'b00000; // diff from ADDC don't latch C/F
            end

            default: begin
                alu_out       = 16'h0000;
                alu_flags     = 5'b00000;
                flag_write_en = 5'b00000;
            end
        endcase
    end

endmodule
