// Manual display-test control only. No traffic sequence or timers.
// SW[0]: 0=N/S selected, 1=E/W selected.
// SW[1]: 0=green, 1=yellow for the selected pair.
// SW[3]: enable selected pair; 0 makes every lamp red.
// SW[2] is unused. Opposing pairs are never green together.
module traffic_switch_control (
    input wire [3:0] switches,
    output reg [1:0] light_ns,
    output reg [1:0] light_ew
);
    localparam [1:0] RED = 2'd0;
    localparam [1:0] YELLOW = 2'd1;
    localparam [1:0] GREEN = 2'd2;
    always @(*) begin
        light_ns = RED;
        light_ew = RED;
        if (switches[3]) begin
            if (switches[0]) light_ew = switches[1] ? YELLOW : GREEN;
            else             light_ns = switches[1] ? YELLOW : GREEN;
        end
    end
endmodule
