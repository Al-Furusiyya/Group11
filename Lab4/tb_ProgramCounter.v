`timescale 1ns/1ps

module tb_ProgramCounter;

    reg clk;
    reg reset;
    reg enable;
    reg load_enable;
    reg [9:0] load_value;

    wire [9:0] pc;

    integer test_number;
    integer error_count;

    ProgramCounter dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .load_enable(load_enable),
        .load_value(load_value),
        .pc(pc)
    );

    // 10 ns clock period
    always begin
        #5 clk = ~clk;
    end

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        enable = 1'b0;
        load_enable = 1'b0;
        load_value = 10'd0;

        test_number = 0;
        error_count = 0;

        // TEST 1: Asynchronous reset
        reset = 1'b1;
        #1;

        test_number = test_number + 1;

        if (pc == 10'd0) begin
            $display(
                "PASS TEST %0d: Reset cleared the PC.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: Reset did not clear the PC.",
                test_number
            );
        end

        reset = 1'b0;

        // TEST 2: PC holds when no control signal is active.
        @(negedge clk);
        enable = 1'b0;
        load_enable = 1'b0;

        @(posedge clk);
        #1;

        test_number = test_number + 1;

        if (pc == 10'd0) begin
            $display(
                "PASS TEST %0d: PC held its value.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: PC did not hold its value.",
                test_number
            );
        end

        // TEST 3: Normal PC increment
        @(negedge clk);
        enable = 1'b1;
        load_enable = 1'b0;

        @(posedge clk);
        #1;

        test_number = test_number + 1;

        if (pc == 10'd1) begin
            $display(
                "PASS TEST %0d: PC incremented to 1.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: PC expected 1, received %0d.",
                test_number,
                pc
            );
        end

        // TEST 4: Another normal PC increment
        @(posedge clk);
        #1;

        test_number = test_number + 1;

        if (pc == 10'd2) begin
            $display(
                "PASS TEST %0d: PC incremented to 2.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: PC expected 2, received %0d.",
                test_number,
                pc
            );
        end

        // TEST 5: Load a forward branch target.
        @(negedge clk);
        enable = 1'b0;
        load_enable = 1'b1;
        load_value = 10'd20;

        @(posedge clk);
        #1;

        test_number = test_number + 1;

        if (pc == 10'd20) begin
            $display(
                "PASS TEST %0d: PC loaded forward target 20.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: PC expected 20, received %0d.",
                test_number,
                pc
            );
        end

        // TEST 6: Load has priority over increment.
        @(negedge clk);
        enable = 1'b1;
        load_enable = 1'b1;
        load_value = 10'd45;

        @(posedge clk);
        #1;

        test_number = test_number + 1;

        if (pc == 10'd45) begin
            $display(
                "PASS TEST %0d: PC load had priority over increment.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: PC expected 45, received %0d.",
                test_number,
                pc
            );
        end

        // TEST 7: Continue incrementing after a loaded target.
        @(negedge clk);
        enable = 1'b1;
        load_enable = 1'b0;

        @(posedge clk);
        #1;

        test_number = test_number + 1;

        if (pc == 10'd46) begin
            $display(
                "PASS TEST %0d: PC continued from loaded target.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: PC expected 46, received %0d.",
                test_number,
                pc
            );
        end

        // TEST 8: Reset has priority over all other controls.
        enable = 1'b1;
        load_enable = 1'b1;
        load_value = 10'd100;
        reset = 1'b1;

        #1;

        test_number = test_number + 1;

        if (pc == 10'd0) begin
            $display(
                "PASS TEST %0d: Reset had highest priority.",
                test_number
            );
        end
        else begin
            error_count = error_count + 1;
            $display(
                "FAIL TEST %0d: Reset expected PC 0, received %0d.",
                test_number,
                pc
            );
        end

        reset = 1'b0;
        enable = 1'b0;
        load_enable = 1'b0;

        $display("--------------------------------------------");

        if (error_count == 0) begin
            $display(
                "SUCCESS: ALL PROGRAM COUNTER TESTS PASSED."
            );
        end
        else begin
            $display(
                "FAILURE: %0d PROGRAM COUNTER TESTS FAILED.",
                error_count
            );
        end

        $finish;
    end

endmodule