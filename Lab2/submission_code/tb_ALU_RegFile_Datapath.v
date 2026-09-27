`timescale 1ns / 1ps

module tb_ALU_RegFile_Datapath;

    // Clock and reset
    reg clk;
    reg reset;

    // Register File read port A
    reg read_enable_a;
    reg [3:0] read_address_a;
    wire [15:0] read_data_a;

    // Register File read port B
    reg read_enable_b;
    reg [3:0] read_address_b;
    wire [15:0] read_data_b;

    // Register File write port
    reg write_enable;
    reg [3:0] write_address;

    // ALU controls
    reg [3:0] alu_op;
    reg use_immediate;
    reg [15:0] immediate_value;
    reg use_carry;

    // External loading controls
    reg external_load;
    reg [15:0] external_data;

    // Flag Register control
    reg [4:0] flag_write_enable;

    // Datapath outputs
    wire [15:0] selected_rhs;
    wire [15:0] alu_result;
    wire [4:0] alu_flags;
    wire [4:0] stored_flags;
    wire [15:0] write_back_data;

    integer errors;

    // ALU operation codes
    localparam [3:0] ADD  = 4'h2;
    localparam [3:0] CMP  = 4'hD;
    localparam [3:0] CMPU = 4'hE;
    localparam [3:0] NOP  = 4'hF;

    // Instantiate the complete datapath.
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

    // Generate a 10 ns clock.
    always #5 clk = ~clk;

    initial begin

        // Initial values
        clk = 1'b0;
        reset = 1'b0;

        read_enable_a = 1'b1;
        read_address_a = 4'd0;

        read_enable_b = 1'b1;
        read_address_b = 4'd15;

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
        // TEST 1: Reset the complete datapath
        // --------------------------------------------------

        #1;
        reset = 1'b1;
        #1;

        if ((read_data_a === 16'h0000) &&
            (read_data_b === 16'h0000) &&
            (stored_flags === 5'b00000)) begin

            $display("PASS TEST 1: Reset cleared registers and flags.");
        end
        else begin
            $display("FAIL TEST 1: Reset did not clear the datapath.");
            errors = errors + 1;
        end

        // Release reset before loading data.
        @(negedge clk);
        reset = 1'b0;

        // --------------------------------------------------
        // TEST 2: Load decimal 5 into R1
        // --------------------------------------------------

        external_load = 1'b1;
        external_data = 16'h0005;
        write_enable = 1'b1;
        write_address = 4'd1;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd1;
        #1;

        if (read_data_a === 16'h0005) begin
            $display("PASS TEST 2: External data loaded R1 with 0005.");
        end
        else begin
            $display("FAIL TEST 2: R1 expected 0005, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 3: Load decimal 3 into R2
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'h0003;
        write_enable = 1'b1;
        write_address = 4'd2;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd1;
        read_address_b = 4'd2;
        #1;

        if ((read_data_a === 16'h0005) &&
            (read_data_b === 16'h0003)) begin

            $display("PASS TEST 3: Simultaneously read R1 and R2.");
        end
        else begin
            $display("FAIL TEST 3: R1=%h R2=%h.",
                     read_data_a, read_data_b);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 4: R3 = R1 + R2
        // Expected result: 5 + 3 = 8
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b0;
        use_immediate = 1'b0;
        use_carry = 1'b0;

        read_address_a = 4'd1;
        read_address_b = 4'd2;

        alu_op = ADD;

        write_enable = 1'b1;
        write_address = 4'd3;

        flag_write_enable = 5'b00000;

        #1;

        if ((alu_result === 16'h0008) &&
            (write_back_data === 16'h0008)) begin

            $display("PASS TEST 4A: ALU calculated R1 + R2 = 0008.");
        end
        else begin
            $display("FAIL TEST 4A: ADD result=%h write-back=%h.",
                     alu_result, write_back_data);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd3;
        #1;

        if (read_data_a === 16'h0008) begin
            $display("PASS TEST 4B: ADD result was written into R3.");
        end
        else begin
            $display("FAIL TEST 4B: R3 expected 0008, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 5: R4 = R3 + immediate value 2
        // Expected result: 8 + 2 = 10 = 000A
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd3;
        read_address_b = 4'd0;

        use_immediate = 1'b1;
        immediate_value = 16'h0002;
        use_carry = 1'b0;
        alu_op = ADD;

        external_load = 1'b0;
        write_enable = 1'b1;
        write_address = 4'd4;

        #1;

        if ((selected_rhs === 16'h0002) &&
            (alu_result === 16'h000A)) begin

            $display("PASS TEST 5A: Immediate ADD calculated 000A.");
        end
        else begin
            $display("FAIL TEST 5A: rhs=%h result=%h.",
                     selected_rhs, alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        use_immediate = 1'b0;
        read_address_a = 4'd4;
        #1;

        if (read_data_a === 16'h000A) begin
            $display("PASS TEST 5B: Immediate ADD stored 000A in R4.");
        end
        else begin
            $display("FAIL TEST 5B: R4 expected 000A, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 6: Load FFFF into R5
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'hFFFF;
        write_enable = 1'b1;
        write_address = 4'd5;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd5;
        #1;

        if (read_data_a === 16'hFFFF) begin
            $display("PASS TEST 6: Loaded FFFF into R5.");
        end
        else begin
            $display("FAIL TEST 6: R5 expected FFFF, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 7: Load 0001 into R6
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'h0001;
        write_enable = 1'b1;
        write_address = 4'd6;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_address_a = 4'd6;
        #1;

        if (read_data_a === 16'h0001) begin
            $display("PASS TEST 7: Loaded 0001 into R6.");
        end
        else begin
            $display("FAIL TEST 7: R6 expected 0001, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 8: R7 = FFFF + 0001
        //
        // Expected result: 0000
        // Expected carry flag: 1
        // Store only the C flag.
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b0;
        read_address_a = 4'd5;
        read_address_b = 4'd6;

        use_immediate = 1'b0;
        use_carry = 1'b0;
        alu_op = ADD;

        write_enable = 1'b1;
        write_address = 4'd7;

        flag_write_enable = 5'b10000;

        #1;

        if ((alu_result === 16'h0000) &&
            (alu_flags[4] === 1'b1)) begin

            $display("PASS TEST 8A: FFFF + 0001 produced carry.");
        end
        else begin
            $display("FAIL TEST 8A: result=%h flags=%b.",
                     alu_result, alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        flag_write_enable = 5'b00000;
        read_address_a = 4'd7;
        #1;

        if ((read_data_a === 16'h0000) &&
            (stored_flags === 5'b10000)) begin

            $display("PASS TEST 8B: R7=0000 and stored carry=1.");
        end
        else begin
            $display("FAIL TEST 8B: R7=%h stored flags=%b.",
                     read_data_a, stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 9: Use the stored carry flag
        //
        // R8 = R1 + R2 + stored carry
        // R8 = 5 + 3 + 1 = 9
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd1;
        read_address_b = 4'd2;

        alu_op = ADD;
        use_immediate = 1'b0;
        use_carry = 1'b1;
        external_load = 1'b0;

        write_enable = 1'b1;
        write_address = 4'd8;
        flag_write_enable = 5'b00000;

        #1;

        if (alu_result === 16'h0009) begin
            $display("PASS TEST 9A: Stored carry produced result 0009.");
        end
        else begin
            $display("FAIL TEST 9A: Expected 0009, got %h.",
                     alu_result);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        use_carry = 1'b0;
        read_address_a = 4'd8;
        #1;

        if (read_data_a === 16'h0009) begin
            $display("PASS TEST 9B: Carry ADD result stored in R8.");
        end
        else begin
            $display("FAIL TEST 9B: R8 expected 0009, got %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 10: Signed comparison
        //
        // R5 = FFFF, which is -1 signed
        // R6 = 0001, which is +1 signed
        // Therefore R5 < R6 and N should be 1.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd5;
        read_address_b = 4'd6;

        alu_op = CMP;
        use_immediate = 1'b0;
        use_carry = 1'b0;

        write_enable = 1'b0;

        // Store only N and Z.
        flag_write_enable = 5'b00101;

        #1;

        if (alu_flags === 5'b00100) begin
            $display("PASS TEST 10A: Signed comparison set N.");
        end
        else begin
            $display("FAIL TEST 10A: Expected 00100, got %b.",
                     alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        flag_write_enable = 5'b00000;

        if (stored_flags === 5'b10100) begin
            $display("PASS TEST 10B: N stored while C was preserved.");
        end
        else begin
            $display("FAIL TEST 10B: Expected 10100, got %b.",
                     stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 11: Unsigned comparison
        //
        // R1 = 5
        // R4 = 10
        // Therefore R1 < R4 and L should be 1.
        // --------------------------------------------------

        @(negedge clk);

        read_address_a = 4'd1;
        read_address_b = 4'd4;

        alu_op = CMPU;
        write_enable = 1'b0;

        // Store only L and Z.
        flag_write_enable = 5'b01001;

        #1;

        if (alu_flags === 5'b01000) begin
            $display("PASS TEST 11A: Unsigned comparison set L.");
        end
        else begin
            $display("FAIL TEST 11A: Expected 01000, got %b.",
                     alu_flags);
            errors = errors + 1;
        end

        @(posedge clk);
        #1;

        flag_write_enable = 5'b00000;

        if (stored_flags === 5'b11100) begin
            $display("PASS TEST 11B: L stored and other flags preserved.");
        end
        else begin
            $display("FAIL TEST 11B: Expected 11100, got %b.",
                     stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 12: write_enable must prevent a write
        //
        // Attempt to overwrite R1 with DEAD while disabled.
        // R1 must remain 0005.
        // --------------------------------------------------

        @(negedge clk);

        external_load = 1'b1;
        external_data = 16'hDEAD;
        write_address = 4'd1;
        write_enable = 1'b0;

        @(posedge clk);
        #1;

        read_address_a = 4'd1;
        #1;

        if (read_data_a === 16'h0005) begin
            $display("PASS TEST 12: Disabled write preserved R1.");
        end
        else begin
            $display("FAIL TEST 12: R1 changed to %h.",
                     read_data_a);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 13: Disabled read ports must output zero
        // --------------------------------------------------

        read_enable_a = 1'b0;
        read_enable_b = 1'b0;
        use_immediate = 1'b0;
        #1;

        if ((read_data_a === 16'h0000) &&
            (read_data_b === 16'h0000) &&
            (selected_rhs === 16'h0000)) begin

            $display("PASS TEST 13: Disabled reads output zero.");
        end
        else begin
            $display("FAIL TEST 13: A=%h B=%h rhs=%h.",
                     read_data_a, read_data_b, selected_rhs);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 14: NOP must produce zero result and flags
        // --------------------------------------------------

        read_enable_a = 1'b1;
        read_enable_b = 1'b1;
        read_address_a = 4'd1;
        read_address_b = 4'd2;

        external_load = 1'b0;
        alu_op = NOP;
        #1;

        if ((alu_result === 16'h0000) &&
            (alu_flags === 5'b00000)) begin

            $display("PASS TEST 14: NOP produced zero result and flags.");
        end
        else begin
            $display("FAIL TEST 14: result=%h flags=%b.",
                     alu_result, alu_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // TEST 15: Final asynchronous reset
        // --------------------------------------------------

        read_address_a = 4'd1;
        read_address_b = 4'd8;

        #1;
        reset = 1'b1;
        #1;

        if ((read_data_a === 16'h0000) &&
            (read_data_b === 16'h0000) &&
            (stored_flags === 5'b00000)) begin

            $display("PASS TEST 15: Final reset cleared everything.");
        end
        else begin
            $display("FAIL TEST 15: A=%h B=%h flags=%b.",
                     read_data_a, read_data_b, stored_flags);
            errors = errors + 1;
        end

        // --------------------------------------------------
        // Final result
        // --------------------------------------------------

        $display("--------------------------------------------------");

        if (errors == 0)
            $display("SUCCESS: ALL DATAPATH TESTS PASSED.");
        else
            $display("FAIL: %0d DATAPATH TEST(S) FAILED.", errors);

        $finish;

    end

endmodule