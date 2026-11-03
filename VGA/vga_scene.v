// Stage 1: static 640 x 480 intersection layout.
// This module only draws pixels. It does not control traffic or run the CPU.

module vga_scene (
    input wire visible,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire [2:0] test_switches,

    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue
);

    reg [23:0] pixel_color;
    integer i;

    localparam [23:0] BACKGROUND = 24'h0B1320;
    localparam [23:0] PANEL      = 24'h111E2E;
    localparam [23:0] BORDER     = 24'h26364A;
    localparam [23:0] GROUND     = 24'h1A2A31;
    localparam [23:0] SIDEWALK   = 24'h718087;
    localparam [23:0] ROAD       = 24'h283647;
    localparam [23:0] WHITE      = 24'hD4DCE0;
    localparam [23:0] YELLOW     = 24'hD0B96C;

    // Later drawing statements cover earlier ones, like layers of paint.
    always @(*) begin
        pixel_color = BACKGROUND;

        // Main intersection panel: outer border, then inner background.
        if (pixel_x >= 12 && pixel_x < 428 &&
            pixel_y >= 66 && pixel_y < 414)
            pixel_color = BORDER;

        if (pixel_x >= 14 && pixel_x < 426 &&
            pixel_y >= 68 && pixel_y < 412)
            pixel_color = PANEL;

        // Right-hand panel borders.
        if (pixel_x >= 440 && pixel_x < 628 &&
            ((pixel_y >= 66 && pixel_y < 182) ||
             (pixel_y >= 194 && pixel_y < 290) ||
             (pixel_y >= 302 && pixel_y < 414)))
            pixel_color = BORDER;

        // Right-hand panel interiors. Labels will be added later.
        if (pixel_x >= 442 && pixel_x < 626 &&
            ((pixel_y >= 68 && pixel_y < 180) ||
             (pixel_y >= 196 && pixel_y < 288) ||
             (pixel_y >= 304 && pixel_y < 412)))
            pixel_color = PANEL;

        // Header separator.
        if (pixel_x >= 12 && pixel_x < 628 &&
            pixel_y >= 53 && pixel_y < 55)
            pixel_color = BORDER;

        // Bottom legend panel.
        if (pixel_x >= 12 && pixel_x < 628 &&
            pixel_y >= 426 && pixel_y < 466)
            pixel_color = BORDER;

        if (pixel_x >= 14 && pixel_x < 626 &&
            pixel_y >= 428 && pixel_y < 464)
            pixel_color = PANEL;

        // Ground around the roads.
        if (pixel_x >= 20 && pixel_x < 420 &&
            pixel_y >= 98 && pixel_y < 406)
            pixel_color = GROUND;

        // Wide strips form the sidewalks along both roads.
        if ((pixel_x >= 165 && pixel_x < 275 &&
             pixel_y >= 98 && pixel_y < 406) ||
            (pixel_x >= 20 && pixel_x < 420 &&
             pixel_y >= 201 && pixel_y < 311))
            pixel_color = SIDEWALK;

        // Narrower strips form the road surfaces inside the sidewalks.
        if ((pixel_x >= 171 && pixel_x < 269 &&
             pixel_y >= 98 && pixel_y < 406) ||
            (pixel_x >= 20 && pixel_x < 420 &&
             pixel_y >= 207 && pixel_y < 305))
            pixel_color = ROAD;

        // Dashed center lines. Keep the middle of the intersection clear.
        // The fixed loop is expanded into hardware by synthesis.
        for (i = 0; i < 20; i = i + 1) begin
            if (pixel_x >= 219 && pixel_x < 221 &&
                pixel_y >= 98 + i * 20 && pixel_y < 108 + i * 20 &&
                ((pixel_y >= 98 && pixel_y < 178) ||
                 (pixel_y >= 334 && pixel_y < 406)))
                pixel_color = YELLOW;

            if (pixel_y >= 255 && pixel_y < 257 &&
                pixel_x >= 20 + i * 20 && pixel_x < 30 + i * 20 &&
                ((pixel_x >= 20 && pixel_x < 142) ||
                 (pixel_x >= 298 && pixel_x < 420)))
                pixel_color = YELLOW;
        end

        // Eight white stripes on each of the four crosswalks.
        for (i = 0; i < 8; i = i + 1) begin
            if (pixel_x >= 176 + i * 11 && pixel_x < 182 + i * 11 &&
                ((pixel_y >= 185 && pixel_y < 199) ||
                 (pixel_y >= 313 && pixel_y < 327)))
                pixel_color = WHITE;

            if (pixel_y >= 212 + i * 11 && pixel_y < 218 + i * 11 &&
                ((pixel_x >= 149 && pixel_x < 163) ||
                 (pixel_x >= 277 && pixel_x < 291)))
                pixel_color = WHITE;
        end

        // Stop lines for the four approaching vehicle lanes.
        if ((pixel_x >= 175 && pixel_x < 216 &&
             pixel_y >= 175 && pixel_y < 178) ||
            (pixel_x >= 224 && pixel_x < 265 &&
             pixel_y >= 335 && pixel_y < 338) ||
            (pixel_x >= 137 && pixel_x < 140 &&
             pixel_y >= 260 && pixel_y < 301) ||
            (pixel_x >= 301 && pixel_x < 304 &&
             pixel_y >= 211 && pixel_y < 252))
            pixel_color = WHITE;

        // Divider inside the future vehicle-signal status panel.
        if (pixel_x >= 452 && pixel_x < 616 &&
            pixel_y >= 248 && pixel_y < 250)
            pixel_color = BORDER;

        // Temporary switch indicators in the bottom panel.
        // SW2 controls red, SW1 controls green, and SW0 controls blue.
        if (pixel_x >= 24 && pixel_x < 42 &&
            pixel_y >= 438 && pixel_y < 454) begin
            if (test_switches[2])
                pixel_color = 24'hFF747B;
            else
                pixel_color = BORDER;
        end

        if (pixel_x >= 52 && pixel_x < 70 &&
            pixel_y >= 438 && pixel_y < 454) begin
            if (test_switches[1])
                pixel_color = 24'h55DDA4;
            else
                pixel_color = BORDER;
        end

        if (pixel_x >= 80 && pixel_x < 98 &&
            pixel_y >= 438 && pixel_y < 454) begin
            if (test_switches[0])
                pixel_color = 24'h7BB4FF;
            else
                pixel_color = BORDER;
        end

        // Blanking has priority over every drawing layer.
        if (!visible)
            pixel_color = 24'h000000;
    end

    assign red   = pixel_color[23:16];
    assign green = pixel_color[15:8];
    assign blue  = pixel_color[7:0];

endmodule
