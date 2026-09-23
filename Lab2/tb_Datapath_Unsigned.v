`timescale 1ns / 1ps

module tb_Datapath_Unsigned;

    reg clk;
    reg reset;

    reg read_enable_a;
    reg [3:0] read_address_a;
    wire [15:0] read_data_a;

    reg read_enable_b;
    reg [3:0] read_address_b;
    wire [15:0] read_data_b;

    reg write_enable;
    reg [3:0] write_address;

    reg [3:0] alu_op;
    reg use_immediate;
    reg [15:0] immediate_value;
    reg use_carry;

    reg external_load;
    reg [15:0] external_data;

    reg [4:0] flag_write_enable;

    wire [15:0] selected_rhs;
    wire [15:0] alu_result;
    wire [4:0] alu_flags;
    wire [4:0] stored_flags;
    wire [15:0] write_back_data;

    integer errors;

    localparam [3:0] ADD = 4'h2;

    ALU_RegFile_Datapath dut (
        .clk(clk),
        .reset(reset),

        .read_enable_a(read_enable_a),
        .read_address_a(read_address_a),
        .read_data_a(read_data_a),

        .read_enable_b(read_enable_b),
        .read_address_b(read_address_b),
        .read_data_b(read_data_b),

        .write_enable(write_enable),
        .write_address(write_address),

        .alu_op(alu_op),
        .use_immediate(use_immediate),
        .immediate_value(immediate_value),
        .use_carry(use_carry),

        .external_load(external_load),
        .external_data(external_data),

        .flag_write_enable(flag_write_enable),

        .selected_rhs(selected_rhs),
        .alu_result(alu_result),
        .alu_flags(alu_flags),
        .stored_flags(stored_flags),
        .write_back_data(write_back_data)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin

        clk = 1'b0;
        reset = 1'b0;

        read_enable_a = 1'b1;
        read_address_a = 4'd0;

        read_enable_b = 1'b1;
        read_address_b = 4'd0;

        write_enable = 1'b0;
        write_address = 4'd0;

        alu_op = ADD;
        use_immediate = 1'b0;
        immediate_value = 16'h0000;
        use_carry = 1'b0;

        external_load = 1'b0;
        external_data = 16'h0000;

        flag_write_enable = 5'b00000;

        errors = 0;

        // --------------------------------------------------
        // TEST 1: Reset the datapath
        // --------------------------------------------------

        #1;
        reset = 1'b1;
        #1;

        if ((read_data_a === 16'h0000) &&
            (read_data_b === 16'h0000) &&
            (stored_flags === 5'b00000)) begin

            $display("PASS TEST 1: Datapath reset correctly.");
        end
        else begin
            $display("FAIL TEST 1: Datapath reset failed.");
            errors = errors + 1;
        end

        @(negedge clk);
        reset = 1'b0;

        // --------------------------------------------------
        // TEST 2: Load starting value 0 into R0
        // --------------------------------------------------

        external_load = 1'b1;
        external_data = 16'd0;
        write_enable = 1'b1;
        write_address = 4'd0;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd0;
        #1;

        if (read_data_a === 16'd0) begin
            $display("PASS TEST 2: R0 = 0.");
        end
        else begin
            $display("FAIL TEST 2: R0 expected 0, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 3: Load starting value 1 into R1
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'd1;
        write_enable = 1'b1;
        write_address = 4'd1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd1;
        #1;

        if (read_data_a === 16'd1) begin
            $display("PASS TEST 3: R1 = 1.");
        end
        else begin
            $display("FAIL TEST 3: R1 expected 1, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // From this point forward, all data comes from
        // ALU calculations instead of external loading.
        external_load = 1'b0;
        use_immediate = 1'b0;
        use_carry = 1'b0;

        // Store C and F from each ADD operation.
        // All Fibonacci values in this test should keep
        // both C and F equal to zero.
        flag_write_enable = 5'b10010;

        // --------------------------------------------------
        // TEST 4: R2 = R0 + R1 = 1
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd0;
        read_address_b = 4'd1;
        write_address = 4'd2;
        write_enable = 1'b1;
        alu_op = ADD;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd2;
        #1;

        if (read_data_a === 16'd1) begin
            $display("PASS TEST 4: R2 = 1.");
        end
        else begin
            $display("FAIL TEST 4: R2 expected 1, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 5: R3 = R1 + R2 = 2
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd1;
        read_address_b = 4'd2;
        write_address = 4'd3;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd3;
        #1;

        if (read_data_a === 16'd2) begin
            $display("PASS TEST 5: R3 = 2.");
        end
        else begin
            $display("FAIL TEST 5: R3 expected 2, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 6: R4 = R2 + R3 = 3
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd2;
        read_address_b = 4'd3;
        write_address = 4'd4;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd4;
        #1;

        if (read_data_a === 16'd3) begin
            $display("PASS TEST 6: R4 = 3.");
        end
        else begin
            $display("FAIL TEST 6: R4 expected 3, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 7: R5 = R3 + R4 = 5
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd3;
        read_address_b = 4'd4;
        write_address = 4'd5;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd5;
        #1;

        if (read_data_a === 16'd5) begin
            $display("PASS TEST 7: R5 = 5.");
        end
        else begin
            $display("FAIL TEST 7: R5 expected 5, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 8: R6 = R4 + R5 = 8
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd4;
        read_address_b = 4'd5;
        write_address = 4'd6;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd6;
        #1;

        if (read_data_a === 16'd8) begin
            $display("PASS TEST 8: R6 = 8.");
        end
        else begin
            $display("FAIL TEST 8: R6 expected 8, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 9: R7 = R5 + R6 = 13
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd5;
        read_address_b = 4'd6;
        write_address = 4'd7;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd7;
        #1;

        if (read_data_a === 16'd13) begin
            $display("PASS TEST 9: R7 = 13.");
        end
        else begin
            $display("FAIL TEST 9: R7 expected 13, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 10: R8 = R6 + R7 = 21
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd6;
        read_address_b = 4'd7;
        write_address = 4'd8;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd8;
        #1;

        if (read_data_a === 16'd21) begin
            $display("PASS TEST 10: R8 = 21.");
        end
        else begin
            $display("FAIL TEST 10: R8 expected 21, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 11: R9 = R7 + R8 = 34
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd7;
        read_address_b = 4'd8;
        write_address = 4'd9;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd9;
        #1;

        if (read_data_a === 16'd34) begin
            $display("PASS TEST 11: R9 = 34.");
        end
        else begin
            $display("FAIL TEST 11: R9 expected 34, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 12: R10 = R8 + R9 = 55
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd8;
        read_address_b = 4'd9;
        write_address = 4'd10;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd10;
        #1;

        if (read_data_a === 16'd55) begin
            $display("PASS TEST 12: R10 = 55.");
        end
        else begin
            $display("FAIL TEST 12: R10 expected 55, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 13: R11 = R9 + R10 = 89
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd9;
        read_address_b = 4'd10;
        write_address = 4'd11;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd11;
        #1;

        if (read_data_a === 16'd89) begin
            $display("PASS TEST 13: R11 = 89.");
        end
        else begin
            $display("FAIL TEST 13: R11 expected 89, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 14: R12 = R10 + R11 = 144
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd10;
        read_address_b = 4'd11;
        write_address = 4'd12;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd12;
        #1;

        if (read_data_a === 16'd144) begin
            $display("PASS TEST 14: R12 = 144.");
        end
        else begin
            $display("FAIL TEST 14: R12 expected 144, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 15: R13 = R11 + R12 = 233
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd11;
        read_address_b = 4'd12;
        write_address = 4'd13;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd13;
        #1;

        if (read_data_a === 16'd233) begin
            $display("PASS TEST 15: R13 = 233.");
        end
        else begin
            $display("FAIL TEST 15: R13 expected 233, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 16: R14 = R12 + R13 = 377
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd12;
        read_address_b = 4'd13;
        write_address = 4'd14;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd14;
        #1;

        if (read_data_a === 16'd377) begin
            $display("PASS TEST 16: R14 = 377.");
        end
        else begin
            $display("FAIL TEST 16: R14 expected 377, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 17: R15 = R13 + R14 = 610
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd13;
        read_address_b = 4'd14;
        write_address = 4'd15;
        write_enable = 1'b1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        flag_write_enable = 5'b00000;

        read_address_a = 4'd15;
        #1;

        if (read_data_a === 16'd610) begin
            $display("PASS TEST 17: R15 = 610.");
        end
        else begin
            $display("FAIL TEST 17: R15 expected 610, got %d.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 18: Simultaneously read final two values
        // --------------------------------------------------

        read_address_a = 4'd14;
        read_address_b = 4'd15;
        #1;

        if ((read_data_a === 16'd377) &&
            (read_data_b === 16'd610)) begin

            $display("PASS TEST 18: Final values are 377 and 610.");
        end
        else begin
            $display("FAIL TEST 18: R14=%d R15=%d.",
                     read_data_a, read_data_b);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 19: Verify no carry or overflow occurred
        // --------------------------------------------------

        if (stored_flags === 5'b00000) begin
            $display("PASS TEST 19: No carry or overflow occurred.");
        end
        else begin
            $display("FAIL TEST 19: Unexpected stored flags %b.",
                     stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // Final result
        // --------------------------------------------------

        $display("--------------------------------------------------");

        if (errors == 0)
            $display("SUCCESS: UNSIGNED FIBONACCI TEST PASSED.");
        else
            $display("FAIL: %0d UNSIGNED TEST(S) FAILED.", errors);

        $finish;

    end

endmodule