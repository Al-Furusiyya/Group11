`timescale 1ns / 1ps

/*
    FPGA demonstration for the ALU and Register File datapath.

    KEY0:
        Active-low reset button.

    SW[3:0]:
        Selects R0 through R15 after the test finishes.

    HEX3:HEX0:
        Selected register value.

    HEX4:
        Selected register number.

    HEX5:
        Current test state.

    LEDR[4:0]:
        Stored flags {C, L, N, F, Z}.

    LEDR[8:5]:
        Current test state.

    LEDR[9]:
        Test sequence finished.
*/

module demo_Datapath (
    input wire CLOCK_50,
    input wire [3:0] SW,
    input wire [0:0] KEY,

    output wire [9:0] LEDR,

    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5
);

    // ALU operation codes
    localparam [3:0] SEXT = 4'h1;
    localparam [3:0] ADD  = 4'h2;
    localparam [3:0] AND  = 4'h4;
    localparam [3:0] OR   = 4'h5;
    localparam [3:0] XOR  = 4'h6;
    localparam [3:0] MULT = 4'h7;
    localparam [3:0] LSH  = 4'h9;
    localparam [3:0] NOT  = 4'hC;
    localparam [3:0] NOP  = 4'hF;

    // KEY0 is active-low on the FPGA board.
    wire reset;

    assign reset = ~KEY[0];

    // --------------------------------------------------
    // Slow counter
    //
    // CLOCK_50 runs at 50 MHz.
    // 25,000,000 cycles is approximately 0.5 seconds.
    // --------------------------------------------------

    reg [25:0] slow_counter;
    wire step_enable;

    assign step_enable =
        (slow_counter == 26'd24999999);

    // Current demonstration state
    reg [3:0] state;

    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            slow_counter <= 26'd0;
        end
        else begin
            if (state == 4'd15) begin
                slow_counter <= 26'd0;
            end
            else if (step_enable) begin
                slow_counter <= 26'd0;
            end
            else begin
                slow_counter <= slow_counter + 26'd1;
            end
        end
    end

    // Advance to the next operation every half-second.
    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            state <= 4'd0;
        end
        else begin
            if (step_enable) begin
                if (state < 4'd15)
                    state <= state + 4'd1;
                else
                    state <= state;
            end
        end
    end

    // --------------------------------------------------
    // Datapath control signals
    // --------------------------------------------------

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

    // --------------------------------------------------
    // Simple control sequence
    // --------------------------------------------------

    always @(state or SW or step_enable) begin

        // Default control values
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

        case (state)

            // R1 = 0005
            4'd0: begin
                external_load = 1'b1;
                external_data = 16'h0005;
                write_address = 4'd1;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R2 = 0003
            4'd1: begin
                external_load = 1'b1;
                external_data = 16'h0003;
                write_address = 4'd2;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R3 = R1 + R2 = 0008
            4'd2: begin
                read_address_a = 4'd1;
                read_address_b = 4'd2;

                alu_op = ADD;
                write_address = 4'd3;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R4 = R3 + immediate 2 = 000A
            4'd3: begin
                read_address_a = 4'd3;

                alu_op = ADD;
                use_immediate = 1'b1;
                immediate_value = 16'h0002;
                write_address = 4'd4;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R5 = FFFF
            4'd4: begin
                external_load = 1'b1;
                external_data = 16'hFFFF;
                write_address = 4'd5;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R6 = 0001
            4'd5: begin
                external_load = 1'b1;
                external_data = 16'h0001;
                write_address = 4'd6;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R7 = R5 + R6
            //
            // FFFF + 0001 = 0000 with carry.
            // Store the C and F flags.
            4'd6: begin
                read_address_a = 4'd5;
                read_address_b = 4'd6;

                alu_op = ADD;
                write_address = 4'd7;

                if (step_enable) begin
                    write_enable = 1'b1;
                    flag_write_enable = 5'b10010;
                end
            end

            // R8 = R1 + R2 + stored carry
            //
            // 5 + 3 + 1 = 9
            4'd7: begin
                read_address_a = 4'd1;
                read_address_b = 4'd2;

                alu_op = ADD;
                use_carry = 1'b1;
                write_address = 4'd8;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R9 = R1 AND R2
            //
            // 0005 AND 0003 = 0001
            4'd8: begin
                read_address_a = 4'd1;
                read_address_b = 4'd2;

                alu_op = AND;
                write_address = 4'd9;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R10 = R1 OR R2
            //
            // 0005 OR 0003 = 0007
            4'd9: begin
                read_address_a = 4'd1;
                read_address_b = 4'd2;

                alu_op = OR;
                write_address = 4'd10;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R11 = R1 XOR R2
            //
            // 0005 XOR 0003 = 0006
            4'd10: begin
                read_address_a = 4'd1;
                read_address_b = 4'd2;

                alu_op = XOR;
                write_address = 4'd11;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R12 = NOT R1
            //
            // NOT 0005 = FFFA
            4'd11: begin
                read_address_a = 4'd1;

                alu_op = NOT;
                write_address = 4'd12;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R13 = R1 shifted left by R2
            //
            // 0005 shifted left by 3 = 0028
            4'd12: begin
                read_address_a = 4'd1;
                read_address_b = 4'd2;

                alu_op = LSH;
                write_address = 4'd13;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R14 = R1 multiplied by R2
            //
            // 5 multiplied by 3 = 15 = 000F
            4'd13: begin
                read_address_a = 4'd1;
                read_address_b = 4'd2;

                alu_op = MULT;
                write_address = 4'd14;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // R15 = sign-extended immediate 80
            //
            // Sign extension produces FF80.
            4'd14: begin
                alu_op = SEXT;
                use_immediate = 1'b1;
                immediate_value = 16'h0080;
                write_address = 4'd15;

                if (step_enable)
                    write_enable = 1'b1;
            end

            // Display mode
            //
            // SW[3:0] selects which register is displayed.
            4'd15: begin
                read_enable_a = 1'b1;
                read_address_a = SW;

                read_enable_b = 1'b0;
                read_address_b = 4'd0;

                write_enable = 1'b0;
                alu_op = NOP;
            end

            default: begin
                read_address_a = 4'd0;
                read_address_b = 4'd0;
                write_enable = 1'b0;
                alu_op = NOP;
            end

        endcase
    end

    // --------------------------------------------------
    // Complete ALU and Register File datapath
    // --------------------------------------------------

    ALU_RegFile_Datapath datapath (
        .clk(CLOCK_50),
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

    // During the operation sequence, display the value that
    // is about to be written.
    //
    // In state F, display the selected register.
    wire [15:0] display_value;

    assign display_value =
        (state == 4'd15) ? read_data_a : write_back_data;

    // --------------------------------------------------
    // LEDs
    // --------------------------------------------------

    // LEDR[4:0] directly display {C,L,N,F,Z}.
    assign LEDR[4:0] = stored_flags;

    // Display the current state on four LEDs.
    assign LEDR[8:5] = state;

    // LEDR9 indicates that display mode has been reached.
    assign LEDR[9] = (state == 4'd15);

    // --------------------------------------------------
    // Seven-segment displays
    // --------------------------------------------------

    hex_to_seven_segment display_0 (
        .hex_value(display_value[3:0]),
        .segments(HEX0)
    );

    hex_to_seven_segment display_1 (
        .hex_value(display_value[7:4]),
        .segments(HEX1)
    );

    hex_to_seven_segment display_2 (
        .hex_value(display_value[11:8]),
        .segments(HEX2)
    );

    hex_to_seven_segment display_3 (
        .hex_value(display_value[15:12]),
        .segments(HEX3)
    );

    hex_to_seven_segment display_4 (
        .hex_value(SW),
        .segments(HEX4)
    );

    hex_to_seven_segment display_5 (
        .hex_value(state),
        .segments(HEX5)
    );

endmodule


// Active-low hexadecimal seven-segment decoder
module hex_to_seven_segment (
    input wire [3:0] hex_value,
    output reg [6:0] segments
);

    // Explicit sensitivity list.
    always @(hex_value) begin
        case (hex_value)
            4'h0: segments = 7'b1000000;
            4'h1: segments = 7'b1111001;
            4'h2: segments = 7'b0100100;
            4'h3: segments = 7'b0110000;
            4'h4: segments = 7'b0011001;
            4'h5: segments = 7'b0010010;
            4'h6: segments = 7'b0000010;
            4'h7: segments = 7'b1111000;
            4'h8: segments = 7'b0000000;
            4'h9: segments = 7'b0010000;
            4'hA: segments = 7'b0001000;
            4'hB: segments = 7'b0000011;
            4'hC: segments = 7'b1000110;
            4'hD: segments = 7'b0100001;
            4'hE: segments = 7'b0000110;
            4'hF: segments = 7'b0001110;
            default: segments = 7'b1111111;
        endcase
    end

endmodule