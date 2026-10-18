module ProgramCounter (
    input wire clk,
    input wire reset,
    input wire enable,
    output reg [9:0] pc
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 10'd0;
        end
        else if (enable) begin
            pc <= pc + 10'd1;
        end
    end

endmodule