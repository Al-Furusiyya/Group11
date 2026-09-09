`timescale 1ns / 1ps

module tb_alu_logic_shift;

    reg  [15:0] a;
    reg  [15:0] b;
    reg  [3:0]  op;
    wire [15:0] result;
    wire        flag_z;

    // Instantiate the device under the test
    alu_logic_shift dut (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .flag_z(flag_z)
    );

    initial begin
        $display("testing alu");
        $display("----------------------------");

        // Simple alu logic tests.
        //
        //
        //
        //

        // test 1 AND
        a=16'hF0F0; b=16'hAAAA; op=4'b0000; #10;
        $display("AND  %b AND %b   =   %b", a, b, result);

        // test 2 OR
        a=16'hF0F0; b=16'h0F0F; op=4'b0001; #10;
        $display("OR   %b OR  %b   =   %b", a, b, result);

        // test 3 XOR
        a=16'hFFFF; b=16'h0F0F; op=4'b0010; #10;
        $display("XOR  %b XOR %b   =   %b", a, b, result);

        // test 4 NOT
        a=16'h0000; b=16'h00FF; op=4'b0011; #10;
        $display("NOT  %b          =   %b", b, result);

        // test 5 Logical Shift Left by 2
        a=16'h0001; b=16'd2; op=4'b0101; #10;
        $display("LSH  %b shift %b   =   %b", a, b, result);

        // test 6 Logical Shift Right by 2
        // b[4:0] = 11110 = -2
        a=16'h0008; b=16'hFFFE; op=4'b0101; #10;
        $display("LSH  %b shift %b   =   %b", a, b, result);

        // test 7 Arithmetic Shift Right by 2
        a=16'h8004; b=16'hFFFE; op=4'b0110; #10;
        $display("ASH  %b shift %b   =   %b", a, b, result);

        // test 8 Load Upper Immediate
        a=16'h0000; b=16'h00AB; op=4'b0111; #10;
        $display("LUI  %b          =   %b", b, result);

        // test 9 Zero Flag
        a=16'h00FF; b=16'hFF00; op=4'b0000; #10;
        $display("AND  %b AND %b   =   %b   Z=%b", a, b, result, flag_z);

        $display("----------------------------");
        $display("testing complete");

        $finish;
    end

endmodule
