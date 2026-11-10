// Board bring-up wrapper: preserve the VGA scene and observe keyboard events.
// This does not yet route keyboard requests into the CPU or spawn cars.
// Use only after verifying PS/2 and LED pin assignments for your board.
module demo_VGA_PS2 (
    input wire CLOCK_50,
    input wire [0:0] KEY,
    input wire [2:0] SW,
    input wire PS2_CLK,
    input wire PS2_DAT,
    output wire [9:0] LEDR,
    output wire [7:0] VGA_R,
    output wire [7:0] VGA_G,
    output wire [7:0] VGA_B,
    output wire VGA_HS,
    output wire VGA_VS,
    output wire VGA_CLK,
    output wire VGA_BLANK_N,
    output wire VGA_SYNC_N
);

    wire reset;
    wire visible;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire [7:0] scan_code;
    wire scan_valid;
    wire frame_error;
    wire [7:0] key_code;
    wire key_pressed;
    reg event_toggle;
    reg error_seen;

    assign reset = ~KEY[0];

    vga_timing timing (
        .clk(CLOCK_50), .reset(reset),
        .pixel_clock(VGA_CLK),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .visible(visible), .hsync(VGA_HS), .vsync(VGA_VS)
    );

    vga_scene scene (
        .visible(visible),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .test_switches(SW),
        .red(VGA_R), .green(VGA_G), .blue(VGA_B)
    );

    PS2Keyboard keyboard (
        .clk(CLOCK_50), .reset(reset),
        .ps2_clk(PS2_CLK), .ps2_data(PS2_DAT),
        .scan_code(scan_code), .scan_valid(scan_valid),
        .frame_error(frame_error),
        .key_code(key_code), .key_pressed(key_pressed)
    );

    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset) begin
            event_toggle <= 1'b0;
            error_seen <= 1'b0;
        end
        else begin
            if (key_pressed) event_toggle <= ~event_toggle;
            if (frame_error) error_seen <= 1'b1;
        end
    end

    assign LEDR[7:0] = key_code;
    assign LEDR[8] = event_toggle;
    assign LEDR[9] = error_seen;
    assign VGA_BLANK_N = visible;
    assign VGA_SYNC_N = 1'b0;
endmodule
