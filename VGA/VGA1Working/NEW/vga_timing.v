module vga_timing (
    input wire clk,
    input wire reset,

    output reg pixel_clock,
    output reg [9:0] pixel_x,
    output reg [9:0] pixel_y,

    output wire visible,
    output wire hsync,
    output wire vsync
);

    // Horizontal timing, measured in pixel periods.
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;

    // Vertical timing, measured in rows.
    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;

    localparam H_TOTAL =
        H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_TOTAL =
        V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pixel_clock <= 1'b0;
            pixel_x <= 10'd0;
            pixel_y <= 10'd0;
        end
        else begin
            // Divide the 50 MHz input clock by two.
            pixel_clock <= ~pixel_clock;

            // Advance the position when pixel_clock falls.
            // This gives the position and colors time to settle
            // before the next rising pixel_clock edge.
            if (pixel_clock == 1'b1) begin
                if (pixel_x == H_TOTAL - 1) begin
                    pixel_x <= 10'd0;

                    if (pixel_y == V_TOTAL - 1)
                        pixel_y <= 10'd0;
                    else
                        pixel_y <= pixel_y + 10'd1;
                end
                else begin
                    pixel_x <= pixel_x + 10'd1;
                end
            end
        end
    end

    // Only the first 640 columns and 480 rows are visible.
    assign visible =
        (pixel_x < H_VISIBLE) &&
        (pixel_y < V_VISIBLE);

    // Horizontal synchronization is active-low.
    assign hsync = ~(
        (pixel_x >= H_VISIBLE + H_FRONT) &&
        (pixel_x < H_VISIBLE + H_FRONT + H_SYNC)
    );

    // Vertical synchronization is active-low.
    assign vsync = ~(
        (pixel_y >= V_VISIBLE + V_FRONT) &&
        (pixel_y < V_VISIBLE + V_FRONT + V_SYNC)
    );

endmodule