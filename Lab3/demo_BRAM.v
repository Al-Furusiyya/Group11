module demo_BRAM
(
    input CLOCK_50,
    input [0:0] KEY,
    input [0:0] SW,

    output [9:0] LEDR,

    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5
);

    wire reset;
    wire [15:0] original_data;
    wire [15:0] updated_data;
    wire [15:0] displayed_data;

    wire error;
    wire done;
    wire [2:0] state_debug;
    wire [1:0] group_debug;

    // KEY0 is active-low
    assign reset = ~KEY[0];

    // SW0 selects which value appears on HEX3 through HEX0
    // SW0 down: original value
    // SW0 up: updated value
    assign displayed_data = SW[0] ? updated_data : original_data;

    // LED status outputs
    assign LEDR[0] = done;
    assign LEDR[1] = error;
    assign LEDR[4:2] = state_debug;
    assign LEDR[6:5] = group_debug;
    assign LEDR[7] = SW[0];
    assign LEDR[9:8] = 2'b00;

    MemoryTestFSM controller (
        .clk(CLOCK_50),
        .reset(reset),
        .original_data(original_data),
        .updated_data(updated_data),
        .error(error),
        .done(done),
        .state_debug(state_debug),
        .group_debug(group_debug)
    );

    hex_to_seven_segment display0 (
        .hex_value(displayed_data[3:0]),
        .segments(HEX0)
    );

    hex_to_seven_segment display1 (
        .hex_value(displayed_data[7:4]),
        .segments(HEX1)
    );

    hex_to_seven_segment display2 (
        .hex_value(displayed_data[11:8]),
        .segments(HEX2)
    );

    hex_to_seven_segment display3 (
        .hex_value(displayed_data[15:12]),
        .segments(HEX3)
    );

    hex_to_seven_segment display4 (
        .hex_value({1'b0, state_debug}),
        .segments(HEX4)
    );

    hex_to_seven_segment display5 (
        .hex_value({2'b00, group_debug}),
        .segments(HEX5)
    );

endmodule


module hex_to_seven_segment
(
    input [3:0] hex_value,
    output reg [6:0] segments
);

    always @(*) begin
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
