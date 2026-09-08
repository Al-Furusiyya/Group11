`timescale 1ns / 1ps

module tb_alu_logic_shift;

    reg  [15:0] a;
    reg  [15:0] b;
    reg  [3:0]  op;
    wire [15:0] result;
    wire        flag_z;

    alu_logic_shift dut (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .flag_z(flag_z)
    );

    integer errors;

    initial begin
        errors = 0;
        a = 16'h0000;
        b = 16'h0000;
        op = 4'b0000;

        #10;

        // Test 1: Bitwise AND
        a = 16'hF0F0; b = 16'hAAAA; op = 4'b0000;
        #10;
        if (result !== 16'hA0A0 || flag_z !== 0) begin
            $display("ERROR: AND failed. result=%h", result);
            errors = errors + 1;
        end

        // Test 2: Bitwise OR
        a = 16'hF0F0; b = 16'h0F0F; op = 4'b0001;
        #10;
        if (result !== 16'hFFFF) begin
            $display("ERROR: OR failed. result=%h", result);
            errors = errors + 1;
        end

        // Test 3: Bitwise NOT
        b = 16'h00FF; op = 4'b0011;
        #10;
        if (result !== 16'hFF00) begin
            $display("ERROR: NOT failed. result=%h", result);
            errors = errors + 1;
        end

        // Test 4: Logical Shift Left by 2 (1 << 2 = 4)
        a = 16'h0001; b = 16'd2; op = 4'b0101;
        #10;
        if (result !== 16'h0004) begin
            $display("ERROR: LSH left failed. result=%h", result);
            errors = errors + 1;
        end

        // Test 5: Logical Shift Right by 2 (-2 in signed 5-bit)
        // b[4:0] = 5'b11110 (-2)
        a = 16'h0008; b = 16'hFFE; op = 4'b0101;
        #10;
        if (result !== 16'h0002) begin
            $display("ERROR: LSH right failed. result=%h", result);
            errors = errors + 1;
        end

        // Test 6: Arithmetic Shift Right (sign-extension check)
        // a = 0x8004 (negative), b = -2 -> should preserve MSB: 0xE001
        a = 16'h8004; b = 16'hFFE; op = 4'b0110;
        #10;
        if (result !== 16'hE001) begin
            $display("ERROR: Arithmetic Shift Right failed. result=%h", result);
            errors = errors + 1;
        end

        // Test 7: Load Upper Immediate (LUI)
        b = 16'h00AB; op = 4'b0111;
        #10;
        if (result !== 16'hAB00) begin
            $display("ERROR: LUI failed. result=%h", result);
            errors = errors + 1;
        end

        // Test 8: Zero Flag Check
        a = 16'h00FF; b = 16'hFF00; op = 4'b0000; // AND with no overlap
        #10;
        if (result !== 16'h0000 || flag_z !== 1) begin
            $display("ERROR: Zero flag test failed. result=%h, z=%b", result, flag_z);
            errors = errors + 1;
        end

        #10;
        if (errors == 0)
            $display("SUCCESS: ALL LOGIC AND SHIFTER TESTS PASSED!");
        else
            $display("FAIL: %0d error(s) found.", errors);

        $stop;
    end

endmodule