`timescale 1ns / 1ps

module tb_Datapath_Mixed;

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

    localparam [3:0] ZEXT = 4'h0;
    localparam [3:0] SEXT = 4'h1;
    localparam [3:0] AND  = 4'h4;
    localparam [3:0] OR   = 4'h5;
    localparam [3:0] XOR  = 4'h6;
    localparam [3:0] MULT = 4'h7;
    localparam [3:0] LUI  = 4'h8;
    localparam [3:0] LSH  = 4'h9;
    localparam [3:0] PASS = 4'hB;
    localparam [3:0] NOT  = 4'hC;
    localparam [3:0] CMPU = 4'hE;
    localparam [3:0] NOP  = 4'hF;

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

        alu_op = NOP;
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
        // TEST 2: Load F0F0 into R1
        // --------------------------------------------------

        external_load = 1'b1;
        external_data = 16'hF0F0;
        write_enable = 1'b1;
        write_address = 4'd1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd1;
        #1;

        if (read_data_a === 16'hF0F0) begin
            $display("PASS TEST 2: R1 contains F0F0.");
        end
        else begin
            $display("FAIL TEST 2: R1 expected F0F0, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 3: Load 0FF0 into R2
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'h0FF0;
        write_enable = 1'b1;
        write_address = 4'd2;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd2;
        #1;

        if (read_data_a === 16'h0FF0) begin
            $display("PASS TEST 3: R2 contains 0FF0.");
        end
        else begin
            $display("FAIL TEST 3: R2 expected 0FF0, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // All following register writes use the ALU result.
        external_load = 1'b0;
        use_carry = 1'b0;
        flag_write_enable = 5'b00000;

        // --------------------------------------------------
        // TEST 4: R3 = R1 AND R2
        //
        // F0F0 AND 0FF0 = 00F0
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd1;
        read_address_b = 4'd2;

        alu_op = AND;
        use_immediate = 1'b0;

        write_enable = 1'b1;
        write_address = 4'd3;

        #1;

        if (alu_result === 16'h00F0) begin
            $display("PASS TEST 4A: AND produced 00F0.");
        end
        else begin
            $display("FAIL TEST 4A: Expected 00F0, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd3;
        #1;

        if (read_data_a === 16'h00F0) begin
            $display("PASS TEST 4B: R3 contains 00F0.");
        end
        else begin
            $display("FAIL TEST 4B: R3 expected 00F0, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 5: R4 = R1 OR R2
        //
        // F0F0 OR 0FF0 = FFF0
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd1;
        read_address_b = 4'd2;

        alu_op = OR;
        write_enable = 1'b1;
        write_address = 4'd4;

        #1;

        if (alu_result === 16'hFFF0) begin
            $display("PASS TEST 5A: OR produced FFF0.");
        end
        else begin
            $display("FAIL TEST 5A: Expected FFF0, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd4;
        #1;

        if (read_data_a === 16'hFFF0) begin
            $display("PASS TEST 5B: R4 contains FFF0.");
        end
        else begin
            $display("FAIL TEST 5B: R4 expected FFF0, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 6: R5 = R1 XOR R2
        //
        // F0F0 XOR 0FF0 = FF00
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd1;
        read_address_b = 4'd2;

        alu_op = XOR;
        write_enable = 1'b1;
        write_address = 4'd5;

        #1;

        if (alu_result === 16'hFF00) begin
            $display("PASS TEST 6A: XOR produced FF00.");
        end
        else begin
            $display("FAIL TEST 6A: Expected FF00, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd5;
        #1;

        if (read_data_a === 16'hFF00) begin
            $display("PASS TEST 6B: R5 contains FF00.");
        end
        else begin
            $display("FAIL TEST 6B: R5 expected FF00, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 7: R6 = NOT R2
        //
        // NOT 0FF0 = F00F
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd2;
        read_address_b = 4'd0;

        alu_op = NOT;
        write_enable = 1'b1;
        write_address = 4'd6;

        #1;

        if (alu_result === 16'hF00F) begin
            $display("PASS TEST 7A: NOT produced F00F.");
        end
        else begin
            $display("FAIL TEST 7A: Expected F00F, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd6;
        #1;

        if (read_data_a === 16'hF00F) begin
            $display("PASS TEST 7B: R6 contains F00F.");
        end
        else begin
            $display("FAIL TEST 7B: R6 expected F00F, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 8: R7 = PASS R5
        //
        // PASS returns the right-side operand.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd0;
        read_address_b = 4'd5;

        alu_op = PASS;
        use_immediate = 1'b0;

        write_enable = 1'b1;
        write_address = 4'd7;

        #1;

        if (alu_result === 16'hFF00) begin
            $display("PASS TEST 8A: PASS produced FF00.");
        end
        else begin
            $display("FAIL TEST 8A: Expected FF00, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd7;
        #1;

        if (read_data_a === 16'hFF00) begin
            $display("PASS TEST 8B: R7 contains FF00.");
        end
        else begin
            $display("FAIL TEST 8B: R7 expected FF00, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 9: R8 = R3 multiplied by immediate 4
        //
        // 00F0 multiplied by 4 = 03C0
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd3;
        read_address_b = 4'd0;

        alu_op = MULT;
        use_immediate = 1'b1;
        immediate_value = 16'h0004;

        write_enable = 1'b1;
        write_address = 4'd8;

        #1;

        if ((selected_rhs === 16'h0004) &&
            (alu_result === 16'h03C0)) begin

            $display("PASS TEST 9A: MULT produced 03C0.");
        end
        else begin
            $display("FAIL TEST 9A: rhs=%h result=%h.",
                     selected_rhs, alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        use_immediate = 1'b0;
        read_address_a = 4'd8;
        #1;

        if (read_data_a === 16'h03C0) begin
            $display("PASS TEST 9B: R8 contains 03C0.");
        end
        else begin
            $display("FAIL TEST 9B: R8 expected 03C0, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 10: R9 = R8 logically shifted left by 1
        //
        // 03C0 << 1 = 0780
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd8;
        read_address_b = 4'd0;

        alu_op = LSH;
        use_immediate = 1'b1;
        immediate_value = 16'h0001;

        write_enable = 1'b1;
        write_address = 4'd9;

        #1;

        if (alu_result === 16'h0780) begin
            $display("PASS TEST 10A: Left shift produced 0780.");
        end
        else begin
            $display("FAIL TEST 10A: Expected 0780, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        use_immediate = 1'b0;
        read_address_a = 4'd9;
        #1;

        if (read_data_a === 16'h0780) begin
            $display("PASS TEST 10B: R9 contains 0780.");
        end
        else begin
            $display("FAIL TEST 10B: R9 expected 0780, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 11: R10 = R9 logically shifted right by 2
        //
        // Negative shift amount FFFE represents -2.
        // 0780 >> 2 = 01E0
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd9;
        read_address_b = 4'd0;

        alu_op = LSH;
        use_immediate = 1'b1;
        immediate_value = 16'hFFFE;

        write_enable = 1'b1;
        write_address = 4'd10;

        #1;

        if (alu_result === 16'h01E0) begin
            $display("PASS TEST 11A: Right shift produced 01E0.");
        end
        else begin
            $display("FAIL TEST 11A: Expected 01E0, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        use_immediate = 1'b0;
        read_address_a = 4'd10;
        #1;

        if (read_data_a === 16'h01E0) begin
            $display("PASS TEST 11B: R10 contains 01E0.");
        end
        else begin
            $display("FAIL TEST 11B: R10 expected 01E0, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 12: Zero extend 80 into R11
        //
        // Zero extension produces 0080.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd0;
        read_address_b = 4'd0;

        alu_op = ZEXT;
        use_immediate = 1'b1;
        immediate_value = 16'hFF80;

        write_enable = 1'b1;
        write_address = 4'd11;

        #1;

        if (alu_result === 16'h0080) begin
            $display("PASS TEST 12A: ZEXT produced 0080.");
        end
        else begin
            $display("FAIL TEST 12A: Expected 0080, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        use_immediate = 1'b0;
        read_address_a = 4'd11;
        #1;

        if (read_data_a === 16'h0080) begin
            $display("PASS TEST 12B: R11 contains 0080.");
        end
        else begin
            $display("FAIL TEST 12B: R11 expected 0080, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 13: Sign extend 80 into R12
        //
        // Sign extension produces FF80.
        // --------------------------------------------------

        @(negedge clk);

        alu_op = SEXT;
        use_immediate = 1'b1;
        immediate_value = 16'h0080;

        write_enable = 1'b1;
        write_address = 4'd12;

        #1;

        if (alu_result === 16'hFF80) begin
            $display("PASS TEST 13A: SEXT produced FF80.");
        end
        else begin
            $display("FAIL TEST 13A: Expected FF80, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        use_immediate = 1'b0;
        read_address_a = 4'd12;
        #1;

        if (read_data_a === 16'hFF80) begin
            $display("PASS TEST 13B: R12 contains FF80.");
        end
        else begin
            $display("FAIL TEST 13B: R12 expected FF80, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 14: Load upper immediate AB into R13
        //
        // LUI produces AB00.
        // --------------------------------------------------

        @(negedge clk);

        alu_op = LUI;
        use_immediate = 1'b1;
        immediate_value = 16'h00AB;

        write_enable = 1'b1;
        write_address = 4'd13;

        #1;

        if (alu_result === 16'hAB00) begin
            $display("PASS TEST 14A: LUI produced AB00.");
        end
        else begin
            $display("FAIL TEST 14A: Expected AB00, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        use_immediate = 1'b0;
        read_address_a = 4'd13;
        #1;

        if (read_data_a === 16'hAB00) begin
            $display("PASS TEST 14B: R13 contains AB00.");
        end
        else begin
            $display("FAIL TEST 14B: R13 expected AB00, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 15: Unsigned comparison
        //
        // R11 = 0080
        // R13 = AB00
        // Unsigned 0080 < AB00, so L must equal 1.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd11;
        read_address_b = 4'd13;

        alu_op = CMPU;
        use_immediate = 1'b0;
        write_enable = 1'b0;

        // Store L and Z.
        flag_write_enable = 5'b01001;

        #1;

        if (alu_flags === 5'b01000) begin
            $display("PASS TEST 15A: CMPU set the L flag.");
        end
        else begin
            $display("FAIL TEST 15A: Expected 01000, got %b.",
                     alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        flag_write_enable = 5'b00000;

        if (stored_flags === 5'b01000) begin
            $display("PASS TEST 15B: L flag stored correctly.");
        end
        else begin
            $display("FAIL TEST 15B: Expected 01000, got %b.",
                     stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 16: NOP must not write a register
        //
        // R13 must remain AB00.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd13;
        read_address_b = 4'd0;

        alu_op = NOP;
        write_enable = 1'b0;

        #1;

        if ((alu_result === 16'h0000) &&
            (alu_flags === 5'b00000)) begin

            $display("PASS TEST 16A: NOP output is zero.");
        end
        else begin
            $display("FAIL TEST 16A: result=%h flags=%b.",
                     alu_result, alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        read_address_a = 4'd13;
        #1;

        if (read_data_a === 16'hAB00) begin
            $display("PASS TEST 16B: NOP preserved R13.");
        end
        else begin
            $display("FAIL TEST 16B: R13 changed to %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 17: Read two final results together
        // --------------------------------------------------

        read_address_a = 4'd10;
        read_address_b = 4'd13;
        #1;

        if ((read_data_a === 16'h01E0) &&
            (read_data_b === 16'hAB00)) begin

            $display("PASS TEST 17: Final mixed results correct.");
        end
        else begin
            $display("FAIL TEST 17: R10=%h R13=%h.",
                     read_data_a, read_data_b);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // Final result
        // --------------------------------------------------

        $display("--------------------------------------------------");

        if (errors == 0)
            $display("SUCCESS: ALL MIXED DATAPATH TESTS PASSED.");
        else
            $display("FAIL: %0d MIXED TEST(S) FAILED.", errors);

        $finish;

    end

endmodule