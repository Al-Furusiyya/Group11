`timescale 1ns/1ps
// Unit tests start after PS2KeyDecoder, at its key_code/key_pressed outputs.
// The original tb_PS2Keyboard still tests serial framing and held-key filtering.
module tb_TrafficKeyMapper;
    reg clk, reset;
    reg [7:0] key_code;
    reg key_pressed, command_ack;
    wire [15:0] command_word;
    wire command_ready, command_overrun;
    wire [1:0] menu_control, menu_kind, menu_direction;
    wire [1:0] menu_turn, menu_emergency;
    wire menu_direction_valid, menu_turn_valid;
    reg visible;
    reg [9:0] pixel_x, pixel_y;
    wire [7:0] red, green, blue;
    integer test_count, error_count;
    integer direction_index, turn_index, emergency_index;
    reg [7:0] direction_code, turn_code, emergency_code;

    TrafficKeyMapper dut (
        .clk(clk), .reset(reset), .key_code(key_code),
        .key_pressed(key_pressed), .command_ack(command_ack),
        .command_word(command_word), .command_ready(command_ready),
        .command_overrun(command_overrun),
        .menu_control(menu_control), .menu_kind(menu_kind),
        .menu_direction(menu_direction),
        .menu_direction_valid(menu_direction_valid),
        .menu_turn(menu_turn), .menu_turn_valid(menu_turn_valid),
        .menu_emergency(menu_emergency)
    );

    vga_scene scene (
        .visible(visible), .pixel_x(pixel_x), .pixel_y(pixel_y),
        .test_switches(3'b000),
        .menu_control(menu_control), .menu_kind(menu_kind),
        .menu_direction(menu_direction),
        .menu_direction_valid(menu_direction_valid),
        .menu_turn(menu_turn), .menu_turn_valid(menu_turn_valid),
        .menu_emergency(menu_emergency),
        .red(red), .green(green), .blue(blue)
    );

    always #10 clk = ~clk;

    task check_result;
        input condition;
        input [639:0] message;
        begin
            test_count = test_count + 1;
            if (condition === 1'b1)
                $display("PASS TEST %0d: %0s", test_count, message);
            else begin
                error_count = error_count + 1;
                $display("FAIL TEST %0d: %0s", test_count, message);
            end
        end
    endtask

    task press_key;
        input [7:0] code;
        begin
            @(negedge clk);
            key_code = code;
            key_pressed = 1'b1;
            @(negedge clk);
            key_pressed = 1'b0;
            #1;
        end
    endtask

    task acknowledge;
        begin
            @(negedge clk);
            command_ack = 1'b1;
            @(negedge clk);
            command_ack = 1'b0;
            #1;
            check_result(!command_ready, "Acknowledgement cleared command_ready.");
        end
    endtask

    task check_command;
        input [15:0] expected;
        begin
            $display("Command expected %04h, received %04h", expected, command_word);
            check_result(command_ready && command_word == expected,
                         "Complete command has the correct type and fields.");
            acknowledge;
            check_result(command_word == expected,
                         "Stored word holds its value after acknowledgement.");
        end
    endtask

    task check_pixel;
        input [9:0] x_value, y_value;
        input [23:0] expected;
        begin
            pixel_x = x_value;
            pixel_y = y_value;
            #1;
            check_result({red,green,blue} == expected,
                         "Dashboard pixel has the expected highlight color.");
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        key_code = 8'd0;
        key_pressed = 1'b0;
        command_ack = 1'b0;
        visible = 1'b1;
        pixel_x = 10'd400;
        pixel_y = 10'd256;
        test_count = 0;
        error_count = 0;
        #35;
        reset = 1'b0;
        #1;
        check_result(!command_ready && command_word == 0 &&
                     menu_control == 0 && menu_kind == 0 && !command_overrun,
                     "Hardware reset cleared commands and selections.");

        press_key(8'h16);
        check_result(menu_control == 1, "Number 1 selected RUN.");
        check_pixel(10'd16, 10'd92, 24'h18382C);
        check_command(16'h1000);
        press_key(8'h1E);
        check_result(menu_control == 2, "Number 2 selected PAUSE.");
        check_pixel(10'd16, 10'd124, 24'h4C4420);
        check_command(16'h2000);
        press_key(8'h26);
        check_result(menu_control == 3 && menu_kind == 0, "Number 3 cleared selections.");
        check_pixel(10'd16, 10'd156, 24'h482728);
        check_command(16'h3000);

        // All four vehicle directions, with all three turns: 12 requests.
        for (direction_index = 0; direction_index < 4; direction_index = direction_index+1) begin
            case (direction_index)
                0: direction_code = 8'h31;
                1: direction_code = 8'h1B;
                2: direction_code = 8'h24;
                3: direction_code = 8'h1D;
            endcase
            for (turn_index = 0; turn_index < 3; turn_index = turn_index+1) begin
                case (turn_index)
                    0: turn_code = 8'h4B;
                    1: turn_code = 8'h1B;
                    2: turn_code = 8'h2D;
                endcase
                press_key(direction_code);
                check_result(!command_ready && menu_kind == 1 &&
                             menu_direction_valid && menu_direction == direction_index &&
                             !menu_turn_valid, "Direction waits for one turn choice.");
                check_pixel(16+32*direction_index, 10'd208, 24'h18382C);
                press_key(turn_code);
                check_result(menu_turn_valid && menu_turn == turn_index,
                             "Turn completed the selected vehicle request.");
                check_pixel(24+40*turn_index, 10'd244, 24'h18382C);
                check_command({4'h4, direction_index[1:0], turn_index[1:0], 8'd0});
            end
        end

        // P selects pedestrian mode. S here means SB, not straight.
        for (direction_index = 0; direction_index < 4; direction_index = direction_index+1) begin
            case (direction_index)
                0: direction_code = 8'h31;
                1: direction_code = 8'h1B;
                2: direction_code = 8'h24;
                3: direction_code = 8'h1D;
            endcase
            press_key(8'h4D);
            check_result(menu_kind == 2 && !menu_direction_valid && !command_ready,
                         "P waits for a pedestrian direction.");
            check_pixel(10'd18, 10'd302, 24'hE4C94C);
            press_key(direction_code);
            check_result(menu_direction_valid && menu_direction == direction_index &&
                         !menu_turn_valid, "Pedestrian request does not select a vehicle turn.");
            check_pixel(16+32*direction_index, 10'd336, 24'h18382C);
            check_command({4'h5, direction_index[1:0], 10'd0});
        end

        for (emergency_index = 0; emergency_index < 4; emergency_index = emergency_index+1) begin
            case (emergency_index)
                0: emergency_code = 8'h1C;
                1: emergency_code = 8'h2B;
                2: emergency_code = 8'h21;
                3: emergency_code = 8'h32;
            endcase
            press_key(emergency_code);
            check_result(menu_kind == 3 && menu_emergency == emergency_index,
                         "A/F/C/B selected the matching emergency input.");
            check_pixel(16+32*emergency_index, 10'd448, 24'h482728);
            check_command({4'h6, 4'd0, emergency_index[1:0], 6'd0});
        end

        press_key(8'h4B);
        press_key(8'h2D);
        press_key(8'h22); // X is not a dashboard command.
        check_result(!command_ready && menu_kind == 3 && menu_emergency == 3,
                     "L/R without a direction and unsupported X are ignored.");

        press_key(8'h31);
        press_key(8'h24);
        press_key(8'h4B);
        check_command(16'h4800);
        check_result(menu_direction == 2, "E replaced a pending N direction.");

        press_key(8'h31);
        press_key(8'h4D);
        press_key(8'h1B);
        check_command(16'h5400);
        check_result(menu_kind == 2, "P interrupted a partial vehicle selection.");

        press_key(8'h4D);
        press_key(8'h1E);
        check_command(16'h2000);
        press_key(8'h4B);
        check_result(!command_ready && menu_kind == 0,
                     "PAUSE canceled an incomplete input sequence.");

        press_key(8'h16);
        repeat (4) @(negedge clk);
        check_result(command_ready && command_word == 16'h1000,
                     "Mailbox keeps an unread command.");
        press_key(8'h1E);
        check_result(command_overrun && command_word == 16'h1000,
                     "Full mailbox reports overrun instead of overwriting.");
        press_key(8'h26);
        check_result(!command_overrun && menu_kind == 0,
                     "RESET supersedes pending input and clears overrun.");
        check_command(16'h3000);

        press_key(8'h16);
        @(negedge clk);
        command_ack = 1'b1;
        key_code = 8'h1E;
        key_pressed = 1'b1;
        @(negedge clk);
        command_ack = 1'b0;
        key_pressed = 1'b0;
        #1;
        check_command(16'h2000);

        check_pixel(10'd400, 10'd256, 24'h292B30);
        visible = 1'b0;
        check_pixel(10'd16, 10'd124, 24'h000000);
        visible = 1'b1;

        press_key(8'h31);
        #2 reset = 1'b1;
        #1;
        check_result(!command_ready && command_word == 0 && menu_kind == 0 &&
                     menu_control == 0 && !menu_direction_valid && !menu_turn_valid,
                     "Hardware reset immediately cleared a partial selection.");

        $display("--------------------------------------------");
        if (error_count == 0)
            $display("SUCCESS: ALL TRAFFIC KEY MAPPING AND GUI TESTS PASSED.");
        else
            $display("FAILURE: %0d OF %0d TESTS FAILED.", error_count, test_count);
        $finish;
    end

    initial begin
        #100000;
        $display("FAILURE: TrafficKeyMapper test timed out.");
        $finish;
    end
endmodule
