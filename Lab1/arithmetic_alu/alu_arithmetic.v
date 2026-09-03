`timescale 1ns / 1ps

module alu_arithmetic (
    input  wire [15:0] a,          
    input  wire [15:0] b,          
    input  wire [3:0]  op,         
    input  wire        c_in,       
    output reg  [15:0] result,     
    output reg         flag_c,    
    output reg         flag_f,  
    output reg         flag_z,     
    output reg         flag_l,     
    output reg         flag_n      
);

   
    reg [16:0] sum_ext;
    reg [16:0] diff_ext;

    localparam OP_ADD  = 4'b0000; // ADD / ADDI
    localparam OP_ADDU = 4'b0001; // ADDU / ADDUI
    localparam OP_ADDC = 4'b0010; // ADDC / ADDCI
    localparam OP_SUB  = 4'b0011; // SUB / SUBI
    localparam OP_SUBC = 4'b0100; // SUBC / SUBCI
    localparam OP_CMP  = 4'b0101; // CMP / CMPI (Signed compare)
    localparam OP_CMPU = 4'b0110; // CMPU / CMPUI (Unsigned compare)

    always @(*) begin
        // Default assignments to prevent accidental latches
        sum_ext  = 17'b0;
        diff_ext = 17'b0;
        result   = 16'b0;
        flag_c   = 1'b0;
        flag_f   = 1'b0;
        flag_z   = 1'b0;
        flag_l   = 1'b0;
        flag_n   = 1'b0;

        case (op)
            OP_ADD, OP_ADDU: begin
                sum_ext = {1'b0, a} + {1'b0, b};
                result  = sum_ext[15:0];
                flag_c  = sum_ext[16];
                // Overflow occurred if inputs had same sign but output sign differs
                flag_f  = (a[15] == b[15]) && (result[15] != a[15]);
            end

            OP_ADDC: begin
                sum_ext = {1'b0, a} + {1'b0, b} + c_in;
                result  = sum_ext[15:0];
                flag_c  = sum_ext[16];
                flag_f  = (a[15] == b[15]) && (result[15] != a[15]);
            end

            OP_SUB: begin
                diff_ext = {1'b0, a} - {1'b0, b};
                result   = diff_ext[15:0];
                flag_c   = diff_ext[16]; // Borrow indicator
                // Overflow occurred if signs were different and result sign differs from a
                flag_f   = (a[15] != b[15]) && (result[15] != a[15]);
            end

            OP_SUBC: begin
                diff_ext = {1'b0, a} - {1'b0, b} - c_in;
                result   = diff_ext[15:0];
                flag_c   = diff_ext[16];
                flag_f   = (a[15] != b[15]) && (result[15] != a[15]);
            end

            OP_CMP, OP_CMPU: begin
                diff_ext = {1'b0, a} - {1'b0, b};
                // CMP does not write back to destination register
                result   = 16'b0;
                
                // Zero flag: set if operands are equal
                flag_z   = (a == b);
                
                // Low flag (unsigned comparison: a < b)
                flag_l   = (a < b);
                
                // Negative flag (signed comparison: a < b)
                // Calculated as L XOR sign bits, or direct signed check:
                flag_n   = ($signed(a) < $signed(b));
            end

            default: begin
                result   = 16'b0;
                flag_c   = 1'b0;
                flag_f   = 1'b0;
                flag_z   = 1'b0;
                flag_l   = 1'b0;
                flag_n   = 1'b0;
            end
        endcase
    end

endmodule