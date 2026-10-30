`timescale 1ns/1ps

module tb_CPUControl;

    reg clk;
    reg reset;

    reg valid_execute;
    reg is_load;
    reg is_store;
    reg is_branch;
    reg is_jump;

    wire instruction_memory_enable;
    wire data_memory_enable;
    wire data_memory_write;

    wire instruction_enable;
    wire pc_enable;
    wire execute_enable;
    wire load_write_enable;
    wire branch_jump_enable;

    wire [2:0] state;

    integer test_number;
    integer error_count;

    CPUControl dut (
        .clk(clk),
        .reset(reset),

        .valid_execute(valid_execute),
        .is_load(is_load),
        .is_store(is_store),
        .is_branch(is_branch),
        .is_jump(is_jump),

        .instruction_memory_enable(instruction_memory_enable),
        .data_memory_enable(data_memory_enable),
        .data_memory_write(data_memory_write),

        .instruction_enable(instruction_enable),
        .pc_enable(pc_enable),
        .execute_enable(execute_enable),
        .load_write_enable(load_write_enable),
        .branch_jump_enable(branch_jump_enable),

        .state(state)
    );

    // 10 ns clock period
    always begin
        #5 clk = ~clk;
    end

    initial begin
        clk = 1'b0;
        reset = 1'b0;

        valid_execute = 1'b0;
        is_load = 1'b0;
        is_store = 1'b0;
        is_branch = 1'b0;
        is_jump = 1'b0;

        test_number = 0;
        error_count = 0;

        // TEST 1: Reset should place the FSM in FETCH.
        reset = 1'b1;
        #1;

        test_number = test_number + 1;

        if ((state == 3'd0) &&
            (instruction_memory_enable == 1'b1)) begin

            $display(
                "PASS TEST %0d: Reset entered FETCH.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: Reset did not enter FETCH.",
                test_number
            );
        end

        reset = 1'b0;

        // FETCH to CAPTURE
        @(posedge clk);
        #1;

        // TEST 2: CAPTURE should enable the instruction register
        // and normal PC increment.
        test_number = test_number + 1;

        if ((state == 3'd1) &&
            (instruction_enable == 1'b1) &&
            (pc_enable == 1'b1)) begin

            $display(
                "PASS TEST %0d: CAPTURE controls are correct.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: CAPTURE controls are incorrect.",
                test_number
            );
        end

        // CAPTURE to DECODE
        @(posedge clk);
        #1;

        // Select a branch while the FSM is in DECODE.
        @(negedge clk);
        is_branch = 1'b1;

        // DECODE to BRANCH_JUMP
        @(posedge clk);
        #1;

        // TEST 3: A branch should enter state 7.
        test_number = test_number + 1;

        if ((state == 3'd7) &&
            (branch_jump_enable == 1'b1)) begin

            $display(
                "PASS TEST %0d: Branch entered BRANCH_JUMP.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: Branch did not enter BRANCH_JUMP.",
                test_number
            );
        end

        // Clear branch input.
        @(negedge clk);
        is_branch = 1'b0;

        // BRANCH_JUMP to FETCH
        @(posedge clk);
        #1;

        // TEST 4: BRANCH_JUMP should return to FETCH.
        test_number = test_number + 1;

        if ((state == 3'd0) &&
            (branch_jump_enable == 1'b0)) begin

            $display(
                "PASS TEST %0d: Branch returned to FETCH.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: Branch did not return to FETCH.",
                test_number
            );
        end

        // Move through FETCH and CAPTURE to DECODE again.
        @(posedge clk);
        #1;

        @(posedge clk);
        #1;

        // Select a jump while the FSM is in DECODE.
        @(negedge clk);
        is_jump = 1'b1;

        // DECODE to BRANCH_JUMP
        @(posedge clk);
        #1;

        // TEST 5: A jump should also enter state 7.
        test_number = test_number + 1;

        if ((state == 3'd7) &&
            (branch_jump_enable == 1'b1)) begin

            $display(
                "PASS TEST %0d: Jump entered BRANCH_JUMP.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: Jump did not enter BRANCH_JUMP.",
                test_number
            );
        end

        // Clear jump input.
        @(negedge clk);
        is_jump = 1'b0;

        // BRANCH_JUMP to FETCH
        @(posedge clk);
        #1;

        // TEST 6: Jump should return to FETCH.
        test_number = test_number + 1;

        if ((state == 3'd0) &&
            (branch_jump_enable == 1'b0)) begin

            $display(
                "PASS TEST %0d: Jump returned to FETCH.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: Jump did not return to FETCH.",
                test_number
            );
        end

        $display("--------------------------------------------");

        if (error_count == 0) begin
            $display(
                "SUCCESS: ALL BRANCH AND JUMP FSM TESTS PASSED."
            );
        end
        else begin
            $display(
                "FAILURE: %0d FSM TESTS FAILED.",
                error_count
            );
        end

        $finish;
    end

endmodule