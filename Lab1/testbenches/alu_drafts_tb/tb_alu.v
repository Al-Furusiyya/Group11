`timescale 1ns / 1ps

module tb_alu;

    reg  [15:0] alu_in_a;
    reg  [15:0] alu_in_b;
    reg  [4:0]  alu_op;
    reg         c_in;
    wire [15:0] alu_out;
    wire [4:0]  alu_flags;     // {C, F, Z, L, N}
    wire [4:0]  flag_write_en;

    alu dut (
        .alu_in_a(alu_in_a),
        .alu_in_b(alu_in_b),
        .alu_op(alu_op),
        .c_in(c_in),
        .alu_out(alu_out),
        .alu_flags(alu_flags),
        .flag_write_en(flag_write_en)
    );

    integer errors;

    initial begin
        errors = 0;
        alu_in_a = 16'h0000;
        alu_in_b = 16'h0000;
        alu_op   = 5'd0;
        c_in     = 1'b0;

        #10;

        // ADD (15 + 25 = 40)
        alu_in_a = 16'd15; alu_in_b = 16'd25; alu_op = 5'd1; c_in = 0;
        #10;
        if (alu_out !== 16'd40 || flag_write_en !== 5'b11000) begin
            $display("ERROR: Integrated ADD failed. out=%d, wen=%b", alu_out, flag_write_en);
            errors = errors + 1;
        end

        // ADDU 
        alu_in_a = 16'd10; alu_in_b = 16'd20; alu_op = 5'd2;
        #10;
        if (alu_out !== 16'd30 || flag_write_en !== 5'b00000) begin
            $display("ERROR: ADDU failed. out=%d, wen=%b", alu_out, flag_write_en);
            errors = errors + 1;
        end

        // CMP (check flag routing: Z, L, N)
        // a = 5, b = 10 -> a < b, so Z=0, L=1 (unsigned), N=1 (signed)
        alu_in_a = 16'd5; alu_in_b = 16'd10; alu_op = 5'd6;
        #10;
        if (alu_flags[2] !== 0 || alu_flags[1] !== 1 || alu_flags[0] !== 1 || flag_write_en !== 5'b00111) begin
            $display("ERROR: CMP flag routing failed. flags={C,F,Z,L,N}=%b, wen=%b", alu_flags, flag_write_en);
            errors = errors + 1;
        end

        // Logic OR
        alu_in_a = 16'h00F0; alu_in_b = 16'h000F; alu_op = 5'd9;
        #10;
        if (alu_out !== 16'h00FF || flag_write_en !== 5'b00100) begin
            $display("ERROR: OR failed. out=%h", alu_out);
            errors = errors + 1;
        end

        // Logical Shift Left by 4 (0x0002 << 4 = 0x0020)
        alu_in_a = 16'h0002; alu_in_b = 16'd4; alu_op = 5'd13;
        #10;
        if (alu_out !== 16'h0020) begin
            $display("ERROR: LSH failed. out=%h", alu_out);
            errors = errors + 1;
        end

        #10;
        if (errors == 0)
            $display("SUCCESS: ALL TOP-LEVEL ALU INTEGRATION TESTS PASSED!");
        else
            $display("FAIL: %0d error(s) found in ALU top.", errors);

        $stop;
    end

endmodule