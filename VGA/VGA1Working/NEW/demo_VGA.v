module demo_VGA (
    input wire CLOCK_50,
    input wire [0:0] KEY,
    input wire [2:0] SW,

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

    assign reset = ~KEY[0];

    // Keep the same timing module used by the working color test.
    vga_timing timing (
        .clk(CLOCK_50),
        .reset(reset),
        .pixel_clock(VGA_CLK),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .visible(visible),
        .hsync(VGA_HS),
        .vsync(VGA_VS)
    );

    // Draw the new intersection instead of the solid-color test.
    vga_scene scene (
        .visible(visible),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .test_switches(SW),
        .red(VGA_R),
        .green(VGA_G),
        .blue(VGA_B)
    );

    assign VGA_BLANK_N = visible;
    assign VGA_SYNC_N = 1'b0;

endmodule
