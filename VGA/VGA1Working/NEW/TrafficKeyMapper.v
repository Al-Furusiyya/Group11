// Turn ordinary PS/2 make events into dashboard commands.
// Vehicle: direction, then L/S/R. Pedestrian: P, then direction.
// Press and release between repeated letters: S then S is SB straight.
// This module does not move cars or decide traffic-light phases.
module TrafficKeyMapper (
    input wire clk,
    input wire reset,
    input wire [7:0] key_code,
    input wire key_pressed,
    input wire command_ack,
    output reg [15:0] command_word,
    output reg command_ready,
    output reg command_overrun,
    output reg [1:0] menu_control,
    output reg [1:0] menu_kind,
    output reg [1:0] menu_direction,
    output reg menu_direction_valid,
    output reg [1:0] menu_turn,
    output reg menu_turn_valid,
    output reg [1:0] menu_emergency
);
    localparam IDLE = 2'd0;
    localparam WAIT_TURN = 2'd1;
    localparam WAIT_PEDESTRIAN_DIRECTION = 2'd2;

    localparam [7:0] KEY_1 = 8'h16, KEY_2 = 8'h1E, KEY_3 = 8'h26;
    localparam [7:0] KEY_N = 8'h31, KEY_S = 8'h1B;
    localparam [7:0] KEY_E = 8'h24, KEY_W = 8'h1D;
    localparam [7:0] KEY_L = 8'h4B, KEY_R = 8'h2D, KEY_P = 8'h4D;
    localparam [7:0] KEY_A = 8'h1C, KEY_F = 8'h2B;
    localparam [7:0] KEY_C = 8'h21, KEY_B = 8'h32;

    reg [1:0] input_mode;
    reg direction_key, turn_key, emergency_key;
    reg [1:0] direction_value, turn_value, emergency_value;
    reg new_command;
    reg [15:0] new_word;

    // Direction: NB=0, SB=1, EB=2, WB=3.
    // Turn: L=0, S=1, R=2. Emergency: A=0, F=1, C=2, B=3.
    always @(*) begin
        direction_key = 1'b0;
        turn_key = 1'b0;
        emergency_key = 1'b0;
        direction_value = 2'd0;
        turn_value = 2'd0;
        emergency_value = 2'd0;
        case (key_code)
            KEY_N: begin direction_key = 1'b1; direction_value = 2'd0; end
            KEY_S: begin
                direction_key = 1'b1; direction_value = 2'd1;
                turn_key = 1'b1; turn_value = 2'd1;
            end
            KEY_E: begin direction_key = 1'b1; direction_value = 2'd2; end
            KEY_W: begin direction_key = 1'b1; direction_value = 2'd3; end
            KEY_L: begin turn_key = 1'b1; turn_value = 2'd0; end
            KEY_R: begin turn_key = 1'b1; turn_value = 2'd2; end
            KEY_A: begin emergency_key = 1'b1; emergency_value = 2'd0; end
            KEY_F: begin emergency_key = 1'b1; emergency_value = 2'd1; end
            KEY_C: begin emergency_key = 1'b1; emergency_value = 2'd2; end
            KEY_B: begin emergency_key = 1'b1; emergency_value = 2'd3; end
            default: begin end
        endcase
    end

    // One complete command fits in a future 16-bit CPU input register.
    // [15:12] type: 1 RUN, 2 PAUSE, 3 RESET, 4 VEHICLE, 5 PED, 6 EMERGENCY.
    // [11:10] direction, [9:8] turn, [7:6] emergency, [5:0] zero.
    // Fields not used by a command are zero, not additional selections.
    always @(*) begin
        new_command = 1'b0;
        new_word = 16'd0;
        if (key_pressed) begin
            if (key_code == KEY_1) begin
                new_command = 1'b1; new_word = 16'h1000;
            end
            else if (key_code == KEY_2) begin
                new_command = 1'b1; new_word = 16'h2000;
            end
            else if (key_code == KEY_3) begin
                new_command = 1'b1; new_word = 16'h3000;
            end
            else if (emergency_key) begin
                new_command = 1'b1;
                new_word = {4'h6, 2'd0, 2'd0, emergency_value, 6'd0};
            end
            else if (input_mode == WAIT_PEDESTRIAN_DIRECTION && direction_key) begin
                new_command = 1'b1;
                new_word = {4'h5, direction_value, 2'd0, 2'd0, 6'd0};
            end
            else if (input_mode == WAIT_TURN && turn_key) begin
                new_command = 1'b1;
                new_word = {4'h4, menu_direction, turn_value, 2'd0, 6'd0};
            end
        end
    end

    // Input selection and dashboard feedback. These show requested inputs,
    // not confirmation that the CPU is running or serving a traffic request.
    // menu_control: 0 none, 1 RUN, 2 PAUSE, 3 RESET.
    // menu_kind: 0 none, 1 vehicle, 2 pedestrian, 3 emergency.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            input_mode <= IDLE;
            menu_control <= 2'd0;
            menu_kind <= 2'd0;
            menu_direction <= 2'd0;
            menu_direction_valid <= 1'b0;
            menu_turn <= 2'd0;
            menu_turn_valid <= 1'b0;
            menu_emergency <= 2'd0;
        end
        else if (key_pressed) begin
            if (key_code == KEY_1 || key_code == KEY_2 || key_code == KEY_3) begin
                input_mode <= IDLE;
                menu_kind <= 2'd0;
                menu_direction <= 2'd0;
                menu_direction_valid <= 1'b0;
                menu_turn <= 2'd0;
                menu_turn_valid <= 1'b0;
                menu_emergency <= 2'd0;
                if (key_code == KEY_1) menu_control <= 2'd1;
                else if (key_code == KEY_2) menu_control <= 2'd2;
                else menu_control <= 2'd3;
            end
            else if (key_code == KEY_P) begin
                input_mode <= WAIT_PEDESTRIAN_DIRECTION;
                menu_kind <= 2'd2;
                menu_direction_valid <= 1'b0;
                menu_turn_valid <= 1'b0;
            end
            else if (emergency_key) begin
                input_mode <= IDLE;
                menu_kind <= 2'd3;
                menu_emergency <= emergency_value;
                menu_direction_valid <= 1'b0;
                menu_turn_valid <= 1'b0;
            end
            else if (input_mode == WAIT_PEDESTRIAN_DIRECTION) begin
                if (direction_key) begin
                    input_mode <= IDLE;
                    menu_direction <= direction_value;
                    menu_direction_valid <= 1'b1;
                end
            end
            else if (input_mode == WAIT_TURN && turn_key) begin
                input_mode <= IDLE;
                menu_turn <= turn_value;
                menu_turn_valid <= 1'b1;
            end
            else if (direction_key) begin
                input_mode <= WAIT_TURN;
                menu_kind <= 2'd1;
                menu_direction <= direction_value;
                menu_direction_valid <= 1'b1;
                menu_turn_valid <= 1'b0;
            end
        end
    end

    // Keep a complete command until acknowledged. Do not silently overwrite
    // unread commands. RESET is allowed to replace an older pending command.
    // This is a one-command mailbox, not a queue of multiple requests.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            command_word <= 16'd0;
            command_ready <= 1'b0;
            command_overrun <= 1'b0;
        end
        else begin
            if (command_ack) command_ready <= 1'b0;
            if (new_command) begin
                if (!command_ready || command_ack || new_word == 16'h3000) begin
                    command_word <= new_word;
                    command_ready <= 1'b1;
                    if (new_word == 16'h3000) command_overrun <= 1'b0;
                end
                else begin
                    command_overrun <= 1'b1;
                end
            end
        end
    end
endmodule
