`timescale 1ns / 1ps

module tb_ALU;

    reg [3:0] alu_op;
    reg [15:0] lhs;
    reg [15:0] rhs;
    reg carryin;
    wire [15:0] result;
    wire [4:0] flags;

    integer tests;
    integer errors;

    ALU dut (
        .alu_op(alu_op),
        .lhs(lhs),
        .rhs(rhs),
        .carryin(carryin),
        .result(result),
        .flags(flags)
    );

    task check;
        input [3:0] test_op;
        input [15:0] test_lhs;
        input [15:0] test_rhs;
        input test_carryin;
        input [15:0] expected_result;
        input [4:0] expected_flags;
        input [4:0] flag_mask;
        begin
            alu_op = test_op;
            lhs = test_lhs;
            rhs = test_rhs;
            carryin = test_carryin;
            #10;
            tests = tests + 1;

            if ((result !== expected_result) ||
                ((flags & flag_mask) !== (expected_flags & flag_mask))) begin
                errors = errors + 1;
                $display("FAIL op=%h lhs=%h rhs=%h cin=%b result=%h expected=%h flags=%b expected_flags=%b mask=%b",
                         alu_op, lhs, rhs, carryin, result, expected_result,
                         flags, expected_flags, flag_mask);
            end
            else begin
                $display("PASS op=%h lhs=%h rhs=%h cin=%b result=%h flags=%b",
                         alu_op, lhs, rhs, carryin, result, flags);
            end
        end
    endtask

    initial begin
        tests = 0;
        errors = 0;
        alu_op = 0;
        lhs = 0;
        rhs = 0;
        carryin = 0;
        #10;

        check(4'h0, 16'h1234, 16'hFF80, 0, 16'h0080, 5'b00000, 5'b00000); // ZEXT
        check(4'h1, 16'h1234, 16'h0080, 0, 16'hFF80, 5'b00000, 5'b00000); // SEXT

        check(4'h2, 16'h0005, 16'h0003, 0, 16'h0008, 5'b00000, 5'b10010); // ADD
        check(4'h2, 16'hFFFF, 16'h0000, 1, 16'h0000, 5'b10000, 5'b10010); // carry
        check(4'h2, 16'h7FFF, 16'h0001, 0, 16'h8000, 5'b00010, 5'b10010); // overflow

        check(4'h3, 16'h000A, 16'h0004, 0, 16'h0006, 5'b00000, 5'b11111); // SUB
        check(4'h3, 16'h0003, 16'h0004, 0, 16'hFFFF, 5'b11100, 5'b11111); // low
        check(4'h3, 16'h1234, 16'h1234, 0, 16'h0000, 5'b00001, 5'b11111); // equal
        check(4'h3, 16'hFFFF, 16'h0001, 0, 16'hFFFE, 5'b00100, 5'b11111); // signed low
        check(4'h3, 16'h8000, 16'h0001, 0, 16'h7FFF, 5'b00110, 5'b11111); // overflow

        check(4'h4, 16'hF0F0, 16'hAAAA, 0, 16'hA0A0, 5'b00000, 5'b00000); // AND
        check(4'h5, 16'hF000, 16'h0F0F, 0, 16'hFF0F, 5'b00000, 5'b00000); // OR
        check(4'h6, 16'hFFFF, 16'h0F0F, 0, 16'hF0F0, 5'b00000, 5'b00000); // XOR
        check(4'h7, 16'h0003, 16'h0004, 0, 16'h000C, 5'b00000, 5'b00000); // MULT
        check(4'h8, 16'h0000, 16'h00AB, 0, 16'hAB00, 5'b00000, 5'b00000); // LUI
        check(4'h9, 16'h0001, 16'h0002, 0, 16'h0004, 5'b00000, 5'b00000); // LSH left
        check(4'h9, 16'h0008, 16'hFFFE, 0, 16'h0002, 5'b00000, 5'b00000); // LSH right
        check(4'hA, 16'h8004, 16'hFFFE, 0, 16'hE001, 5'b00000, 5'b00000); // ASH right
        check(4'hB, 16'h1111, 16'hCAFE, 0, 16'hCAFE, 5'b00000, 5'b00000); // PASS
        check(4'hC, 16'h00FF, 16'h1234, 0, 16'hFF00, 5'b00000, 5'b00000); // NOT

        $display("----");
        if (errors == 0)
            $display("SUCCESS: all %0d ALU tests passed", tests);
        else
            $display("FAILURE: %0d of %0d ALU tests failed", errors, tests);

        $finish;
    end

endmodule
