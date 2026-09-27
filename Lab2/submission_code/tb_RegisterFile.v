`timescale 1ns / 1ps
module tb_RegisterFile;

    reg clk;
    reg reset;

    reg         read_enable_a;
    reg  [3:0]  read_address_a;
    wire [15:0] read_data_a;
    reg         read_enable_b;
    reg  [3:0]  read_address_b;
    wire [15:0] read_data_b;

    reg         write_enable;
    reg  [3:0]  write_address;
    reg  [15:0] write_data;

    integer errors;

    RegisterFile dut (
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
        .write_data(write_data)
    );

    always #5 clk = ~clk;

    initial begin

        clk = 1'b0;
        reset = 1'b1;

        read_enable_a = 1'b0;
        read_address_a = 4'd0;

        read_enable_b = 1'b0;
        read_address_b = 4'd0;

        write_enable = 1'b0;
        write_address = 4'd0;
        write_data = 16'h0000;

        errors = 0;
        #2;

        if ((read_data_a !== 16'h0000) ||
            (read_data_b !== 16'h0000)) begin

            $display(
                "FAIL TEST 1: Disabled read ports did not output zero."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 1: Disabled read ports output zero."
            );
        end
        read_enable_a = 1'b1;
        read_address_a = 4'd0;

        read_enable_b = 1'b1;
        read_address_b = 4'd15;

        #1;

        if ((read_data_a !== 16'h0000) ||
            (read_data_b !== 16'h0000)) begin

            $display(
                "FAIL TEST 2: Reset did not clear R0 and R15."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 2: Reset cleared R0 and R15."
            );
        end

        reset = 1'b0;
 
        write_enable = 1'b1;
        write_address = 4'd1;
        write_data = 16'h1234;

        @(posedge clk);
        #1;

        write_enable = 1'b0;

        read_enable_a = 1'b1;
        read_address_a = 4'd1;

        #1;

        if (read_data_a !== 16'h1234) begin

            $display(
                "FAIL TEST 3: R1 expected 1234, got %h.",
                read_data_a
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 3: R1 stored 1234."
            );
        end

        write_enable = 1'b1;
        write_address = 4'd2;
        write_data = 16'hABCD;

        @(posedge clk);
        #1;

        write_enable = 1'b0;
        read_enable_a =1'b1;
        read_address_a = 4'd1;

        read_enable_b = 1'b1;
        read_address_b = 4'd2;

        #1;

        if ((read_data_a !== 16'h1234) ||
            (read_data_b !== 16'hABCD)) begin

            $display(
                "FAIL TEST 4: Expected A=1234 and B=ABCD, got A=%h B=%h.",
                read_data_a,
                read_data_b
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 4: Simultaneously read R1 and R2."
            );
        end

        read_address_a = 4'd2;
        read_address_b = 4'd2;

        #1;

        if ((read_data_a !== 16'hABCD) ||
            (read_data_b !== 16'hABCD)) begin

            $display(
                "FAIL TEST 5: Both ports should read ABCD."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 5: Both ports read R2 correctly."
            );
        end

        write_enable = 1'b0;
        write_address = 4'd1;
        write_data = 16'hFFFF;
        @(posedge clk);
        #1;

        read_address_a = 4'd1;
        #1;

        if (read_data_a !== 16'h1234) begin

            $display(
                "FAIL TEST 6: R1 changed while write_enable was zero."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 6: write_enable prevented the write."
            );
        end
        write_enable = 1'b1;
        write_address = 4'd15;
        write_data = 16'h8000;

        @(posedge clk);
        #1;
        write_enable = 1'b0;
        read_address_b = 4'd15;
        #1;
        if (read_data_b !== 16'h8000) begin

            $display(
                "FAIL TEST 7: R15 expected 8000, got %h.",
                read_data_b
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 7: R15 stored 8000."
            );
        end
        read_enable_a = 1'b0;
        read_enable_b = 1'b0;

        #1;

        if ((read_data_a !== 16'h0000) ||
            (read_data_b !== 16'h0000)) begin

            $display(
                "FAIL TEST 8: Disabled ports did not return zero."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 8: Both disabled ports returned zero."
            );
        end

        write_enable = 1'b1;
        write_address = 4'd2;
        write_data = 16'h0001;

        @(posedge clk);
        #1;

        write_enable = 1'b0;

        read_enable_a = 1'b1;
        read_address_a = 4'd2;

        #1;

        if (read_data_a !== 16'h0001) begin

            $display(
                "FAIL TEST 9: R2 expected 0001, got %h.",
                read_data_a
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 9: R2 was overwritten with 0001."
            );
        end
        reset = 1'b1;

        #1;

        read_enable_a = 1'b1;
        read_enable_b = 1'b1;

        read_address_a = 4'd1;
        read_address_b = 4'd2;
        #1;
        if ((read_data_a !== 16'h0000) ||
            (read_data_b !== 16'h0000)) begin

            $display(
                "FAIL TEST 10A: Reset did not clear R1 and R2."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 10A: Reset cleared R1 and R2."
            );
        end
        read_address_a = 4'd15;
        #1;
        if (read_data_a !== 16'h0000) begin

            $display(
                "FAIL TEST 10B: Reset did not clear R15."
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 10B: Reset cleared R15."
            );
        end

        reset = 1'b0;
        $display(
            "---"
        );
        if (errors == 0) begin
            $display(
                "SUCCESS: ALL REGISTER FILE TESTS PASSED."
            );
        end
        else begin
            $display(
                "FAILURE: %0d REGISTER FILE TEST(S) FAILED.",
                errors
            );
        end
        $finish;
    end
endmodule
