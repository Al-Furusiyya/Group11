`timescale 1ns / 1ps

module tb_Datapath_Signed;

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
    localparam [3:0] SUB = 4'h3;
    localparam [3:0] ASH = 4'hA;
    localparam [3:0] CMP = 4'hD;

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
        // TEST 1: Reset
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
        // TEST 2: Load -5 into R1
        //
        // -5 in 16-bit two's complement is FFFB.
        // --------------------------------------------------

        external_load = 1'b1;
        external_data = 16'hFFFB;
        write_enable = 1'b1;
        write_address = 4'd1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd1;
        #1;

        if (read_data_a === 16'hFFFB) begin
            $display("PASS TEST 2: R1 contains -5 (FFFB).");
        end
        else begin
            $display("FAIL TEST 2: R1 expected FFFB, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 3: Load +3 into R2
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'h0003;
        write_enable = 1'b1;
        write_address = 4'd2;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd2;
        #1;

        if (read_data_a === 16'h0003) begin
            $display("PASS TEST 3: R2 contains +3 (0003).");
        end
        else begin
            $display("FAIL TEST 3: R2 expected 0003, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 4: R3 = R1 + R2
        //
        // -5 + 3 = -2 = FFFE
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b0;
        read_address_a = 4'd1;
        read_address_b = 4'd2;

        alu_op = ADD;
        use_immediate = 1'b0;
        use_carry = 1'b0;

        write_enable = 1'b1;
        write_address = 4'd3;

        // Store C and F.
        flag_write_enable = 5'b10010;

        #1;

        if ((alu_result === 16'hFFFE) &&
            (alu_flags === 5'b00000)) begin

            $display("PASS TEST 4A: -5 + 3 produced -2.");
        end
        else begin
            $display("FAIL TEST 4A: result=%h flags=%b.",
                     alu_result, alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        flag_write_enable = 5'b00000;
        read_address_a = 4'd3;
        #1;

        if (read_data_a === 16'hFFFE) begin
            $display("PASS TEST 4B: R3 contains -2 (FFFE).");
        end
        else begin
            $display("FAIL TEST 4B: R3 expected FFFE, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 5: R4 = R2 - R1
        //
        // 3 - (-5) = 8
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd2;
        read_address_b = 4'd1;

        alu_op = SUB;
        use_carry = 1'b0;

        write_enable = 1'b1;
        write_address = 4'd4;

        flag_write_enable = 5'b11111;

        #1;

        if ((alu_result === 16'h0008) &&
            (alu_flags === 5'b11000)) begin

            $display("PASS TEST 5A: 3 - (-5) produced 8.");
        end
        else begin
            $display("FAIL TEST 5A: result=%h flags=%b.",
                     alu_result, alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        flag_write_enable = 5'b00000;
        read_address_a = 4'd4;
        #1;

        if (read_data_a === 16'h0008) begin
            $display("PASS TEST 5B: R4 contains 8.");
        end
        else begin
            $display("FAIL TEST 5B: R4 expected 0008, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 6: R5 = R1 - R2
        //
        // -5 - 3 = -8 = FFF8
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd1;
        read_address_b = 4'd2;

        alu_op = SUB;
        write_enable = 1'b1;
        write_address = 4'd5;

        flag_write_enable = 5'b11111;

        #1;

        if ((alu_result === 16'hFFF8) &&
            (alu_flags === 5'b00100)) begin

            $display("PASS TEST 6A: -5 - 3 produced -8.");
        end
        else begin
            $display("FAIL TEST 6A: result=%h flags=%b.",
                     alu_result, alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        flag_write_enable = 5'b00000;
        read_address_a = 4'd5;
        #1;

        if (read_data_a === 16'hFFF8) begin
            $display("PASS TEST 6B: R5 contains -8 (FFF8).");
        end
        else begin
            $display("FAIL TEST 6B: R5 expected FFF8, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 7: Signed comparison of -5 and +3
        //
        // -5 < +3, so N must equal 1.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd1;
        read_address_b = 4'd2;

        alu_op = CMP;
        write_enable = 1'b0;

        // Store N and Z.
        flag_write_enable = 5'b00101;

        #1;

        if (alu_flags === 5'b00100) begin
            $display("PASS TEST 7A: Signed comparison set N.");
        end
        else begin
            $display("FAIL TEST 7A: Expected 00100, got %b.",
                     alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        flag_write_enable = 5'b00000;

        if (stored_flags === 5'b00100) begin
            $display("PASS TEST 7B: Signed comparison flags stored.");
        end
        else begin
            $display("FAIL TEST 7B: Expected 00100, got %b.",
                     stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 8: Compare R3 with itself
        //
        // -2 == -2, so Z must equal 1 and N must equal 0.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd3;
        read_address_b = 4'd3;

        alu_op = CMP;
        flag_write_enable = 5'b00101;

        #1;

        if (alu_flags === 5'b00001) begin
            $display("PASS TEST 8A: Equal comparison set Z.");
        end
        else begin
            $display("FAIL TEST 8A: Expected 00001, got %b.",
                     alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        flag_write_enable = 5'b00000;

        if (stored_flags === 5'b00001) begin
            $display("PASS TEST 8B: Z stored and N cleared.");
        end
        else begin
            $display("FAIL TEST 8B: Expected 00001, got %b.",
                     stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 9: Load maximum positive number into R6
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'h7FFF;
        write_enable = 1'b1;
        write_address = 4'd6;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd6;
        #1;

        if (read_data_a === 16'h7FFF) begin
            $display("PASS TEST 9: R6 contains 7FFF.");
        end
        else begin
            $display("FAIL TEST 9: R6 expected 7FFF, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 10: Load 1 into R7
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'h0001;
        write_enable = 1'b1;
        write_address = 4'd7;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd7;
        #1;

        if (read_data_a === 16'h0001) begin
            $display("PASS TEST 10: R7 contains 0001.");
        end
        else begin
            $display("FAIL TEST 10: R7 expected 0001, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 11: Signed positive overflow
        //
        // R8 = 7FFF + 0001 = 8000
        // F must equal 1.
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b0;
        read_address_a = 4'd6;
        read_address_b = 4'd7;

        alu_op = ADD;
        use_immediate = 1'b0;
        use_carry = 1'b0;

        write_enable = 1'b1;
        write_address = 4'd8;

        // Store C and F.
        flag_write_enable = 5'b10010;

        #1;

        if ((alu_result === 16'h8000) &&
            (alu_flags === 5'b00010)) begin

            $display("PASS TEST 11A: Positive overflow detected.");
        end
        else begin
            $display("FAIL TEST 11A: result=%h flags=%b.",
                     alu_result, alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        flag_write_enable = 5'b00000;
        read_address_a = 4'd8;
        #1;

        if ((read_data_a === 16'h8000) &&
            (stored_flags === 5'b00011)) begin

            $display("PASS TEST 11B: Overflow stored and Z preserved.");
        end
        else begin
            $display("FAIL TEST 11B: R8=%h stored flags=%b.",
                     read_data_a, stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 12: Load most-negative number into R9
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'h8000;
        write_enable = 1'b1;
        write_address = 4'd9;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd9;
        #1;

        if (read_data_a === 16'h8000) begin
            $display("PASS TEST 12: R9 contains -32768.");
        end
        else begin
            $display("FAIL TEST 12: R9 expected 8000, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 13: Load 1 into R10
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'h0001;
        write_enable = 1'b1;
        write_address = 4'd10;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd10;
        #1;

        if (read_data_a === 16'h0001) begin
            $display("PASS TEST 13: R10 contains 0001.");
        end
        else begin
            $display("FAIL TEST 13: R10 expected 0001, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 14: Signed negative overflow
        //
        // R11 = 8000 - 0001 = 7FFF
        // This operation must set F.
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b0;
        read_address_a = 4'd9;
        read_address_b = 4'd10;

        alu_op = SUB;
        use_carry = 1'b0;

        write_enable = 1'b1;
        write_address = 4'd11;

        flag_write_enable = 5'b11111;

        #1;

        if ((alu_result === 16'h7FFF) &&
            (alu_flags === 5'b00110)) begin

            $display("PASS TEST 14A: Negative overflow detected.");
        end
        else begin
            $display("FAIL TEST 14A: result=%h flags=%b.",
                     alu_result, alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        flag_write_enable = 5'b00000;
        read_address_a = 4'd11;
        #1;

        if ((read_data_a === 16'h7FFF) &&
            (stored_flags === 5'b00110)) begin

            $display("PASS TEST 14B: Overflow result and flags stored.");
        end
        else begin
            $display("FAIL TEST 14B: R11=%h stored flags=%b.",
                     read_data_a, stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 15: Immediate signed addition
        //
        // R12 = R5 + 10
        // R5 contains -8.
        // -8 + 10 = 2.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd5;
        read_address_b = 4'd0;

        alu_op = ADD;
        use_immediate = 1'b1;
        immediate_value = 16'h000A;
        use_carry = 1'b0;

        external_load = 1'b0;
        write_enable = 1'b1;
        write_address = 4'd12;

        flag_write_enable = 5'b10010;

        #1;

        if ((selected_rhs === 16'h000A) &&
            (alu_result === 16'h0002) &&
            (alu_flags === 5'b10000)) begin

            $display("PASS TEST 15A: -8 + 10 produced 2.");
        end
        else begin
            $display("FAIL TEST 15A: rhs=%h result=%h flags=%b.",
                     selected_rhs, alu_result, alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        flag_write_enable = 5'b00000;
        use_immediate = 1'b0;
        read_address_a = 4'd12;
        #1;

        if (read_data_a === 16'h0002) begin
            $display("PASS TEST 15B: R12 contains 0002.");
        end
        else begin
            $display("FAIL TEST 15B: R12 expected 0002, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 16: Arithmetic right shift
        //
        // Shift R5, which contains -8, right by 2.
        // A negative shift amount means shift right.
        //
        // FFFE represents -2 as the shift amount.
        // FFF8 shifted right by 2 produces FFFE.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd5;
        read_address_b = 4'd0;

        alu_op = ASH;
        use_immediate = 1'b1;
        immediate_value = 16'hFFFE;
        use_carry = 1'b0;

        external_load = 1'b0;
        write_enable = 1'b1;
        write_address = 4'd13;

        flag_write_enable = 5'b00000;

        #1;

        if (alu_result === 16'hFFFE) begin
            $display("PASS TEST 16A: Arithmetic shift produced -2.");
        end
        else begin
            $display("FAIL TEST 16A: Expected FFFE, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        use_immediate = 1'b0;
        read_address_a = 4'd13;
        #1;

        if (read_data_a === 16'hFFFE) begin
            $display("PASS TEST 16B: R13 contains -2 (FFFE).");
        end
        else begin
            $display("FAIL TEST 16B: R13 expected FFFE, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 17: Final simultaneous signed-value read
        // --------------------------------------------------

        read_address_a = 4'd5;
        read_address_b = 4'd13;
        #1;

        if ((read_data_a === 16'hFFF8) &&
            (read_data_b === 16'hFFFE)) begin

            $display("PASS TEST 17: Read -8 and -2 together.");
        end
        else begin
            $display("FAIL TEST 17: R5=%h R13=%h.",
                     read_data_a, read_data_b);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // Final result
        // --------------------------------------------------

        $display("--------------------------------------------------");

        if (errors == 0)
            $display("SUCCESS: ALL SIGNED DATAPATH TESTS PASSED.");
        else
            $display("FAIL: %0d SIGNED TEST(S) FAILED.", errors);

        $finish;

    end

endmodule