// Retro four-lane intersection -- graphics renderer only.
// 640 x 480 output; all art uses a 320 x 240 grid, doubled to 2 x 2 pixels.
// Light decisions live in traffic_switch_control.v. This file never reads SW.
// Pedestrian states/counts are display inputs, not a running countdown.

module vga_scene (
    input wire visible,
    input wire [9:0] pixel_x, pixel_y,
    input wire [1:0] light_ns, light_ew,
    input wire [3:0] ped_walk,
    input wire [31:0] ped_counts_bcd,
    output wire [7:0] red, green, blue
);
    localparam MENU_EDGE = 91;
    localparam CENTER_X = 208, CENTER_Y = 126;
    localparam ROAD_HALF = 48;
    localparam [1:0] LIGHT_RED = 2'd0;
    localparam [1:0] LIGHT_YELLOW = 2'd1;
    localparam [1:0] LIGHT_GREEN = 2'd2;

    // Each road has two incoming and two outgoing lanes.
    // Rotated view: N=upper-left, E=upper-right, S=lower-right, W=lower-left.
    localparam N_CAR_X = 111, N_CAR_Y = 85;
    localparam E_CAR_X = 291, E_CAR_Y = 78;
    localparam S_CAR_X = 297, S_CAR_Y = 164;
    localparam W_CAR_X = 125, W_CAR_Y = 175;

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
                8'h5B: glyph = 35'h39084210E; // [
                8'h5D: glyph = 35'h38421084E; // ]
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
                default: glyph = 35'd0;
            endcase
        end
    endfunction

    // Each character occupies a 6 x 8 cell. Strings are right-aligned
    // in this 16-character argument, as with a normal Verilog string.
    function text_pixel;
        input [8:0] px, py;
        input integer left, top, count;
        input [127:0] message;
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
                for (i=0; i<16; i=i+1) begin
                    if (i < count && tx >= i*6 && tx < i*6+5) begin
                        bits = glyph(message >> ((count-1-i)*8));
                        bit_index = 34 - ty*5 - (tx-i*6);
                        text_pixel = bits[bit_index];
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
        input [8:0] px, py;
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

    function [3:0] light_color;
        input [1:0] state;
        begin
            case (state)
                LIGHT_YELLOW: light_color = YELLOW;
                LIGHT_GREEN:  light_color = GREEN;
                default:      light_color = CORAL;
            endcase
        end
    endfunction

    function light_word_pixel;
        input [8:0] px, py;
        input integer left, top;
        input [1:0] state;
        begin
            case (state)
                LIGHT_YELLOW: light_word_pixel = text_pixel(px,py,left,top,6,"YELLOW");
                LIGHT_GREEN:  light_word_pixel = text_pixel(px,py,left,top,5,"GREEN");
                default:      light_word_pixel = text_pixel(px,py,left,top,3,"RED");
            endcase
        end
    endfunction

    function digit_pixel;
        input [8:0] px, py;
        input integer left, top;
        input [3:0] digit;
        reg signed [10:0] sx, sy;
        reg [34:0] bits;
        reg [5:0] bit_index;
        begin
            digit_pixel = 1'b0;
            sx = $signed({2'b00,px})-left;
            sy = $signed({2'b00,py})-top;
            bits = 35'd0;
            bit_index = 6'd0;
            if (sx >= 0 && sx < 5 && sy >= 0 && sy < 7) begin
                if (digit <= 9) bits = glyph(8'h30 + {4'b0000,digit});
                else bits = glyph(8'h2D);
                bit_index = 34-sy*5-sx;
                digit_pixel = bits[bit_index];
            end
        end
    endfunction

    function count_pixel;
        input [8:0] px, py;
        input integer left, top;
        input [7:0] seconds_bcd;
        begin
            count_pixel = digit_pixel(px,py,left,top,seconds_bcd[7:4]) ||
                          digit_pixel(px,py,left+6,top,seconds_bcd[3:0]);
        end
    endfunction

    function ped_word_pixel;
        input [8:0] px, py;
        input integer left, top;
        input walk;
        begin
            if (walk) ped_word_pixel = text_pixel(px,py,left,top,4,"WALK");
            else      ped_word_pixel = text_pixel(px,py,left,top,4,"WAIT");
        end
    endfunction

    // Only the selected lamp is bright. Reserved states display red.
    function [4:0] signal_pixel;
        input [8:0] px, py;
        input integer left, top;
        input [1:0] state;
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
                        signal_pixel = {1'b1, ((state == LIGHT_YELLOW || state == LIGHT_GREEN) ? DIM_RED : CORAL)};
                    if (sy >= 9 && sy < 14)
                        signal_pixel = {1'b1, ((state == LIGHT_YELLOW) ? YELLOW : DIM_YELLOW)};
                    if (sy >= 15 && sy < 20)
                        signal_pixel = {1'b1, ((state == LIGHT_GREEN) ? GREEN : DIM_GREEN)};
                end
            end
        end
    endfunction

    // Shared small pedestrian icon, also used for the four curb pedestrians.
    function [6:0] person_row;
        input [3:0] row;
        begin
            case (row)
                0,1: person_row = 7'b0011100;
                2:   person_row = 7'b0001000;
                3:   person_row = 7'b0111110;
                4,5: person_row = 7'b1011101;
                6:   person_row = 7'b0011100;
                7:   person_row = 7'b0010100;
                8,9,10: person_row = 7'b0100010;
                default: person_row = 7'd0;
            endcase
        end
    endfunction

    function person_pixel;
        input [8:0] px, py;
        input integer left, top;
        reg signed [10:0] sx, sy;
        reg [6:0] bits;
        begin
            person_pixel = 1'b0;
            sx = $signed({2'b00,px})-left;
            sy = $signed({2'b00,py})-top;
            bits = 7'd0;
            if (sx >= 0 && sx < 7 && sy >= 0 && sy < 11) begin
                bits = person_row(sy[3:0]);
                person_pixel = bits[6-sx[2:0]];
            end
        end
    endfunction

    // Direction letter + pedestrian icon + two-digit BCD timer display.
    function [4:0] ped_head_pixel;
        input [8:0] px, py;
        input integer left, top;
        input [7:0] direction_letter;
        input walk;
        input [7:0] seconds_bcd;
        reg signed [10:0] sx, sy;
        reg [127:0] direction_text;
        begin
            ped_head_pixel = 5'd0;
            sx = $signed({2'b00,px})-left;
            sy = $signed({2'b00,py})-top;
            direction_text = {120'd0,direction_letter};
            if (sx >= 0 && sx < 24 && sy >= 0 && sy < 24) begin
                ped_head_pixel = {1'b1, GRAY};
                if (sx >= 1 && sx < 23 && sy >= 1 && sy < 23)
                    ped_head_pixel = {1'b1, BLACK};
                if (text_pixel(px,py,left+3,top+3,1,direction_text))
                    ped_head_pixel = {1'b1, WHITE};
                if (person_pixel(px,py,left+13,top+2))
                    ped_head_pixel = {1'b1, (walk ? GREEN : CORAL)};
                if (count_pixel(px,py,left+6,top+15,seconds_bcd))
                    ped_head_pixel = {1'b1, YELLOW};
            end
        end
    endfunction

    // These road-plane arrows rotate with each incoming approach.
    // r is the driver's right; f is forward. The inner lane turns left.
    function lane_arrow_pixel;
        input signed [11:0] road_u, road_v;
        input [1:0] approach;
        input straight_right;
        reg signed [11:0] r, f, lateral, abs_r, abs_f, bend_distance;
        begin
            lateral = straight_right ? 12'sd36 : 12'sd14;
            case (approach)
                2'd0: begin r= road_u-lateral; f= road_v+124; end
                2'd1: begin r=-road_v-lateral; f= road_u+124; end
                2'd2: begin r=-road_u-lateral; f=-road_v+124; end
                default: begin r=road_v-lateral; f=-road_u+124; end
            endcase
            abs_r = (r < 0) ? -r : r;
            abs_f = (f < 0) ? -f : f;
            bend_distance = (f < 4) ? 4-f : f-4;
            lane_arrow_pixel = 1'b0;
            if (straight_right) begin
                if ((abs_r <= 2 && f >= -14 && f <= 10) ||
                    (f >= 9 && f <= 17 && abs_r <= 17-f) ||
                    (r >= 0 && r <= 7 && abs_f <= 2) ||
                    (r >= 4 && r <= 10 && abs_f <= 10-r))
                    lane_arrow_pixel = 1'b1;
            end
            else begin
                if ((abs_r <= 2 && f >= -14 && f <= 4) ||
                    (r >= -7 && r <= 0 && f >= 2 && f <= 6) ||
                    (r >= -10 && r <= -4 && bend_distance <= r+10))
                    lane_arrow_pixel = 1'b1;
            end
        end
    endfunction

    // A flat pixel-art control box, independent of input or menu logic.
    function [4:0] ui_box_pixel;
        input [8:0] px, py;
        input integer left, top, width, height;
        input [3:0] border_color;
        reg signed [10:0] sx, sy;
        begin
            ui_box_pixel = 5'd0;
            sx = $signed({2'b00,px})-left;
            sy = $signed({2'b00,py})-top;
            if (sx >= 0 && sx < width && sy >= 0 && sy < height) begin
                ui_box_pixel = {1'b1,border_color};
                if (sx >= 1 && sx < width-1 && sy >= 1 && sy < height-1)
                    ui_box_pixel = {1'b1,ASPHALT};
            end
        end
    endfunction

    wire [8:0] x = pixel_x[9:1];
    wire [8:0] y = pixel_y[9:1];
    wire [7:0] ped_n_bcd = ped_counts_bcd[31:24];
    wire [7:0] ped_e_bcd = ped_counts_bcd[23:16];
    wire [7:0] ped_s_bcd = ped_counts_bcd[15:8];
    wire [7:0] ped_w_bcd = ped_counts_bcd[7:0];
    reg signed [11:0] dx, dy, u, v;
    reg [11:0] abs_u, abs_v;
    reg [3:0] ink;
    reg [4:0] overlay;
    reg [23:0] rgb;

    // Background -> road markings -> sprites -> dashboard -> blanking.
    always @(*) begin
        dx = $signed({3'b000,x})-CENTER_X;
        dy = $signed({3'b000,y})-CENTER_Y;
        u = (dy <<< 1)-dx;
        v = (dy <<< 1)+dx;
        abs_u = (u < 0) ? -u : u;
        abs_v = (v < 0) ? -v : v;
        ink = BLACK;
        overlay = 5'd0;

        if (x > MENU_EDGE+1) begin
            if (abs_u <= ROAD_HALF+3 || abs_v <= ROAD_HALF+3) ink = WHITE;
            if (abs_u <= ROAD_HALF || abs_v <= ROAD_HALF) ink = ASPHALT;

            // Double yellow separates opposing traffic. Dashed white
            // separates the two lanes travelling in the same direction.
            if ((abs_u >= 2 && abs_u <= 3 && abs_v >= 88) ||
                (abs_v >= 2 && abs_v <= 3 && abs_u >= 88))
                ink = YELLOW;
            if (((abs_u >= 23 && abs_u <= 24 && abs_v >= 88) ||
                 (abs_v >= 23 && abs_v <= 24 && abs_u >= 88)) && ((x & 15) < 8))
                ink = WHITE;

            // Six full zebra stripes across each four-lane arm.
            if ((u >= -44 && u <= 43 && abs_v >= 66 && abs_v <= 82 && ((u+44) & 15) < 8) ||
                (v >= -44 && v <= 43 && abs_u >= 66 && abs_u <= 82 && ((v+44) & 15) < 8))
                ink = WHITE;

            // Stop bars cover the incoming lanes only.
            if ((u >= 4 && u <= 44 && v >= -94 && v <= -90) ||
                (u >= -44 && u <= -4 && v >= 90 && v <= 94) ||
                (v >= -44 && v <= -4 && u >= -94 && u <= -90) ||
                (v >= 4 && v <= 44 && u >= 90 && u <= 94))
                ink = WHITE;

            if (lane_arrow_pixel(u,v,2'd0,1'b0) || lane_arrow_pixel(u,v,2'd0,1'b1) ||
                lane_arrow_pixel(u,v,2'd1,1'b0) || lane_arrow_pixel(u,v,2'd1,1'b1) ||
                lane_arrow_pixel(u,v,2'd2,1'b0) || lane_arrow_pixel(u,v,2'd2,1'b1) ||
                lane_arrow_pixel(u,v,2'd3,1'b0) || lane_arrow_pixel(u,v,2'd3,1'b1))
                ink = WHITE;

            // Cars are fixed drawings, placed behind the lane arrows.
            overlay = car_pixel(x,y,N_CAR_X,N_CAR_Y,2'd0,2'd0);
            if (overlay[4]) ink = overlay[3:0];
            overlay = car_pixel(x,y,E_CAR_X,E_CAR_Y,2'd1,2'd1);
            if (overlay[4]) ink = overlay[3:0];
            overlay = car_pixel(x,y,S_CAR_X,S_CAR_Y,2'd2,2'd0);
            if (overlay[4]) ink = overlay[3:0];
            overlay = car_pixel(x,y,W_CAR_X,W_CAR_Y,2'd3,2'd2);
            if (overlay[4]) ink = overlay[3:0];

            if (person_pixel(x,y,187,86) || person_pixel(x,y,221,86) ||
                person_pixel(x,y,187,146) || person_pixel(x,y,221,146))
                ink = GLASS_LIGHT;

            overlay = signal_pixel(x,y,170,58,light_ns);
            if (overlay[4]) ink = overlay[3:0];
            overlay = signal_pixel(x,y,233,58,light_ew);
            if (overlay[4]) ink = overlay[3:0];
            overlay = signal_pixel(x,y,169,174,light_ew);
            if (overlay[4]) ink = overlay[3:0];
            overlay = signal_pixel(x,y,238,174,light_ns);
            if (overlay[4]) ink = overlay[3:0];

            overlay = ped_head_pixel(x,y,146,35,"N",ped_walk[3],ped_n_bcd);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ped_head_pixel(x,y,252,35,"E",ped_walk[2],ped_e_bcd);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ped_head_pixel(x,y,255,204,"S",ped_walk[1],ped_s_bcd);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ped_head_pixel(x,y,137,204,"W",ped_walk[0],ped_w_bcd);
            if (overlay[4]) ink = overlay[3:0];

            if (text_pixel(x,y,117,47,1,"N") || text_pixel(x,y,298,47,1,"E") ||
                text_pixel(x,y,298,199,1,"S") || text_pixel(x,y,109,199,1,"W"))
                ink = GRAY;
        end

        // Compact control center. Commands/keys are visual labels only.
        // The existing switches still feed the road lights and color bars.
        if (x < MENU_EDGE) begin
            if (text_pixel(x,y,6,8,7,"CONTROL")) ink = WHITE;
            if (x >= 75 && x < 84 && y >= 5 && y < 21) begin
                ink = GRAY;
                if (x >= 76 && x < 83 && y >= 6 && y < 20) ink = BLACK;
                if (x >= 78 && x < 81) begin
                    if (y >= 8 && y < 11) ink = CORAL;
                    if (y >= 12 && y < 15) ink = YELLOW;
                    if (y >= 16 && y < 19) ink = GREEN;
                end
            end

            // Primary commands: full-width rows with right-aligned keys.
            overlay = ui_box_pixel(x,y,5,28,81,14,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,5,45,81,14,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,5,62,81,14,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            if (x >= 6 && x < 8) begin
                if (y >= 29 && y < 41) ink = GREEN;
                if (y >= 46 && y < 58) ink = YELLOW;
                if (y >= 63 && y < 75) ink = CORAL;
            end
            if (text_pixel(x,y,12,32,3,"RUN") ||
                text_pixel(x,y,12,49,5,"PAUSE") ||
                text_pixel(x,y,12,66,5,"RESET")) ink = WHITE;
            if (text_pixel(x,y,65,32,3,"[1]")) ink = GREEN;
            if (text_pixel(x,y,65,49,3,"[2]")) ink = YELLOW;
            if (text_pixel(x,y,65,66,3,"[3]")) ink = CORAL;

            if (x >= 5 && x < 86 && (y == 81 || y == 144 || y == 195)) ink = GRAY;
            if (text_pixel(x,y,6,87,8,"VEHICLES")) ink = GRAY;

            // Directions are intentionally ordered N S E W, as requested.
            overlay = ui_box_pixel(x,y,5,99,17,17,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,26,99,17,17,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,47,99,17,17,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,68,99,17,17,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            if (text_pixel(x,y,11,103,1,"N") || text_pixel(x,y,32,103,1,"S") ||
                text_pixel(x,y,53,103,1,"E") || text_pixel(x,y,74,103,1,"W")) ink = WHITE;
            if (y >= 112 && y < 115) begin
                if ((x >= 6 && x < 21) || (x >= 27 && x < 42)) ink = light_color(light_ns);
                if ((x >= 48 && x < 63) || (x >= 69 && x < 84)) ink = light_color(light_ew);
            end

            // Shared movement selection sits directly below the direction row.
            overlay = ui_box_pixel(x,y,16,123,17,16,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,37,123,17,16,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,58,123,17,16,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            if (text_pixel(x,y,22,127,1,"L") || text_pixel(x,y,43,127,1,"S") ||
                text_pixel(x,y,64,127,1,"R")) ink = WHITE;

            if (text_pixel(x,y,5,151,10,"PEDESTRIAN")) ink = WHITE;
            if (text_pixel(x,y,71,151,3,"[P]")) ink = YELLOW;
            overlay = ui_box_pixel(x,y,5,164,17,25,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,26,164,17,25,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,47,164,17,25,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,68,164,17,25,GRAY);
            if (overlay[4]) ink = overlay[3:0];
            if (text_pixel(x,y,11,168,1,"N")) ink = ped_walk[3] ? GREEN : CORAL;
            if (text_pixel(x,y,32,168,1,"S")) ink = ped_walk[1] ? GREEN : CORAL;
            if (text_pixel(x,y,53,168,1,"E")) ink = ped_walk[2] ? GREEN : CORAL;
            if (text_pixel(x,y,74,168,1,"W")) ink = ped_walk[0] ? GREEN : CORAL;
            if (count_pixel(x,y,8,179,ped_n_bcd) || count_pixel(x,y,29,179,ped_s_bcd) ||
                count_pixel(x,y,50,179,ped_e_bcd) || count_pixel(x,y,71,179,ped_w_bcd)) ink = YELLOW;

            // The full heading wraps to fit the existing narrow sidebar.
            if (text_pixel(x,y,18,201,9,"EMERGENCY")) ink = CORAL;
            if (text_pixel(x,y,21,211,8,"SERVICES")) ink = WHITE;
            overlay = ui_box_pixel(x,y,5,223,17,15,CORAL);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,26,223,17,15,CORAL);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,47,223,17,15,CORAL);
            if (overlay[4]) ink = overlay[3:0];
            overlay = ui_box_pixel(x,y,68,223,17,15,CORAL);
            if (overlay[4]) ink = overlay[3:0];
            if (text_pixel(x,y,11,227,1,"A") || text_pixel(x,y,32,227,1,"F") ||
                text_pixel(x,y,53,227,1,"C") || text_pixel(x,y,74,227,1,"B")) ink = WHITE;
        end
        if (x == MENU_EDGE) ink = GRAY;
        rgb = palette(ink);
        if (!visible || pixel_x >= 640 || pixel_y >= 480) rgb = 24'h000000;
    end
    assign red = rgb[23:16];
    assign green = rgb[15:8];
    assign blue = rgb[7:0];
endmodule
