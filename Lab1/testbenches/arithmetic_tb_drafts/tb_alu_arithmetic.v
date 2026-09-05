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

	 initial begin
	 $display("testing alu");
    $display("----------------------------");
	 
		 // Simple alu operation tests.
	 //
	 //
	 //
	 //

	   // test 1 ADD 2 + 3 = 5
        a=16'b0000000000000010; b=16'b0000000000000011; op=4'b0000; c_in=0; #10;
        $display("ADD  %b + %b   =   %b", a, b, result);

        // test 2 ADDU 4 + 5 = 9
        a=16'b0000000000000100; b=16'b0000000000000101; op=4'b0001; c_in=0; #10;
        $display("ADDU %b + %b   =   %b", a, b, result);

        // test 3 ADDC 2 + 3 + 1 = 6
        a=16'b0000000000000010; b=16'b0000000000000011; op=4'b0010; c_in=1; #10;
        $display("ADDC %b + %b + %b   =   %b", a, b, c_in, result);

        // test 4 SUB 5 - 3 = 2
        a=16'b0000000000000101; b=16'b0000000000000011; op=4'b0011; c_in=0; #10;
        $display("SUB  %b - %b   =   %b", a, b, result);

        // test 5 SUBC 5 - 3 - 1 = 1
        a=16'b0000000000000101; b=16'b0000000000000011; op=4'b0100; c_in=1; #10;
        $display("SUBC %b - %b - %b   =   %b", a, b, c_in, result);

        // test 6 CMP same numbers should set zero flag
        a=16'b0000000000000101; b=16'b0000000000000101; op=4'b0101; c_in=0; #10;
        $display("CMP  %b %b   Z=%b L=%b N=%b", a, b, flag_z, flag_l, flag_n);

        // test 7 CMPU smaller number should set low flag
        a=16'b0000000000000011; b=16'b0000000000000101; op=4'b0110; c_in=0; #10;
        $display("CMPU %b %b   Z=%b L=%b N=%b", a, b, flag_z, flag_l, flag_n);
		  $display("----------------------------");
        $display("testing complete");

        $finish;
    end

endmodule
