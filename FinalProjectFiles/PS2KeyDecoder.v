// Decode ordinary scan-code-set-2 key presses.
// A held key generates only one event until it is released.
// Extended keys and the special Pause-key sequence are intentionally ignored.
// The project's PAUSE command will use the ordinary number key 2.
module PS2KeyDecoder #(
    parameter integer TIMEOUT_CYCLES = 100000
) (
    input wire clk,
    input wire reset,
    input wire [7:0] scan_code,
    input wire scan_valid,
    input wire frame_error,
    output reg [7:0] key_code,
    output reg key_pressed
);

    reg break_pending;
    reg extended_pending;
    reg [3:0] pause_bytes_left;
    reg [16:0] prefix_timeout;
    reg [255:0] key_down;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            key_code <= 8'd0;
            key_pressed <= 1'b0;
            break_pending <= 1'b0;
            extended_pending <= 1'b0;
            pause_bytes_left <= 4'd0;
            prefix_timeout <= 17'd0;
            key_down <= 256'd0;
        end
        else begin
            key_pressed <= 1'b0;

            if (frame_error) begin
                // Recover from corrupted or incomplete input.
                break_pending <= 1'b0;
                extended_pending <= 1'b0;
                pause_bytes_left <= 4'd0;
                prefix_timeout <= 17'd0;
                key_down <= 256'd0;
            end
            else if (scan_valid) begin
                prefix_timeout <= 17'd0;

                if (pause_bytes_left != 0) begin
                    pause_bytes_left <= pause_bytes_left - 4'd1;
                end
                else if (scan_code == 8'hE1) begin
                    // Physical Pause key: E1 14 77 E1 F0 14 F0 77.
                    pause_bytes_left <= 4'd7;
                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                end
                else if (scan_code == 8'hE0) begin
                    extended_pending <= 1'b1;
                end
                else if (scan_code == 8'hF0) begin
                    break_pending <= 1'b1;
                end
                else if (scan_code == 8'hAA ||
                         scan_code == 8'h00 || scan_code == 8'hFF) begin
                    // Keyboard self-test completion or keyboard error.
                    key_down <= 256'd0;
                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                end
                else if (scan_code == 8'hFA || scan_code == 8'hFE) begin
                    // ACK and RESEND are protocol bytes, not key presses.
                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                end
                else begin
                    if (!extended_pending) begin
                        if (break_pending) begin
                            key_down[scan_code] <= 1'b0;
                        end
                        else if (!key_down[scan_code]) begin
                            key_down[scan_code] <= 1'b1;
                            key_code <= scan_code;
                            key_pressed <= 1'b1;
                        end
                    end

                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                end
            end
            else if (break_pending || extended_pending || pause_bytes_left != 0) begin
                if (prefix_timeout == TIMEOUT_CYCLES - 1) begin
                    // Do not let a missing prefix continuation poison
                    // a later, unrelated key press.
                    break_pending <= 1'b0;
                    extended_pending <= 1'b0;
                    pause_bytes_left <= 4'd0;
                    prefix_timeout <= 17'd0;
                end
                else begin
                    prefix_timeout <= prefix_timeout + 17'd1;
                end
            end
            else begin
                prefix_timeout <= 17'd0;
            end
        end
    end
endmodule
