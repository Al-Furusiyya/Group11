`timescale 1ns/1ps

module tb_BranchCondition;

    reg [3:0] condition;
    reg [4:0] stored_flags;
    wire condition_met;

    integer test_number;
    integer error_count;

    BranchCondition dut (
        .condition(condition),
        .stored_flags(stored_flags),
        .condition_met(condition_met)
    );

    task check_condition;
        input [3:0] test_condition;
        input [4:0] test_flags;
        input expected_result;

        begin
            test_number = test_number + 1;

            condition = test_condition;
            stored_flags = test_flags;

            #1;

            if (condition_met == expected_result) begin
                $display(
                    "PASS TEST %0d: condition=%h flags=%b result=%b",
                    test_number,
                    condition,
                    stored_flags,
                    condition_met
                );
            end
            else begin
                error_count = error_count + 1;

                $display(
                    "FAIL TEST %0d: condition=%h flags=%b expected=%b received=%b",
                    test_number,
                    condition,
                    stored_flags,
                    expected_result,
                    condition_met
                );
            end
        end
    endtask

    initial begin
        test_number = 0;
        error_count = 0;

        condition = 4'h0;
        stored_flags = 5'b00000;

        #1;

        // Flags are ordered as C, L, N, F, Z.

        // EQ: true when Z = 1.
        check_condition(4'h0, 5'b00001, 1'b1);
        check_condition(4'h0, 5'b00000, 1'b0);

        // NE: true when Z = 0.
        check_condition(4'h1, 5'b00000, 1'b1);
        check_condition(4'h1, 5'b00001, 1'b0);

        // CS: true when C = 1.
        check_condition(4'h2, 5'b10000, 1'b1);
        check_condition(4'h2, 5'b00000, 1'b0);

        // CC: true when C = 0.
        check_condition(4'h3, 5'b00000, 1'b1);
        check_condition(4'h3, 5'b10000, 1'b0);

        // HI: true when L = 1.
        check_condition(4'h4, 5'b01000, 1'b1);
        check_condition(4'h4, 5'b00000, 1'b0);

        // LS: true when L = 0.
        check_condition(4'h5, 5'b00000, 1'b1);
        check_condition(4'h5, 5'b01000, 1'b0);

        // GT: true when N = 1.
        check_condition(4'h6, 5'b00100, 1'b1);
        check_condition(4'h6, 5'b00000, 1'b0);

        // LE: true when N = 0.
        check_condition(4'h7, 5'b00000, 1'b1);
        check_condition(4'h7, 5'b00100, 1'b0);

        // FS: true when F = 1.
        check_condition(4'h8, 5'b00010, 1'b1);
        check_condition(4'h8, 5'b00000, 1'b0);

        // FC: true when F = 0.
        check_condition(4'h9, 5'b00000, 1'b1);
        check_condition(4'h9, 5'b00010, 1'b0);

        // LO: true when L = 0 and Z = 0.
        check_condition(4'hA, 5'b00000, 1'b1);
        check_condition(4'hA, 5'b01000, 1'b0);
        check_condition(4'hA, 5'b00001, 1'b0);

        // HS: true when L = 1 or Z = 1.
        check_condition(4'hB, 5'b01000, 1'b1);
        check_condition(4'hB, 5'b00001, 1'b1);
        check_condition(4'hB, 5'b00000, 1'b0);

        // LT: true when N = 0 and Z = 0.
        check_condition(4'hC, 5'b00000, 1'b1);
        check_condition(4'hC, 5'b00100, 1'b0);
        check_condition(4'hC, 5'b00001, 1'b0);

        // GE: true when N = 1 or Z = 1.
        check_condition(4'hD, 5'b00100, 1'b1);
        check_condition(4'hD, 5'b00001, 1'b1);
        check_condition(4'hD, 5'b00000, 1'b0);

        // UC: unconditional.
        check_condition(4'hE, 5'b00000, 1'b1);
        check_condition(4'hE, 5'b11111, 1'b1);

        // Never condition.
        check_condition(4'hF, 5'b00000, 1'b0);
        check_condition(4'hF, 5'b11111, 1'b0);

        $display("--------------------------------------------");

        if (error_count == 0) begin
            $display("SUCCESS: ALL BRANCH CONDITIONS PASSED.");
        end
        else begin
            $display("FAILURE: %0d BRANCH CONDITION TESTS FAILED.",
                     error_count);
        end

        $finish;
    end

endmodule