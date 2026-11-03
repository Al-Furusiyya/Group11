module vga_color (
    input wire visible,
    input wire [2:0] color_select,

    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue
);

    // Each switch enables one color channel.
    // Outside the visible area, every channel is zero.

    assign red =
        (visible && color_select[2]) ? 8'hFF : 8'h00;

    assign green =
        (visible && color_select[1]) ? 8'hFF : 8'h00;

    assign blue =
        (visible && color_select[0]) ? 8'hFF : 8'h00;

endmodule