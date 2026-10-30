`timescale 1ns/1ps

module tb_InstructionDecoder;

    reg [15:0] instruction;

    wire [3:0] alu_op;
    wire use_immediate;
    wire [15:0] immediate_value;
    wire use_carry;

    wire register_write;
    wire [4:0] flag_write_enable;
    wire valid_execute;

    wire is_load;
    wire is_store;

    wire is_branch;
    wire is_jump;
    wire [3:0] condition_code;
    wire [9:0] branch_offset;

    integer test_number;
    integer error_count;

    InstructionDecoder dut (
        .instruction(instruction),

        .alu_op(alu_op),
        .use_immediate(use_immediate),
        .immediate_value(immediate_value),
        .use_carry(use_carry),

        .register_write(register_write),
        .flag_write_enable(flag_write_enable),
        .valid_execute(valid_execute),

        .is_load(is_load),
        .is_store(is_store),

        .is_branch(is_branch),
        .is_jump(is_jump),
        .condition_code(condition_code),
        .branch_offset(branch_offset)
    );

    initial begin
        test_number = 0;
        error_count = 0;
        instruction = 16'h0000;

        #1;

        // TEST 1: BEQ with a positive displacement of 5.
        test_number = test_number + 1;
        instruction = 16'hC005;
        #1;

        if ((is_branch == 1'b1) &&
            (is_jump == 1'b0) &&
            (condition_code == 4'h0) &&
            (branch_offset == 10'h005)) begin

            $display(
                "PASS TEST %0d: BEQ +5 decoded correctly.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: BEQ +5 decoding is incorrect.",
                test_number
            );
        end

        // TEST 2: BNE with a negative displacement of 3.
        // 8-bit FD represents -3.
        // Sign-extended to 10 bits, this becomes 3FD.
        test_number = test_number + 1;
        instruction = 16'hC1FD;
        #1;

        if ((is_branch == 1'b1) &&
            (is_jump == 1'b0) &&
            (condition_code == 4'h1) &&
            (branch_offset == 10'h3FD)) begin

            $display(
                "PASS TEST %0d: BNE -3 decoded correctly.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: BNE -3 decoding is incorrect.",
                test_number
            );
        end

        // TEST 3: Unconditional branch with displacement +2.
        test_number = test_number + 1;
        instruction = 16'hCE02;
        #1;

        if ((is_branch == 1'b1) &&
            (condition_code == 4'hE) &&
            (branch_offset == 10'h002)) begin

            $display(
                "PASS TEST %0d: BUC +2 decoded correctly.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: BUC +2 decoding is incorrect.",
                test_number
            );
        end

        // TEST 4: JEQ using R3 as the target register.
        // Encoding: 0100 0000 1100 0011
        test_number = test_number + 1;
        instruction = 16'h40C3;
        #1;

        if ((is_jump == 1'b1) &&
            (is_branch == 1'b0) &&
            (condition_code == 4'h0)) begin

            $display(
                "PASS TEST %0d: JEQ R3 decoded correctly.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: JEQ R3 decoding is incorrect.",
                test_number
            );
        end

        // TEST 5: Unconditional jump using R5.
        // Encoding: 0100 1110 1100 0101
        test_number = test_number + 1;
        instruction = 16'h4EC5;
        #1;

        if ((is_jump == 1'b1) &&
            (is_branch == 1'b0) &&
            (condition_code == 4'hE)) begin

            $display(
                "PASS TEST %0d: JUC R5 decoded correctly.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: JUC R5 decoding is incorrect.",
                test_number
            );
        end

        // TEST 6: LOAD should not be decoded as a branch or jump.
        // LOAD R1, R2
        test_number = test_number + 1;
        instruction = 16'h4102;
        #1;

        if ((is_load == 1'b1) &&
            (is_branch == 1'b0) &&
            (is_jump == 1'b0)) begin

            $display(
                "PASS TEST %0d: LOAD remains correctly decoded.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: LOAD decoding was affected.",
                test_number
            );
        end

        // TEST 7: STORE should not be decoded as a branch or jump.
        // STOR R1, R2
        test_number = test_number + 1;
        instruction = 16'h4142;
        #1;

        if ((is_store == 1'b1) &&
            (is_branch == 1'b0) &&
            (is_jump == 1'b0)) begin

            $display(
                "PASS TEST %0d: STORE remains correctly decoded.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: STORE decoding was affected.",
                test_number
            );
        end

        // TEST 8: ADDI should still execute normally.
        // ADDI R1, 5
        test_number = test_number + 1;
        instruction = 16'h5105;
        #1;

        if ((valid_execute == 1'b1) &&
            (register_write == 1'b1) &&
            (use_immediate == 1'b1) &&
            (immediate_value == 16'h0005) &&
            (is_branch == 1'b0) &&
            (is_jump == 1'b0)) begin

            $display(
                "PASS TEST %0d: ADDI remains correctly decoded.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: ADDI decoding was affected.",
                test_number
            );
        end

        $display("--");

        if (error_count == 0) begin
            $display(
                "SUCCESS: ALL BRANCH AND JUMP DECODER TESTS PASSED."
            );
        end
        else begin
            $display(
                "FAILURE: %0d DECODER TESTS FAILED.",
                error_count
            );
        end

        $finish;
    end

endmodule