`timescale 1ns / 1ps

/*
 * Simple self-checking testbench for FlagRegister.v
 *
 * This testbench checks:
 *     1. Reset
 *     2. Writing all flags
 *     3. Updating only C
 *     4. Updating only L and F
 *     5. Clearing only N and Z
 *     6. Preserving flags when all enables are zero
 *     7. Updating C, N, and Z
 *     8. Values do not change before a clock edge
 *     9. Asynchronous reset
 */
module tb_FlagRegister;

    reg clk;
    reg reset;

    reg [4:0] new_flags;
    reg [4:0] flag_write_enable;

    wire [4:0] stored_flags;

    integer errors;

    FlagRegister dut (
        .clk(clk),
        .reset(reset),
        .new_flags(new_flags),
        .flag_write_enable(flag_write_enable),
        .stored_flags(stored_flags)
    );

    // Generate a clock with a period of 10 ns
    always #5 clk = ~clk;

    initial begin

        // Initialize all inputs
        clk = 1'b0;
        reset = 1'b1;
        new_flags = 5'b00000;
        flag_write_enable = 5'b00000;
        errors = 0;

        /*
         * TEST 1
         * Reset should clear all five stored flags.
         */
        #2;

        if (stored_flags !== 5'b00000) begin

            $display(
                "FAIL TEST 1: Reset expected 00000, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 1: Reset cleared all flags."
            );
        end

        // Release reset
        reset = 1'b0;

        /*
         * TEST 2
         * Enable all five flags and write 10101.
         */
        new_flags = 5'b10101;
        flag_write_enable = 5'b11111;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b10101) begin

            $display(
                "FAIL TEST 2: Expected 10101, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 2: Wrote all flags as 10101."
            );
        end

        /*
         * TEST 3
         * Update only C.
         *
         * Old flags: 10101
         * New C:     0
         * Expected:  00101
         */
        new_flags = 5'b00000;
        flag_write_enable = 5'b10000;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b00101) begin

            $display(
                "FAIL TEST 3: Expected 00101, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 3: Updated only the C flag."
            );
        end

        /*
         * TEST 4
         * Update only L and F.
         *
         * Old flags: 00101
         * New L:     1
         * New F:     1
         * Expected:  01111
         */
        new_flags = 5'b01010;
        flag_write_enable = 5'b01010;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b01111) begin

            $display(
                "FAIL TEST 4: Expected 01111, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 4: Updated only L and F."
            );
        end

        /*
         * TEST 5
         * Clear only N and Z.
         *
         * Old flags: 01111
         * New N:     0
         * New Z:     0
         * Expected:  01010
         */
        new_flags = 5'b00000;
        flag_write_enable = 5'b00101;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b01010) begin

            $display(
                "FAIL TEST 5: Expected 01010, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 5: Cleared only N and Z."
            );
        end

        /*
         * TEST 6
         * Disable all writes.
         *
         * new_flags is 11111, but the stored value
         * must remain 01010.
         */
        new_flags = 5'b11111;
        flag_write_enable = 5'b00000;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b01010) begin

            $display(
                "FAIL TEST 6: Flags changed while enables were zero."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 6: Disabled flags kept their values."
            );
        end

        /*
         * TEST 7
         * Set C, N, and Z to one.
         *
         * Old flags: 01010
         * Updated:   C, N, Z
         * Expected:  11111
         */
        new_flags = 5'b10101;
        flag_write_enable = 5'b10101;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b11111) begin

            $display(
                "FAIL TEST 7: Expected 11111, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 7: Updated C, N, and Z."
            );
        end

        /*
         * TEST 8
         * Set up a complete clear, but check before
         * the next rising edge.
         *
         * The flags must remain 11111 until the edge.
         */
        new_flags = 5'b00000;
        flag_write_enable = 5'b11111;

        #2;

        if (stored_flags !== 5'b11111) begin

            $display(
                "FAIL TEST 8A: Flags changed before the clock edge."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 8A: Flags stayed unchanged before the edge."
            );
        end

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b00000) begin

            $display(
                "FAIL TEST 8B: Expected 00000 after edge, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 8B: Flags changed on the rising edge."
            );
        end

        /*
         * Write 11011 before testing asynchronous reset.
         */
        new_flags = 5'b11011;
        flag_write_enable = 5'b11111;

        @(posedge clk);
        #1;

        /*
         * TEST 9A
         * Confirm that 11011 was stored.
         */
        if (stored_flags !== 5'b11011) begin

            $display(
                "FAIL TEST 9A: Expected 11011, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 9A: Stored 11011 before reset."
            );
        end

        /*
         * TEST 9B
         * Assert reset between clock edges.
         * The flags should clear immediately.
         */
        reset = 1'b1;

        #1;

        if (stored_flags !== 5'b00000) begin

            $display(
                "FAIL TEST 9B: Asynchronous reset failed."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 9B: Asynchronous reset cleared flags."
            );
        end

        reset = 1'b0;
        flag_write_enable = 5'b00000;

        /*
         * Final result
         */
        $display(
            "--------------------------------------------------"
        );

        if (errors == 0) begin
            $display(
                "SUCCESS: ALL FLAG REGISTER TESTS PASSED."
            );
        end
        else begin
            $display(
                "FAILURE: %0d FLAG REGISTER TEST(S) FAILED.",
                errors
            );
        end

        $finish;

    end

endmodule