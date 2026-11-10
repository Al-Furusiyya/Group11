// Combined receiver and key decoder. This does not make traffic decisions.
// key_pressed is a one-clock pulse. key_code holds the last accepted key.
// The future CPU-facing input register must latch this event for polling.
module PS2Keyboard #(
    parameter integer TIMEOUT_CYCLES = 100000
) (
    input wire clk,
    input wire reset,
    input wire ps2_clk,
    input wire ps2_data,
    output wire [7:0] scan_code,
    output wire scan_valid,
    output wire frame_error,
    output wire [7:0] key_code,
    output wire key_pressed
);

    PS2Receiver #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES)) receiver (
        .clk(clk),
        .reset(reset),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .scan_code(scan_code),
        .scan_valid(scan_valid),
        .frame_error(frame_error)
    );

    PS2KeyDecoder #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES)) decoder (
        .clk(clk),
        .reset(reset),
        .scan_code(scan_code),
        .scan_valid(scan_valid),
        .frame_error(frame_error),
        .key_code(key_code),
        .key_pressed(key_pressed)
    );
endmodule
