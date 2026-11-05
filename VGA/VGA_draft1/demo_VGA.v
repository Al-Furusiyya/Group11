module demo_VGA (
    input wire CLOCK_50,
    input wire [0:0] KEY,
    input wire [3:0] SW,

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
    wire [1:0] light_ns;
    wire [1:0] light_ew;

    // Fixed pedestrian display samples, ordered N, E, S, W.
    // Each byte contains two BCD digits. These do not count down yet.
    wire [3:0] ped_walk = 4'b0000;
    wire [31:0] ped_counts_bcd = {8'h12,8'h08,8'h16,8'h10};

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

    // Switch decisions stay outside the pixel renderer.
    traffic_switch_control manual_control (
        .switches(SW),
        .light_ns(light_ns),
        .light_ew(light_ew)
    );

    // The renderer displays the same states in the scene and dashboard.
    vga_scene scene (
        .visible(visible),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .light_ns(light_ns),
        .light_ew(light_ew),
        .ped_walk(ped_walk),
        .ped_counts_bcd(ped_counts_bcd),
        .red(VGA_R),
        .green(VGA_G),
        .blue(VGA_B)
    );

    assign VGA_BLANK_N = visible;
    assign VGA_SYNC_N = 1'b0;

endmodule
