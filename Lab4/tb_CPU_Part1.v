`timescale 1ns / 1ps

module tb_CPU_Part1;

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

    reg saw_load_request;
    reg saw_load_write;
    reg saw_store_write;

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

    // Record whether each memory state was reached.
    always @(posedge clk) begin
        if (reset) begin
            saw_load_request <= 1'b0;
            saw_load_write <= 1'b0;
            saw_store_write <= 1'b0;
        end
        else begin
            if (state == 3'd4)
                saw_load_request <= 1'b1;

            if (state == 3'd5)
                saw_load_write <= 1'b1;

            if (state == 3'd6)
                saw_store_write <= 1'b1;
        end
    end

    initial begin

        clk = 1'b0;
        reset = 1'b1;
        debug_register_select = 4'd0;
        error_count = 0;

        saw_load_request = 1'b0;
        saw_load_write = 1'b0;
        saw_store_write = 1'b0;

        // Hold reset for two rising edges.
        repeat (2) @(posedge clk);

        // Release reset away from the rising edge.
        @(negedge clk);
        reset = 1'b0;

        // Allow the final program to complete.
        repeat (110) @(posedge clk);
        #1;

        // ADD and SUBI result
        if (dut.datapath.register_file.registers[1] == 16'h0007)
            $display("PASS TEST 1: ADD and SUBI produced R1 = 0007.");
        else begin
            $display("FAIL TEST 1: R1 expected 0007, received %h.",
                dut.datapath.register_file.registers[1]);
            error_count = error_count + 1;
        end

        // Loaded second operand
        if (dut.datapath.register_file.registers[2] == 16'h0003)
            $display("PASS TEST 2: LOAD produced R2 = 0003.");
        else begin
            $display("FAIL TEST 2: R2 expected 0003, received %h.",
                dut.datapath.register_file.registers[2]);
            error_count = error_count + 1;
        end

        // MOV, MUL, ANDI, ORI, and XORI result
        if (dut.datapath.register_file.registers[3] == 16'h0030)
            $display("PASS TEST 3: MUL and logic sequence produced R3 = 0030.");
        else begin
            $display("FAIL TEST 3: R3 expected 0030, received %h.",
                dut.datapath.register_file.registers[3]);
            error_count = error_count + 1;
        end

        // LUI and ORI result
        if (dut.datapath.register_file.registers[4] == 16'hAB34)
            $display("PASS TEST 4: LUI and ORI produced R4 = AB34.");
        else begin
            $display("FAIL TEST 4: R4 expected AB34, received %h.",
                dut.datapath.register_file.registers[4]);
            error_count = error_count + 1;
        end

        // Reloaded value plus immediate
        if (dut.datapath.register_file.registers[5] == 16'h0032)
            $display("PASS TEST 5: LOAD and ADDI produced R5 = 0032.");
        else begin
            $display("FAIL TEST 5: R5 expected 0032, received %h.",
                dut.datapath.register_file.registers[5]);
            error_count = error_count + 1;
        end

        // Final memory reload
        if (dut.datapath.register_file.registers[6] == 16'h0032)
            $display("PASS TEST 6: Final LOAD produced R6 = 0032.");
        else begin
            $display("FAIL TEST 6: R6 expected 0032, received %h.",
                dut.datapath.register_file.registers[6]);
            error_count = error_count + 1;
        end

        // Address registers
        if (dut.datapath.register_file.registers[10] == 16'h0040 &&
            dut.datapath.register_file.registers[11] == 16'h0041 &&
            dut.datapath.register_file.registers[12] == 16'h0042)
            $display("PASS TEST 7: Memory address registers are correct.");
        else begin
            $display("FAIL TEST 7: Memory address registers are incorrect.");
            error_count = error_count + 1;
        end

        // Stored memory value
        if (dut.memory.ram[10'h042] == 16'h0032)
            $display("PASS TEST 8: Memory address 042 contains 0032.");
        else begin
            $display("FAIL TEST 8: Memory 042 expected 0032, received %h.",
                dut.memory.ram[10'h042]);
            error_count = error_count + 1;
        end

        // Equal comparison
        if (stored_flags == 5'b00001)
            $display("PASS TEST 9: CMP set the Z flag.");
        else begin
            $display("FAIL TEST 9: Flags expected 00001, received %b.",
                stored_flags);
            error_count = error_count + 1;
        end

        // LOAD state verification
        if (saw_load_request && saw_load_write)
            $display("PASS TEST 10: FSM completed both LOAD states.");
        else begin
            $display("FAIL TEST 10: FSM did not complete both LOAD states.");
            error_count = error_count + 1;
        end

        // STORE state verification
        if (saw_store_write)
            $display("PASS TEST 11: FSM completed the STORE state.");
        else begin
            $display("FAIL TEST 11: FSM did not reach STORE_WRITE.");
            error_count = error_count + 1;
        end

        // Program counter verification
        if (pc >= 10'd21)
            $display("PASS TEST 12: Program counter completed the program.");
        else begin
            $display("FAIL TEST 12: Program counter only reached %d.", pc);
            error_count = error_count + 1;
        end

        // Board debug-port verification
        debug_register_select = 4'd4;
        #1;

        if (debug_register_value == 16'hAB34)
            $display("PASS TEST 13: Debug port displayed R4 = AB34.");
        else begin
            $display("FAIL TEST 13: Debug R4 expected AB34, received %h.",
                debug_register_value);
            error_count = error_count + 1;
        end

        $display("--------------------------------------------");

        if (error_count == 0)
            $display("SUCCESS: FINAL PART 1 CPU TEST PASSED.");
        else
            $display("FAILURE: %0d FINAL CPU TESTS FAILED.", error_count);

        $finish;
    end

endmodule