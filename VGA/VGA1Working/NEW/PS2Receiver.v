// Receive-only PS/2 interface. All logic uses the board's 50 MHz clock.
// One pulse on scan_valid means one correctly framed byte was received.
module PS2Receiver #(
    parameter integer TIMEOUT_CYCLES = 100000
) (
    input wire clk,
    input wire reset,
    input wire ps2_clk,
    input wire ps2_data,
    output reg [7:0] scan_code,
    output reg scan_valid,
    output reg frame_error
);

    reg [2:0] clock_sync;
    reg [2:0] data_sync;
    reg [7:0] clock_filter;
    reg filtered_clock;
    reg previous_clock;

    reg [10:0] frame;
    reg [3:0] bit_count;
    reg [16:0] timeout_count;

    wire falling_edge;
    assign falling_edge = previous_clock && !filtered_clock;

    // Synchronize both asynchronous wires into the 50 MHz clock domain.
    // Require eight matching clock samples to reject short clock glitches.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clock_sync <= 3'b111;
            data_sync <= 3'b111;
            clock_filter <= 8'hFF;
            filtered_clock <= 1'b1;
            previous_clock <= 1'b1;
        end
        else begin
            clock_sync <= {clock_sync[1:0], ps2_clk};
            data_sync <= {data_sync[1:0], ps2_data};
            clock_filter <= {clock_filter[6:0], clock_sync[2]};

            if (&clock_filter)
                filtered_clock <= 1'b1;
            else if (~|clock_filter)
                filtered_clock <= 1'b0;

            previous_clock <= filtered_clock;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            frame <= 11'd0;
            bit_count <= 4'd0;
            timeout_count <= 17'd0;
            scan_code <= 8'd0;
            scan_valid <= 1'b0;
            frame_error <= 1'b0;
        end
        else begin
            scan_valid <= 1'b0;
            frame_error <= 1'b0;

            if (falling_edge) begin
                timeout_count <= 17'd0;

                if (bit_count == 0) begin
                    // Start bit must be zero.
                    if (!data_sync[2]) begin
                        frame[0] <= 1'b0;
                        bit_count <= 4'd1;
                    end
                end
                else if (bit_count < 10) begin
                    // Bits 1-8 are data, LSB first. Bit 9 is parity.
                    frame[bit_count] <= data_sync[2];
                    bit_count <= bit_count + 4'd1;
                end
                else begin
                    bit_count <= 4'd0;

                    // The current bit is STOP. Data plus parity must
                    // contain an odd number of ones.
                    if (data_sync[2] && (^frame[9:1])) begin
                        scan_code <= frame[8:1];
                        scan_valid <= 1'b1;
                    end
                    else begin
                        frame_error <= 1'b1;
                    end
                end
            end
            else if (bit_count != 0) begin
                // Abandon an incomplete packet after 2 ms at 50 MHz.
                if (timeout_count == TIMEOUT_CYCLES - 1) begin
                    bit_count <= 4'd0;
                    timeout_count <= 17'd0;
                    frame_error <= 1'b1;
                end
                else begin
                    timeout_count <= timeout_count + 17'd1;
                end
            end
            else begin
                timeout_count <= 17'd0;
            end
        end
    end
endmodule
