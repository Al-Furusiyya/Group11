`timescale 1ns / 1ps

module tb_alu_arithmetic;

    reg  [15:0] a;
    reg  [15:0] b;
    reg  [3:0]  op;
    reg         c_in;
    wire [15:0] result;
    wire        flag_c;
    wire        flag_f;
    wire        flag_z;
    wire        flag_l;
    wire        flag_n;

    // Instantiate Device Under Test (DUT)
    alu_arithmetic dut (
        .a(a),
        .b(b),
        .op(op),
        .c_in(c_in),
        .result(result),
        .flag_c(flag_c),
        .flag_f(flag_f),
        .flag_z(flag_z),
        .flag_l(flag_l),
        .flag_n(flag_n)
    );

    integer errors;

    initial begin
        errors = 0;
        a = 16'h0000;
        b = 16'h0000;
        op = 4'b0000;
        c_in = 1'b0;

        #10;

        // Test 1: Simple ADD (5 + 3 = 8)
        a = 16'd5; b = 16'd3; op = 4'b0000; c_in = 0;
        #10;
        if (result !== 16'd8 || flag_c !== 0 || flag_f !== 0) begin
            $display("ERROR: ADD 5 + 3 failed. result=%d, c=%b, f=%b", result, flag_c, flag_f);
            errors = errors + 1;
        end

        // Test 2: Unsigned ADD with Carry Out (0xFFFF + 1 = 0x0000, C=1)
        a = 16'hFFFF; b = 16'h0001; op = 4'b0000; c_in = 0;
        #10;
        if (result !== 16'h0000 || flag_c !== 1) begin
            $display("ERROR: Unsigned ADD carry failed. result=%h, c=%b", result, flag_c);
            errors = errors + 1;
        end

        // Test 3: Signed ADD Overflow (0x7FFF + 1 = 0x8000, F=1)
        a = 16'h7FFF; b = 16'h0001; op = 4'b0000; c_in = 0;
        #10;
        if (result !== 16'h8000 || flag_f !== 1) begin
            $display("ERROR: Signed overflow failed. result=%h, f=%b", result, flag_f);
            errors = errors + 1;
        end

        // Test 4: ADDC with Carry-In (10 + 20 + 1 = 31)
        a = 16'd10; b = 16'd20; op = 4'b0010; c_in = 1;
        #10;
        if (result !== 16'd31) begin
            $display("ERROR: ADDC failed. result=%d", result);
            errors = errors + 1;
        end

        // Test 5: SUB (10 - 4 = 6)
        a = 16'd10; b = 16'd4; op = 4'b0011; c_in = 0;
        #10;
        if (result !== 16'd6) begin
            $display("ERROR: SUB 10 - 4 failed. result=%d", result);
            errors = errors + 1;
        end

        // Test 6: CMP Equal (a == b -> Z=1, L=0, N=0)
        a = 16'h1234; b = 16'h1234; op = 4'b0101; c_in = 0;
        #10;
        if (flag_z !== 1 || flag_l !== 0 || flag_n !== 0) begin
            $display("ERROR: CMP Equal failed. z=%b, l=%b, n=%b", flag_z, flag_l, flag_n);
            errors = errors + 1;
        end

        // Test 7: CMP Unsigned Low vs Signed Neg (-1 vs 1)
        // a = 0xFFFF (-1 signed, 65535 unsigned), b = 0x0001 (1)
        // Signed: a < b (-1 < 1) -> flag_n = 1
        // Unsigned: a > b (65535 > 1) -> flag_l = 0
        a = 16'hFFFF; b = 16'h0001; op = 4'b0101; c_in = 0;
        #10;
        if (flag_n !== 1 || flag_l !== 0) begin
            $display("ERROR: CMP signed/unsigned branch failed. n=%b, l=%b", flag_n, flag_l);
            errors = errors + 1;
        end

        // Final summary output
        #10;
        if (errors == 0)
            $display("SUCCESS: ALL ARITHMETIC TESTS PASSED!");
        else
            $display("FAIL: %0d error(s) found.", errors);

        $stop;
    end

endmodule