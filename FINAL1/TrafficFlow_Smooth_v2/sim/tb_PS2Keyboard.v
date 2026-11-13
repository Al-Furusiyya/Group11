`timescale 1ns/1ps

module tb_PS2Keyboard;
    reg clk;
    reg reset;
    reg ps2_clk;
    reg ps2_data;
    wire [7:0] scan_code;
    wire scan_valid;
    wire frame_error;
    wire [7:0] key_code;
    wire key_pressed;

    integer press_count;
    integer frame_error_count;
    integer error_count;
    integer expected_presses;
    integer saved_errors;
    integer i;
    reg [7:0] codes [0:14];

    PS2Keyboard dut (
        .clk(clk), .reset(reset),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .scan_code(scan_code), .scan_valid(scan_valid),
        .frame_error(frame_error),
        .key_code(key_code), .key_pressed(key_pressed)
    );

    always #10 clk = ~clk;

    always @(posedge clk) begin
        if (reset) begin
            press_count <= 0;
            frame_error_count <= 0;
        end
        else begin
            if (key_pressed) press_count <= press_count + 1;
            if (frame_error) frame_error_count <= frame_error_count + 1;
        end
    end

    task send_bit;
        input value;
        begin
            ps2_data = value;
            #10000;
            ps2_clk = 1'b0;
            #20000;
            ps2_clk = 1'b1;
            #10000;
        end
    endtask

    task send_frame;
        input [7:0] value;
        input bad_parity;
        input bad_stop;
        integer b;
        reg parity;
        begin
            parity = ~(^value);
            if (bad_parity) parity = ~parity;
            send_bit(1'b0);
            for (b = 0; b < 8; b = b + 1)
                send_bit(value[b]);
            send_bit(parity);
            send_bit(!bad_stop);
            ps2_data = 1'b1;
            #60000;
        end
    endtask

    task send_byte;
        input [7:0] value;
        begin
            send_frame(value, 1'b0, 1'b0);
        end
    endtask

    task release_key;
        input [7:0] value;
        begin
            send_byte(8'hF0);
            send_byte(value);
        end
    endtask

    task expect_press;
        input [7:0] value;
        begin
            expected_presses = expected_presses + 1;
            if (press_count == expected_presses && key_code === value)
                $display("PASS: key %h received once.", value);
            else begin
                $display("FAIL: expected key=%h count=%0d, got key=%h count=%0d.",
                         value, expected_presses, key_code, press_count);
                error_count = error_count + 1;
            end
        end
    endtask

    task expect_no_press;
        begin
            if (press_count != expected_presses) begin
                $display("FAIL: unexpected key event, count=%0d expected=%0d.",
                         press_count, expected_presses);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        ps2_clk = 1;
        ps2_data = 1;
        error_count = 0;
        expected_presses = 0;

        // 1, 2, 3, N, S, E, W, L, T, R, P, A, F, C, B.
        codes[0]=8'h16; codes[1]=8'h1E; codes[2]=8'h26;
        codes[3]=8'h31; codes[4]=8'h1B; codes[5]=8'h24;
        codes[6]=8'h1D; codes[7]=8'h4B; codes[8]=8'h2D;
        codes[9]=8'h4D; codes[10]=8'h1C; codes[11]=8'h2B;
        codes[12]=8'h21; codes[13]=8'h32; codes[14]=8'h2C;

        #2000;
        reset = 0;
        #2000;

        // Every required project key, including its release sequence.
        for (i=0; i<15; i=i+1) begin
            send_byte(codes[i]);
            expect_press(codes[i]);
            release_key(codes[i]);
            expect_no_press;
        end

        // A held key must not repeatedly spawn events.
        send_byte(8'h31); expect_press(8'h31);
        send_byte(8'h31); expect_no_press;
        send_byte(8'h31); expect_no_press;
        release_key(8'h31);
        send_byte(8'h31); expect_press(8'h31);

        // A second key still works while the first is held.
        send_byte(8'h1B); expect_press(8'h1B);
        release_key(8'h31); release_key(8'h1B); expect_no_press;

        // Extended arrow make/break sequences are not ordinary letters.
        send_byte(8'hE0); send_byte(8'h75); expect_no_press;
        send_byte(8'hE0); send_byte(8'hF0); send_byte(8'h75); expect_no_press;

        // Ignore the physical Pause key's complete eight-byte sequence.
        send_byte(8'hE1); send_byte(8'h14); send_byte(8'h77);
        send_byte(8'hE1); send_byte(8'hF0); send_byte(8'h14);
        send_byte(8'hF0); send_byte(8'h77); expect_no_press;
        send_byte(8'h2D); expect_press(8'h2D); release_key(8'h2D);

        // Invalid frames are rejected, and the receiver recovers.
        saved_errors = frame_error_count;
        send_frame(8'h31, 1'b1, 1'b0); expect_no_press;
        if (frame_error_count != saved_errors + 1) error_count = error_count + 1;
        send_byte(8'h31); expect_press(8'h31); release_key(8'h31);

        saved_errors = frame_error_count;
        send_frame(8'h24, 1'b0, 1'b1); expect_no_press;
        if (frame_error_count != saved_errors + 1) error_count = error_count + 1;
        send_byte(8'h24); expect_press(8'h24); release_key(8'h24);

        // An incomplete frame times out after 2 ms.
        saved_errors = frame_error_count;
        send_bit(1'b0); send_bit(1'b1);
        ps2_data = 1'b1;
        #2200000;
        expect_no_press;
        if (frame_error_count != saved_errors + 1) error_count = error_count + 1;
        send_byte(8'h4D); expect_press(8'h4D); release_key(8'h4D);

        // A missing byte after F0 must not discard an unrelated later key.
        send_byte(8'hF0);
        #2200000;
        send_byte(8'h16); expect_press(8'h16); release_key(8'h16);

        // A short clock glitch must not be mistaken for a frame.
        saved_errors = frame_error_count;
        ps2_data = 0; ps2_clk = 0;
        #20;
        ps2_clk = 1; ps2_data = 1;
        #10000;
        expect_no_press;
        if (frame_error_count != saved_errors) error_count = error_count + 1;

        // BAT/ACK are not key events.
        send_byte(8'hAA); send_byte(8'hFA); expect_no_press;

        // Reset clears both the last code and the held-key bitmap.
        send_byte(8'h31); expect_press(8'h31);
        reset = 1;
        #2000;
        reset = 0;
        expected_presses = 0;
        #2000;
        if (key_code !== 8'h00 || key_pressed !== 1'b0)
            error_count = error_count + 1;
        send_byte(8'h31); expect_press(8'h31);

        $display("--------------------------------------------");
        if (error_count == 0)
            $display("SUCCESS: ALL PS2 KEYBOARD TESTS PASSED.");
        else
            $display("FAILURE: %0d PS2 CHECKS FAILED.", error_count);
        $finish;
    end

    // Fail instead of hanging forever if the main test stalls.
    initial begin
        #100000000;
        $display("FAILURE: PS2 TESTBENCH WATCHDOG EXPIRED.");
        $finish;
    end
endmodule
