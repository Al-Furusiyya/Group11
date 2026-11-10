// Retro isometric intersection -- STATIC GRAPHICS ONLY.
// Compact left menu is unchanged. The right intersection is zoomed out,
// with smaller cars and queue space for five cars per incoming lane.
// Timer digits are static examples, not live countdowns.
// Bracketed keys are labels only; this module does not process key presses.
// 640 x 480 output. Menu and timer cards retain their 2 x 2 pixel scale.
// Roads, car sprites, signals, and roadside people use native VGA pixels.
// Drop-in replacement for the original vga_scene.v. No clock, RAM files,
// traffic FSM, CPU interface, animation, or working menu is required.
// test_switches is retained only to match the existing demo_VGA ports.

module vga_scene (
    input  wire       visible,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire [2:0] test_switches,
    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue
);

    // Menu coordinates stay on the original 320 x 240 artwork grid.
    // The road center and car anchors now use native 640 x 480 pixels.
    localparam MENU_EDGE = 75;
    localparam CENTER_X  = 396;
    localparam CENTER_Y  = 256;
    localparam ROAD_HALF = 60;

    // One visible car per approach. Each sprite now occupies at most
    // 32 x 24 VGA pixels instead of the previous 64 x 48 VGA pixels.
    localparam NW_CAR_X = 302, NW_CAR_Y = 216;
    localparam NE_CAR_X = 476, NE_CAR_Y = 209;
    localparam SW_CAR_X = 316, SW_CAR_Y = 303;
    localparam SE_CAR_X = 490, SE_CAR_Y = 296;

    // Reserved queue geometry for later software, not live car storage:
    // Slot k ranges from 0 to 4. Move each later slot away from the stop.
    // NW/N: anchor + (-28*k, -14*k)
    // NE/E: anchor + ( 28*k, -14*k)
    // SW/W: anchor + (-28*k,  14*k)
    // SE/S: anchor + ( 28*k,  14*k)
    // Adjacent straight/right lane offsets from these left-lane anchors:
    // NW/N (-15,+8), NE/E (-15,-8), SW/W (+15,+8), SE/S (+15,-8).
    // Five cars fit in either incoming lane; only slot zero is drawn now.

    // Palette indices. The same 16 flat colors are used everywhere.
    localparam [3:0] BLACK       = 4'd0;
    localparam [3:0] ASPHALT     = 4'd1;
    localparam [3:0] WHITE       = 4'd2;
    localparam [3:0] GRAY        = 4'd3;
    localparam [3:0] YELLOW      = 4'd4;
    localparam [3:0] CORAL       = 4'd5;
    localparam [3:0] DIM_RED     = 4'd6;
    localparam [3:0] GREEN       = 4'd7;
    localparam [3:0] DIM_GREEN   = 4'd8;
    localparam [3:0] DIM_YELLOW  = 4'd9;
    localparam [3:0] MINT        = 4'd10;
    localparam [3:0] MINT_SHADE  = 4'd11;
    localparam [3:0] CORAL_SHADE = 4'd12;
    localparam [3:0] GOLD_SHADE  = 4'd13;
    localparam [3:0] GLASS       = 4'd14;
    localparam [3:0] GLASS_LIGHT = 4'd15;

    function [23:0] palette;
        input [3:0] index;
        begin
            case (index)
                BLACK:       palette = 24'h000000;
                ASPHALT:     palette = 24'h292B30;
                WHITE:       palette = 24'hDCE0D8;
                GRAY:        palette = 24'h8C9494;
                YELLOW:      palette = 24'hE4C94C;
                CORAL:       palette = 24'hF06C68;
                DIM_RED:     palette = 24'h482728;
                GREEN:       palette = 24'h40D8A0;
                DIM_GREEN:   palette = 24'h18382C;
                DIM_YELLOW:  palette = 24'h4C4420;
                MINT:        palette = 24'h38D0BC;
                MINT_SHADE:  palette = 24'h208C80;
                CORAL_SHADE: palette = 24'hB34C50;
                GOLD_SHADE:  palette = 24'hA48C30;
                GLASS:       palette = 24'hC0E0E0;
                GLASS_LIGHT: palette = 24'hECF0E4;
                default:     palette = 24'h000000;
            endcase
        end
    endfunction

    // Five columns x seven rows; bit 34 is the upper-left font pixel.
    function [34:0] glyph;
        input [7:0] character;
        begin
            case (character)
                8'h20: glyph = 35'h000000000; //  
                8'h2D: glyph = 35'h0000F8000; // -
                8'h30: glyph = 35'h3A33AE62E; // 0
                8'h31: glyph = 35'h11842108E; // 1
                8'h32: glyph = 35'h3A211111F; // 2
                8'h33: glyph = 35'h78217043E; // 3
                8'h34: glyph = 35'h08CA97C42; // 4
                8'h35: glyph = 35'h7E10F043E; // 5
                8'h36: glyph = 35'h3A10F462E; // 6
                8'h37: glyph = 35'h7C2222108; // 7
                8'h38: glyph = 35'h3A317462E; // 8
                8'h39: glyph = 35'h3A317842E; // 9
                8'h41: glyph = 35'h3A31FC631; // A
                8'h42: glyph = 35'h7A31F463E; // B
                8'h43: glyph = 35'h3E108420F; // C
                8'h44: glyph = 35'h7A318C63E; // D
                8'h45: glyph = 35'h7E10F421F; // E
                8'h46: glyph = 35'h7E10F4210; // F
                8'h47: glyph = 35'h3E10BC62F; // G
                8'h48: glyph = 35'h4631FC631; // H
                8'h49: glyph = 35'h7C842109F; // I
                8'h4A: glyph = 35'h1C4214A4C; // J
                8'h4B: glyph = 35'h4654C5251; // K
                8'h4C: glyph = 35'h42108421F; // L
                8'h4D: glyph = 35'h4775AC631; // M
                8'h4E: glyph = 35'h4739ACE71; // N
                8'h4F: glyph = 35'h3A318C62E; // O
                8'h50: glyph = 35'h7A31F4210; // P
                8'h51: glyph = 35'h3A318D64D; // Q
                8'h52: glyph = 35'h7A31F5251; // R
                8'h53: glyph = 35'h3E107043E; // S
                8'h54: glyph = 35'h7C8421084; // T
                8'h55: glyph = 35'h46318C62E; // U
                8'h56: glyph = 35'h46318C544; // V
                8'h57: glyph = 35'h4631AD6AA; // W
                8'h58: glyph = 35'h462A22A31; // X
                8'h59: glyph = 35'h462A21084; // Y
                8'h5A: glyph = 35'h7C222221F; // Z
                8'h5B: glyph = 35'h39084210E; // [
                8'h5D: glyph = 35'h38421084E; // ]
                default: glyph = 35'd0;
            endcase
        end
    endfunction

    // Each character occupies a 6 x 8 cell. Strings are right-aligned
    // in this 12-character argument, as with a normal Verilog string.
    function text_pixel;
        input [8:0] px, py;
        input integer left, top, count;
        input [95:0] message;
        reg signed [10:0] tx, ty;
        integer i;
        reg [34:0] bits;
        reg [5:0] bit_index;
        begin
            text_pixel = 1'b0;
            tx = $signed({2'b00,px}) - left;
            ty = $signed({2'b00,py}) - top;
            bits = 35'd0;
            bit_index = 6'd0;
            // The loop is expanded during synthesis. Every message and
            // character is constant: no divider or runtime string engine.
            if (tx >= 0 && tx < count*6 && ty >= 0 && ty < 7) begin
                for (i=0; i<12; i=i+1) begin
                    if (i < count && tx >= i*6 && tx < i*6+5) begin
                        bits = glyph(message >> ((count-1-i)*8));
                        bit_index = 34 - ty*5 - (tx-i*6);
                        text_pixel = bits[bit_index];
                    end
                end
            end
        end
    endfunction

    // Compact 3 x 5 font for the single-line PEDESTRIAN [P] heading.
    // The normal 5 x 7 text remains unchanged for all other menu labels.
    function [14:0] compact_glyph;
        input [7:0] character;
        begin
            case (character)
                "A": compact_glyph = {3'b010,3'b101,3'b111,3'b101,3'b101};
                "D": compact_glyph = {3'b110,3'b101,3'b101,3'b101,3'b110};
                "E": compact_glyph = {3'b111,3'b100,3'b110,3'b100,3'b111};
                "I": compact_glyph = {3'b111,3'b010,3'b010,3'b010,3'b111};
                "N": compact_glyph = {3'b101,3'b111,3'b111,3'b111,3'b101};
                "P": compact_glyph = {3'b110,3'b101,3'b110,3'b100,3'b100};
                "R": compact_glyph = {3'b110,3'b101,3'b110,3'b101,3'b101};
                "S": compact_glyph = {3'b111,3'b100,3'b111,3'b001,3'b111};
                "T": compact_glyph = {3'b111,3'b010,3'b010,3'b010,3'b010};
                "[": compact_glyph = {3'b110,3'b100,3'b100,3'b100,3'b110};
                "]": compact_glyph = {3'b011,3'b001,3'b001,3'b001,3'b011};
                default: compact_glyph = 15'd0;
            endcase
        end
    endfunction

    // Four columns per character; supports this 14-character heading.
    function compact_text_pixel;
        input [8:0] px, py;
        input integer left, top, count;
        input [111:0] message;
        reg signed [10:0] tx, ty;
        integer i;
        reg [14:0] bits;
        reg [3:0] bit_index;
        begin
            compact_text_pixel = 1'b0;
            tx = $signed({2'b00,px}) - left;
            ty = $signed({2'b00,py}) - top;
            bits = 15'd0;
            bit_index = 4'd0;
            if (tx >= 0 && tx < count*4 && ty >= 0 && ty < 5) begin
                for (i=0; i<14; i=i+1) begin
                    if (i < count && tx >= i*4 && tx < i*4+3) begin
                        bits = compact_glyph(message >> ((count-1-i)*8));
                        bit_index = 14 - ty*3 - (tx-i*4);
                        compact_text_pixel = bits[bit_index];
                    end
                end
            end
        end
    endfunction

    // 32 x 24 car sprites, 3 bits per pixel. These constant rows are
    // inside this source file; there is no external .hex or .mif asset.
    // Direction: 0 southeast, 1 southwest, 2 northwest, 3 northeast.
    function [95:0] car_row;
        input [6:0] address;
        begin
            case (address)
                7'd4: car_row = 96'h000000002000000000000000;
                7'd5: car_row = 96'h000000092480000000000000;
                7'd6: car_row = 96'h000002492492000000000000;
                7'd7: car_row = 96'h00009B692492480000000000;
                7'd8: car_row = 96'h0024DB6DA492492000000000;
                7'd9: car_row = 96'h0526DB6DA6924A4800000000;
                7'd10: car_row = 96'h04B6DB6D36DA924900000000;
                7'd11: car_row = 96'h0492DB6D36DC924920000000;
                7'd12: car_row = 96'h04D24B69B6DC924924000000;
                7'd13: car_row = 96'h005B4929B6DC924912480000;
                7'd14: car_row = 96'h005B6D24B6DC924492492000;
                7'd15: car_row = 96'h005B6D2492DC912492492480;
                7'd16: car_row = 96'h00016D04924C492492492480;
                7'd17: car_row = 96'h000005001249252492492480;
                7'd18: car_row = 96'h00000000004D249492492480;
                7'd19: car_row = 96'h000000000005B49292492000;
                7'd20: car_row = 96'h000000000005B6D292480000;
                7'd21: car_row = 96'h000000000005B6D292000000;
                7'd22: car_row = 96'h00000000000016D080000000;
                7'd23: car_row = 96'h000000000000005000000000;
                7'd36: car_row = 96'h000000000000002000000000;
                7'd37: car_row = 96'h000000000000092480000000;
                7'd38: car_row = 96'h000000000002492492000000;
                7'd39: car_row = 96'h0000000000924924A4880000;
                7'd40: car_row = 96'h000000002492492924912000;
                7'd41: car_row = 96'h00000001B6924A2924922480;
                7'd42: car_row = 96'h0000000DB6DA924524924480;
                7'd43: car_row = 96'h0000006DB6DC924524912480;
                7'd44: car_row = 96'h0000036DB6DC9248A4495480;
                7'd45: car_row = 96'h0000924DB6DC92489256D000;
                7'd46: car_row = 96'h0024924936DC924495B6D000;
                7'd47: car_row = 96'h0524924924DC912495B6D000;
                7'd48: car_row = 96'h049492492494492485B40000;
                7'd49: car_row = 96'h049252492492492005000000;
                7'd50: car_row = 96'h049249492495480000000000;
                7'd51: car_row = 96'h00124929256D000000000000;
                7'd52: car_row = 96'h000049295B6D000000000000;
                7'd53: car_row = 96'h000001295B6D000000000000;
                7'd54: car_row = 96'h000000085B40000000000000;
                7'd55: car_row = 96'h000000005000000000000000;
                7'd69: car_row = 96'h000000080000000000000000;
                7'd70: car_row = 96'h000002492002000000000000;
                7'd71: car_row = 96'h000092492492480000000000;
                7'd72: car_row = 96'h002492492492492000000000;
                7'd73: car_row = 96'h05249249B692492480000000;
                7'd74: car_row = 96'h0494924DB6DA492492000000;
                7'd75: car_row = 96'h0492526DB6DA6924A4800000;
                7'd76: car_row = 96'h04D24B6DB6D36DA924900000;
                7'd77: car_row = 96'h005B492DB6D36DC924920000;
                7'd78: car_row = 96'h005B6D24B69B6DC924924000;
                7'd79: car_row = 96'h005B6D24929B6DC924912480;
                7'd80: car_row = 96'h00016D04924B6DC924492480;
                7'd81: car_row = 96'h0000050012492DC912492480;
                7'd82: car_row = 96'h00000000004D24C492492480;
                7'd83: car_row = 96'h000000000005B49292492000;
                7'd84: car_row = 96'h000000000005B6D292480000;
                7'd85: car_row = 96'h000000000005B6D292000000;
                7'd86: car_row = 96'h00000000000016D080000000;
                7'd87: car_row = 96'h000000000000005000000000;
                7'd101: car_row = 96'h000000000000000080000000;
                7'd102: car_row = 96'h000000000002002492000000;
                7'd103: car_row = 96'h000000000092492492480000;
                7'd104: car_row = 96'h000000002492492492492000;
                7'd105: car_row = 96'h0000000924924A4892492480;
                7'd106: car_row = 96'h000002492492924912492480;
                7'd107: car_row = 96'h00001B6924A2924922492480;
                7'd108: car_row = 96'h0000DB6DA924524924495480;
                7'd109: car_row = 96'h0006DB6DC92452491256D000;
                7'd110: car_row = 96'h0036DB6DC9248A4495B6D000;
                7'd111: car_row = 96'h0524DB6DC924892495B6D000;
                7'd112: car_row = 96'h0494936DC924492485B40000;
                7'd113: car_row = 96'h0492524DC912492005000000;
                7'd114: car_row = 96'h049249494495480000000000;
                7'd115: car_row = 96'h00124929256D000000000000;
                7'd116: car_row = 96'h000049295B6D000000000000;
                7'd117: car_row = 96'h000001295B6D000000000000;
                7'd118: car_row = 96'h000000085B40000000000000;
                7'd119: car_row = 96'h000000005000000000000000;
                default: car_row = 96'd0;
            endcase
        end
    endfunction

    // Overlay functions return {opaque, palette_index}. Transparent
    // pixels preserve whichever road/background pixel is underneath.
    function [4:0] car_pixel;
        input [9:0] px, py;
        input integer anchor_x, anchor_y;
        input [1:0] direction, paint;
        reg signed [10:0] sx, sy;
        reg [6:0] bit_index;
        reg [95:0] row_bits;
        reg [2:0] ink;
        reg [3:0] top_paint, side_paint;
        begin
            car_pixel = 5'd0;
            sx = $signed({2'b00,px}) - anchor_x + 15;
            sy = $signed({2'b00,py}) - anchor_y + 16;
            bit_index = 7'd0;
            row_bits = 96'd0;
            ink = 3'd0;
            case (paint)
                2'd1: begin top_paint = CORAL;  side_paint = CORAL_SHADE; end
                2'd2: begin top_paint = YELLOW; side_paint = GOLD_SHADE;  end
                default: begin top_paint = MINT; side_paint = MINT_SHADE; end
            endcase
            if (sx >= 0 && sx < 32 && sy >= 0 && sy < 24) begin
                row_bits = car_row({direction, sy[4:0]});
                bit_index = (31-sx[4:0])*3;
                ink = row_bits[bit_index +: 3];
                case (ink)
                    3'd1: car_pixel = {1'b1, side_paint};
                    3'd2: car_pixel = {1'b1, top_paint};
                    3'd3: car_pixel = {1'b1, GLASS};
                    3'd4: car_pixel = {1'b1, GLASS_LIGHT};
                    3'd5: car_pixel = {1'b1, BLACK};
                    default: car_pixel = 5'd0;
                endcase
            end
        end
    endfunction

    // Upright three-lamp traffic-light sprite, with a small curb post.
    // go is a fixed artwork choice here, not a controller output.
    function [4:0] signal_pixel;
        input [9:0] px, py;
        input integer left, top;
        input go;
        reg signed [10:0] sx, sy;
        begin
            signal_pixel = 5'd0;
            sx = $signed({2'b00,px})-left;
            sy = $signed({2'b00,py})-top;
            if (sx == 5 && sy >= 23 && sy < 26)
                signal_pixel = {1'b1, GRAY};
            if (sx >= 0 && sx < 11 && sy >= 0 && sy < 23) begin
                signal_pixel = {1'b1, WHITE};
                if (sx >= 1 && sx < 10 && sy >= 1 && sy < 22)
                    signal_pixel = {1'b1, BLACK};
                if (sx >= 3 && sx < 8) begin
                    if (sy >= 3 && sy < 8)
                        signal_pixel = {1'b1, (go ? DIM_RED : CORAL)};
                    if (sy >= 9 && sy < 14)
                        signal_pixel = {1'b1, DIM_YELLOW};
                    if (sy >= 15 && sy < 20)
                        signal_pixel = {1'b1, (go ? GREEN : DIM_GREEN)};
                end
            end
        end
    endfunction

    // An arrow is drawn in road coordinates, so it follows the same
    // diagonal projection as the lanes. Forward points into the junction;
    // right_side increases toward the driver's right.
    function lane_arrow_pixel;
        input signed [11:0] forward, right_side;
        input left_only;
        reg signed [11:0] abs_right, bend_distance;
        begin
            lane_arrow_pixel = 1'b0;
            abs_right = (right_side < 0) ? -right_side : right_side;
            bend_distance = (forward < 2) ? 2-forward : forward-2;

            if (left_only) begin
                // Stem, left bend, and left-facing arrowhead.
                if ((abs_right <= 1 && forward >= -16 && forward <= 3) ||
                    (forward >= 1 && forward <= 3 &&
                     right_side >= -10 && right_side <= 0) ||
                    (right_side >= -10 && right_side <= -4 &&
                     bend_distance <= right_side+10))
                    lane_arrow_pixel = 1'b1;
            end
            else begin
                // Straight stem and arrowhead, with a right-turn branch.
                if ((abs_right <= 1 && forward >= -16 && forward <= 15) ||
                    (forward >= 9 && forward <= 17 &&
                     abs_right <= 17-forward) ||
                    (forward >= 1 && forward <= 3 &&
                     right_side >= 0 && right_side <= 10) ||
                    (right_side >= 4 && right_side <= 10 &&
                     bend_distance <= 10-right_side))
                    lane_arrow_pixel = 1'b1;
            end
        end
    endfunction

    // A small standing pedestrian. The same silhouette is used beside
    // each crossing and, in red, inside the pedestrian timer cards.
    function [4:0] pedestrian_pixel;
        input [9:0] px, py;
        input integer left, top;
        input [3:0] color;
        reg signed [10:0] sx, sy;
        begin
            pedestrian_pixel = 5'd0;
            sx = $signed({2'b00,px})-left;
            sy = $signed({2'b00,py})-top;
            if ((sx >= 2 && sx <= 4 && sy >= 0 && sy <= 2) ||
                (sx >= 2 && sx <= 4 && sy >= 4 && sy <= 8) ||
                (sx >= 0 && sx <= 6 && sy >= 4 && sy <= 5) ||
                (sx >= 1 && sx <= 2 && sy >= 8 && sy <= 12) ||
                (sx >= 4 && sx <= 5 && sy >= 8 && sy <= 12))
                pedestrian_pixel = {1'b1, color};
        end
    endfunction

    // Static timer display card: direction, red pedestrian, two digits.
    // Digit arguments are ASCII characters, ready to be replaced by
    // controller/CPU-provided values in a later integration step.
    function [4:0] pedestrian_timer_pixel;
        input [8:0] px, py;
        input integer left, top;
        input [7:0] direction, tens, ones;
        reg signed [10:0] sx, sy;
        reg [4:0] person;
        begin
            pedestrian_timer_pixel = 5'd0;
            sx = $signed({2'b00,px})-left;
            sy = $signed({2'b00,py})-top;
            person = 5'd0;
            if (sx >= 0 && sx < 30 && sy >= 0 && sy < 29) begin
                pedestrian_timer_pixel = {1'b1, GRAY};
                if (sx >= 1 && sx < 29 && sy >= 1 && sy < 28)
                    pedestrian_timer_pixel = {1'b1, BLACK};
                if (text_pixel(px,py,left+3,top+4,1,direction))
                    pedestrian_timer_pixel = {1'b1, WHITE};
                person = pedestrian_pixel(px,py,left+19,top+3,CORAL);
                if (person[4]) pedestrian_timer_pixel = person;
                if (text_pixel(px,py,left+9,top+18,1,tens) ||
                    text_pixel(px,py,left+15,top+18,1,ones))
                    pedestrian_timer_pixel = {1'b1, YELLOW};
            end
        end
    endfunction

    wire [8:0] x = pixel_x[9:1];
    wire [8:0] y = pixel_y[9:1];
    reg signed [11:0] dx, dy, u, v;
    reg [11:0] abs_u, abs_v;
    reg [3:0] ink;
    reg [4:0] overlay;
    reg [23:0] rgb;

    // Layer order: black -> road -> markings -> cars -> signals -> UI.
    // Every value is assigned on every path: this is only pixel drawing.
    always @(*) begin
        // Only the right scene changes scale. x/y below remain unchanged
        // for the menu and readable timer-card text.
        dx = $signed({2'b00,pixel_x})-CENTER_X;
        dy = $signed({2'b00,pixel_y})-CENTER_Y;

        // Two diagonal coordinate tests give the 2:1 isometric roads.
        // Only additions/shifts/comparisons are needed for the road.
        u = (dy <<< 1) - dx;
        v = (dy <<< 1) + dx;
        abs_u = (u < 0) ? -u : u;
        abs_v = (v < 0) ? -v : v;
        ink = BLACK;
        overlay = 5'd0;

        if (x > MENU_EDGE+1) begin
            // Draw the union of the roads so no border crosses the center.
            if (abs_u <= ROAD_HALF+3 || abs_v <= ROAD_HALF+3)
                ink = WHITE;
            if (abs_u <= ROAD_HALF || abs_v <= ROAD_HALF)
                ink = ASPHALT;

            // Four lanes total on each road: two in each direction.
            // Double yellow lines separate opposing traffic.
            if ((abs_u >= 1 && abs_u <= 2 && abs_v >= 114) ||
                (abs_v >= 1 && abs_v <= 2 && abs_u >= 114))
                ink = YELLOW;

            // White dashed lines split each direction into two lanes.
            if (((abs_u >= 29 && abs_u <= 31 && abs_v >= 114) ||
                 (abs_v >= 29 && abs_v <= 31 && abs_u >= 114)) &&
                ((pixel_x & 15) < 8))
                ink = WHITE;

            // Four full-width zebra crossings, outside the junction.
            if ((abs_u <= 56 && abs_v >= 84 && abs_v <= 100 &&
                 ((u+56) & 15) < 8) ||
                (abs_v <= 56 && abs_u >= 84 && abs_u <= 100 &&
                 ((v+56) & 15) < 8))
                ink = WHITE;

            // Stop bars cover the incoming half of each approach only.
            if ((u >= 4 && u <= 57 && v >= -110 && v <= -107) ||
                (u >= -57 && u <= -4 && v >= 107 && v <= 110) ||
                (v >= -57 && v <= -4 && u >= -110 && u <= -107) ||
                (v >= 4 && v <= 57 && u >= 107 && u <= 110))
                ink = WHITE;

            // Inner incoming lane: LEFT ONLY.
            // Outer incoming lane: STRAIGHT OR RIGHT.
            // NW/N, SE/S, NE/E, and SW/W all follow the same rule.
            if (lane_arrow_pixel(v+132, u-15, 1'b1) ||
                lane_arrow_pixel(v+132, u-45, 1'b0) ||
                lane_arrow_pixel(132-v, -u-15, 1'b1) ||
                lane_arrow_pixel(132-v, -u-45, 1'b0) ||
                lane_arrow_pixel(u+132, -v-15, 1'b1) ||
                lane_arrow_pixel(u+132, -v-45, 1'b0) ||
                lane_arrow_pixel(132-u, v-15, 1'b1) ||
                lane_arrow_pixel(132-u, v-45, 1'b0))
                ink = WHITE;

            // Static car ground anchors. Change these numbers to place
            // cars; the sprite contains only the small car, not asphalt.
            overlay = car_pixel(pixel_x, pixel_y, NW_CAR_X, NW_CAR_Y, 2'd0, 2'd0);
            if (overlay[4]) ink = overlay[3:0];
            overlay = car_pixel(pixel_x, pixel_y, NE_CAR_X, NE_CAR_Y, 2'd1, 2'd1);
            if (overlay[4]) ink = overlay[3:0];
            overlay = car_pixel(pixel_x, pixel_y, SW_CAR_X, SW_CAR_Y, 2'd3, 2'd2);
            if (overlay[4]) ink = overlay[3:0];
            overlay = car_pixel(pixel_x, pixel_y, SE_CAR_X, SE_CAR_Y, 2'd2, 2'd0);
            if (overlay[4]) ink = overlay[3:0];

            // Opposite corners agree: NW/SE green, NE/SW red.
            overlay = signal_pixel(pixel_x, pixel_y, 360, 184, 1'b1);
            if (overlay[4]) ink = overlay[3:0];
            overlay = signal_pixel(pixel_x, pixel_y, 422, 184, 1'b0);
            if (overlay[4]) ink = overlay[3:0];
            overlay = signal_pixel(pixel_x, pixel_y, 310, 335, 1'b0);
            if (overlay[4]) ink = overlay[3:0];
            overlay = signal_pixel(pixel_x, pixel_y, 470, 335, 1'b1);
            if (overlay[4]) ink = overlay[3:0];

            // One standing pedestrian beside each crossing.
            overlay = pedestrian_pixel(pixel_x, pixel_y, 378, 203, WHITE);
            if (overlay[4]) ink = overlay[3:0];
            overlay = pedestrian_pixel(pixel_x, pixel_y, 408, 203, WHITE);
            if (overlay[4]) ink = overlay[3:0];
            overlay = pedestrian_pixel(pixel_x, pixel_y, 378, 285, WHITE);
            if (overlay[4]) ink = overlay[3:0];
            overlay = pedestrian_pixel(pixel_x, pixel_y, 408, 285, WHITE);
            if (overlay[4]) ink = overlay[3:0];

            // Example readouts only. This module has no timer clock.
            overlay = pedestrian_timer_pixel(x,y,133,16,"N","1","2");
            if (overlay[4]) ink = overlay[3:0];
            overlay = pedestrian_timer_pixel(x,y,235,16,"E","0","8");
            if (overlay[4]) ink = overlay[3:0];
            overlay = pedestrian_timer_pixel(x,y,112,207,"W","1","0");
            if (overlay[4]) ink = overlay[3:0];
            overlay = pedestrian_timer_pixel(x,y,250,207,"S","1","6");
            if (overlay[4]) ink = overlay[3:0];

            // Road labels use the same cardinal directions as the cards.
            if (text_pixel(x,y,101,67,1,"N") ||
                text_pixel(x,y,299,65,1,"E") ||
                text_pixel(x,y,102,191,1,"W") ||
                text_pixel(x,y,299,184,1,"S"))
                ink = GRAY;
        end

        // LEFT MENU: fixed artwork only. No control behavior is added.
        if (x < MENU_EDGE) begin
            // Header symbol and title, retained from the original scene.
            if (x >= 7 && x < 21 && y >= 10 && y < 36) begin
                ink = WHITE;
                if (x >= 8 && x < 20 && y >= 11 && y < 35)
                    ink = BLACK;
                if (x >= 10 && x < 18) begin
                    if (y >= 13 && y < 19) ink = CORAL;
                    if (y >= 21 && y < 26) ink = YELLOW;
                    if (y >= 28 && y < 33) ink = GREEN;
                end
            end

            if (text_pixel(x,y,27,13,7,"TRAFFIC") ||
                text_pixel(x,y,27,25,7,"CONTROL"))
                ink = WHITE;

            // Thin separators divide the requested control groups.
            if (x >= 7 && x < 68 &&
                (y == 94 || y == 140 || y == 188))
                ink = GRAY;

            // RUN / PAUSE / RESET rows.
            if (x >= 7 && x < 68 &&
                ((y >= 45 && y < 58) ||
                 (y >= 61 && y < 74) ||
                 (y >= 77 && y < 90)))
                ink = ASPHALT;

            // Dark key badges line up at the right of each row.
            if (x >= 47 && x < 67 &&
                ((y >= 47 && y < 56) ||
                 (y >= 63 && y < 72) ||
                 (y >= 79 && y < 88)))
                ink = BLACK;

            if (text_pixel(x,y,12,48,3,"RUN") ||
                text_pixel(x,y,12,64,5,"PAUSE") ||
                text_pixel(x,y,12,80,5,"RESET"))
                ink = WHITE;

            if (text_pixel(x,y,49,48,3,"[1]") ||
                text_pixel(x,y,49,64,3,"[2]") ||
                text_pixel(x,y,49,80,3,"[3]"))
                ink = YELLOW;

            // Vehicle directions and pedestrian directions use the same
            // four-column alignment: N, S, E, W.
            if (((x >= 7 && x < 20) ||
                 (x >= 23 && x < 36) ||
                 (x >= 39 && x < 52) ||
                 (x >= 55 && x < 68)) &&
                ((y >= 102 && y < 116) ||
                 (y >= 166 && y < 180)))
                ink = ASPHALT;

            // L / S / R subsection, centered under vehicle directions.
            if (((x >= 11 && x < 28) ||
                 (x >= 31 && x < 48) ||
                 (x >= 51 && x < 68)) &&
                y >= 121 && y < 135)
                ink = ASPHALT;

            if (text_pixel(x,y,11,105,1,"N") ||
                text_pixel(x,y,27,105,1,"S") ||
                text_pixel(x,y,43,105,1,"E") ||
                text_pixel(x,y,59,105,1,"W") ||
                text_pixel(x,y,17,124,1,"L") ||
                text_pixel(x,y,37,124,1,"S") ||
                text_pixel(x,y,57,124,1,"R"))
                ink = WHITE;

            // A compact heading fits PEDESTRIAN [P] on one line.
            if (compact_text_pixel(x,y,9,151,14,"PEDESTRIAN [P]"))
                ink = MINT;

            if (text_pixel(x,y,11,169,1,"N") ||
                text_pixel(x,y,27,169,1,"S") ||
                text_pixel(x,y,43,169,1,"E") ||
                text_pixel(x,y,59,169,1,"W"))
                ink = WHITE;

            // Emergency heading uses two lines to keep the menu width.
            if (text_pixel(x,y,11,197,9,"EMERGENCY") ||
                text_pixel(x,y,14,207,8,"SERVICES"))
                ink = CORAL;

            // Emergency selections, in the requested A / F / C / B order.
            if (((x >= 7 && x < 20) ||
                 (x >= 23 && x < 36) ||
                 (x >= 39 && x < 52) ||
                 (x >= 55 && x < 68)) &&
                y >= 222 && y < 236)
                ink = ASPHALT;

            if (text_pixel(x,y,11,225,1,"A") ||
                text_pixel(x,y,27,225,1,"F") ||
                text_pixel(x,y,43,225,1,"C") ||
                text_pixel(x,y,59,225,1,"B"))
                ink = WHITE;
        end

        // One thin vertical divider; no surrounding dashboard boxes.
        if (x == MENU_EDGE) ink = GRAY;

        rgb = palette(ink);
        // Blanking has final priority, including unused coordinate space.
        if (!visible || pixel_x >= 640 || pixel_y >= 480)
            rgb = 24'h000000;
    end

    assign red   = rgb[23:16];
    assign green = rgb[15:8];
    assign blue  = rgb[7:0];
endmodule
