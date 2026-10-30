`timescale 1ns / 1ps

module tb_CPU_Branch;

    reg clk;
    reg reset;

    reg [3:0] debug_register_select;
    wire [15:0] debug_register_value;

    wire [9:0] pc;
    wire [15:0] instruction;
    wire [2:0] state;
    wire [15:0] read_data_a;
    wire [15:0] read_data_b;
    wire [15:0] alu_result;
    wire [4:0] stored_flags;

    integer error_count;
    integer branch_jump_count;

    reg saw_branch_jump_state;
    reg saw_jump_target;
    reg saw_final_loop;

    CPU_Part1 dut (
        .clk(clk),
        .reset(reset),

        .debug_register_select(debug_register_select),
        .debug_register_value(debug_register_value),

        .pc(pc),
        .instruction(instruction),
        .state(state),

        .read_data_a(read_data_a),
        .read_data_b(read_data_b),
        .alu_result(alu_result),
        .stored_flags(stored_flags)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    // Observe important branch and jump behavior.
    always @(posedge clk) begin
        if (reset) begin
            branch_jump_count <= 0;
            saw_branch_jump_state <= 1'b0;
            saw_jump_target <= 1'b0;
            saw_final_loop <= 1'b0;
        end
        else begin

            if (state == 3'd7) begin
                branch_jump_count <= branch_jump_count + 1;
                saw_branch_jump_state <= 1'b1;
            end

            // Register jump target
            if (pc == 10'h01E)
                saw_jump_target <= 1'b1;

            // Final backward-branch loop
            if (pc == 10'h027)
                saw_final_loop <= 1'b1;
        end
    end

    initial begin

        clk = 1'b0;
        reset = 1'b1;

        debug_register_select = 4'd0;

        error_count = 0;
        branch_jump_count = 0;

        saw_branch_jump_state = 1'b0;
        saw_jump_target = 1'b0;
        saw_final_loop = 1'b0;

        // The BRAM normally loads memory_init.hex.
        // Replace its simulation contents with the branch program.
        #1;
        $readmemh("memory_branch.hex", dut.memory.ram);

        // Hold reset for two rising clock edges.
        repeat (2) @(posedge clk);

        // Release reset away from a rising edge.
        @(negedge clk);
        reset = 1'b0;

        // Allow the complete branch program to execute.
        repeat (180) @(posedge clk);
        #1;

        // TEST 1: LOAD, ADD, and ANDI result
        if (dut.datapath.register_file.registers[1] == 16'h0008) begin
            $display(
                "PASS TEST 1: LOAD, ADD, and ANDI produced R1 = 0008."
            );
        end
        else begin
            $display(
                "FAIL TEST 1: R1 expected 0008, received %h.",
                dut.datapath.register_file.registers[1]
            );
            error_count = error_count + 1;
        end

        // TEST 2: LOAD and STORE path
        if ((dut.datapath.register_file.registers[2] == 16'h0003) &&
            (dut.datapath.register_file.registers[3] == 16'h0008)) begin

            $display(
                "PASS TEST 2: LOAD and STORE datapath values are correct."
            );
        end
        else begin
            $display(
                "FAIL TEST 2: R2 or R3 is incorrect."
            );
            error_count = error_count + 1;
        end

        // TEST 3: Taken BEQ
        if (dut.datapath.register_file.registers[4] == 16'h0011) begin
            $display(
                "PASS TEST 3: Taken BEQ skipped the failure value."
            );
        end
        else begin
            $display(
                "FAIL TEST 3: R4 expected 0011, received %h.",
                dut.datapath.register_file.registers[4]
            );
            error_count = error_count + 1;
        end

        // TEST 4: Taken BLT
        if (dut.datapath.register_file.registers[5] == 16'h0022) begin
            $display(
                "PASS TEST 4: Taken BLT skipped the failure value."
            );
        end
        else begin
            $display(
                "FAIL TEST 4: R5 expected 0022, received %h.",
                dut.datapath.register_file.registers[5]
            );
            error_count = error_count + 1;
        end

        // TEST 5: Taken BNE
        if (dut.datapath.register_file.registers[6] == 16'h0033) begin
            $display(
                "PASS TEST 5: Taken BNE skipped the failure value."
            );
        end
        else begin
            $display(
                "FAIL TEST 5: R6 expected 0033, received %h.",
                dut.datapath.register_file.registers[6]
            );
            error_count = error_count + 1;
        end

        // TEST 6: Unconditional branch
        if (dut.datapath.register_file.registers[7] == 16'h0044) begin
            $display(
                "PASS TEST 6: BUC reached the correct target."
            );
        end
        else begin
            $display(
                "FAIL TEST 6: R7 expected 0044, received %h.",
                dut.datapath.register_file.registers[7]
            );
            error_count = error_count + 1;
        end

        // TEST 7: Register-based unconditional jump
        if ((dut.datapath.register_file.registers[8] == 16'h001E) &&
            (dut.datapath.register_file.registers[9] == 16'h0055)) begin

            $display(
                "PASS TEST 7: JUC loaded the PC from R8."
            );
        end
        else begin
            $display(
                "FAIL TEST 7: Register jump result is incorrect."
            );
            error_count = error_count + 1;
        end

        // TEST 8: Final LOAD and successful BEQ
        if ((dut.datapath.register_file.registers[14] == 16'h0055) &&
            (dut.datapath.register_file.registers[15] == 16'h00AA)) begin

            $display(
                "PASS TEST 8: Final LOAD and BEQ produced R15 = 00AA."
            );
        end
        else begin
            $display(
                "FAIL TEST 8: R14 or R15 is incorrect."
            );
            error_count = error_count + 1;
        end

        // TEST 9: Failure values must have been skipped.
        if ((dut.datapath.register_file.registers[4] != 16'h00EE) &&
            (dut.datapath.register_file.registers[5] != 16'h00EE) &&
            (dut.datapath.register_file.registers[6] != 16'h00EE) &&
            (dut.datapath.register_file.registers[7] != 16'h00EE) &&
            (dut.datapath.register_file.registers[9] != 16'h00EE) &&
            (dut.datapath.register_file.registers[15] != 16'h00EE)) begin

            $display(
                "PASS TEST 9: All skipped failure instructions stayed skipped."
            );
        end
        else begin
            $display(
                "FAIL TEST 9: A skipped failure instruction executed."
            );
            error_count = error_count + 1;
        end

        // TEST 10: First memory result
        if (dut.memory.ram[10'h042] == 16'h0008) begin
            $display(
                "PASS TEST 10: Memory address 042 contains 0008."
            );
        end
        else begin
            $display(
                "FAIL TEST 10: Memory 042 expected 0008, received %h.",
                dut.memory.ram[10'h042]
            );
            error_count = error_count + 1;
        end

        // TEST 11: Final stored result
        if (dut.memory.ram[10'h043] == 16'h0055) begin
            $display(
                "PASS TEST 11: Memory address 043 contains 0055."
            );
        end
        else begin
            $display(
                "FAIL TEST 11: Memory 043 expected 0055, received %h.",
                dut.memory.ram[10'h043]
            );
            error_count = error_count + 1;
        end

        // TEST 12: Final comparison should set Z.
        if (stored_flags[0] == 1'b1) begin
            $display(
                "PASS TEST 12: Final comparison set the Z flag."
            );
        end
        else begin
            $display(
                "FAIL TEST 12: Final comparison did not set Z."
            );
            error_count = error_count + 1;
        end

        // TEST 13: Controller reached BRANCH_JUMP.
        if (saw_branch_jump_state == 1'b1) begin
            $display(
                "PASS TEST 13: FSM reached the BRANCH_JUMP state."
            );
        end
        else begin
            $display(
                "FAIL TEST 13: FSM never reached BRANCH_JUMP."
            );
            error_count = error_count + 1;
        end

        // TEST 14: Register jump reached address 01E.
        if (saw_jump_target == 1'b1) begin
            $display(
                "PASS TEST 14: PC reached register jump target 01E."
            );
        end
        else begin
            $display(
                "FAIL TEST 14: PC never reached jump target 01E."
            );
            error_count = error_count + 1;
        end

        // TEST 15: Negative branch reached the final loop.
        if (saw_final_loop == 1'b1) begin
            $display(
                "PASS TEST 15: Negative branch held the final loop at 027."
            );
        end
        else begin
            $display(
                "FAIL TEST 15: Final backward branch was not observed."
            );
            error_count = error_count + 1;
        end

        // TEST 16: Several branch/jump instructions executed.
        if (branch_jump_count >= 7) begin
            $display(
                "PASS TEST 16: Multiple branch and jump operations executed."
            );
        end
        else begin
            $display(
                "FAIL TEST 16: Only %0d branch/jump states were observed.",
                branch_jump_count
            );
            error_count = error_count + 1;
        end

        // TEST 17: Verify the board debug register output.
        debug_register_select = 4'hF;
        #1;

        if (debug_register_value == 16'h00AA) begin
            $display(
                "PASS TEST 17: Debug port displayed R15 = 00AA."
            );
        end
        else begin
            $display(
                "FAIL TEST 17: Debug R15 expected 00AA, received %h.",
                debug_register_value
            );
            error_count = error_count + 1;
        end

        $display("--------------------------------------------");

        if (error_count == 0) begin
            $display(
                "SUCCESS: ALL CPU BRANCH AND JUMP TESTS PASSED."
            );
        end
        else begin
            $display(
                "FAILURE: %0d CPU BRANCH/JUMP TESTS FAILED.",
                error_count
            );
        end

        $finish;
    end

endmodule