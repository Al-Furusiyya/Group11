 module ProgramCounter (
input wire clk,
input wire reset,
// Normal sequential execution
input wire enable,
// Branch or jump execution
input wire load_enable,
    input wire [9:0] load_value,

output reg [9:0] pc
);

always @(posedge clk or posedge reset) begin
if (reset) begin
pc <= 10'd0;
end
else if (load_enable) begin
            pc <= load_value;
end
else if (enable) begin
pc <= pc + 10'd1;
end
end
endmodule
