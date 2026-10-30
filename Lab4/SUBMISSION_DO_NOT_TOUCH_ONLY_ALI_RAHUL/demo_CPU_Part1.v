module demo_CPU_Part1 (
    input wire CLOCK_50,
input wire [0:0] KEY,
input wire [3:0] SW,
output wire [9:0] LEDR,

output wire [6:0] HEX0,
output wire [6:0] HEX1,
output wire [6:0] HEX2,
output wire [6:0] HEX3,
output wire [6:0] HEX4,
output wire [6:0] HEX5
);
wire reset;

wire [15:0] selected_register_value;
    wire [9:0] pc;
wire [15:0] instruction;
wire [2:0] state;
wire [15:0] read_data_a;
    wire [15:0] read_data_b;
wire [15:0] alu_result;
wire [4:0] stored_flags;
reg program_done;

    // KEY0 is active-low on the DE1-SoC board.
assign reset = ~KEY[0];

CPU_Part1 cpu (
.clk(CLOCK_50),
.reset(reset),

.debug_register_select(SW),
.debug_register_value(selected_register_value),

.pc(pc),
.instruction(instruction),
.state(state),
.read_data_a(read_data_a),
.read_data_b(read_data_b),
.alu_result(alu_result),
.stored_flags(stored_flags)
    );

    // Remember when the complete program has executed.
   always @(posedge CLOCK_50 or posedge reset) begin
if (reset)
program_done <= 1'b0;
else if (pc >= 10'd21)
program_done <= 1'b1;
    end

    // LEDR[4:0] display the stored flags: C, L, N, F, Z.
    assign LEDR[4:0] = stored_flags;

    // LEDR[7:5] display the current FSM state.
assign LEDR[7:5] = state;

    // Unused LED.
assign LEDR[8] = 1'b0;

    // LEDR9 turns on after the complete program executes.
assign LEDR[9] = program_done;

    // Four HEX displays show the selected register value.
hex_to_seven_segment display0 (
.hex_value(selected_register_value[3:0]),
.segments(HEX0)
    );

    hex_to_seven_segment display1 (
.hex_value(selected_register_value[7:4]),
.segments(HEX1)
    );

    hex_to_seven_segment display2 (
.hex_value(selected_register_value[11:8]),
.segments(HEX2)
    );

hex_to_seven_segment display3 (
.hex_value(selected_register_value[15:12]),
.segments(HEX3)
    );

    // HEX4 shows the selected register number.
    hex_to_seven_segment display4 (
.hex_value(SW),
.segments(HEX4)
    );

    // HEX5 shows D after the program finishes.
    // Before completion, it displays the FSM state.
    hex_to_seven_segment display5 (
.hex_value(program_done ? 4'hD : {1'b0, state}),
.segments(HEX5)
    );

endmodule


module hex_to_seven_segment (
    input wire [3:0] hex_value,
output reg [6:0] segments
);

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
