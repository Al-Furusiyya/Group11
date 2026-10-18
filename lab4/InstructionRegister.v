module InstructionRegister (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [15:0] instruction_in,
    output reg [15:0] instruction
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            instruction <= 16'h0000;
        end
        else if (enable) begin
            instruction <= instruction_in;
        end
    end

endmodule