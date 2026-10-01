module MemoryTestFSM
(
input clk,
input reset,
    
output reg [15:0] original_data,
output reg [15:0] updated_data,
output reg error,
output done,
output [2:0] state_debug,
output [1:0] group_debug
);
// FSM states
localparam S_READ = 3'd0;
localparam S_CAPTURE = 3'd1;
localparam S_WRITE = 3'd2;
localparam S_VERIFY  = 3'd3;
localparam S_CHECK = 3'd4;
localparam S_DONE = 3'd5;

reg [2:0] state;
reg [1:0] group_index;

reg en_a;
reg we_a;
reg [9:0] addr_a;
reg [15:0] data_a;
wire [15:0] q_a;

reg en_b;
reg we_b;
reg [9:0] addr_b;
reg [15:0] data_b;
wire [15:0] q_b;

reg [15:0] expected_a;
reg [15:0] expected_b;
reg use_port_b;

assign done = (state ==S_DONE);
assign state_debug = state;
assign group_debug =group_index;
bram memory (
.clk(clk),

.en_a(en_a),
.we_a(we_a),
.addr_a(addr_a),
.data_a(data_a),
.q_a(q_a),

.en_b(en_b),
.we_b(we_b),
.addr_b(addr_b),
.data_b(data_b),
.q_b(q_b)
    );
    // State register and verification logic
always @(posedge clk) begin
if (reset) begin

    
state <= S_READ;
group_index <= 2'd0;
expected_a <= 16'h0000;
expected_b <=16'h0000;
original_data <= 16'h0000;
updated_data <=16'h0000;
error <= 1'b0;


        end
    
        else begin
            
case (state)

S_READ: begin
state <= S_CAPTURE;
end

S_CAPTURE: begin
expected_a <= q_a +16'h0001;
if (use_port_b)
expected_b <= q_b+16'h0001;
if (group_index ==2'd3)
original_data <= q_a;

state <= S_WRITE;
end

S_WRITE: begin
state <= S_VERIFY;
end

S_VERIFY: begin
state <=S_CHECK;
end

S_CHECK: begin
if (q_a !=expected_a)
error <= 1'b1;

if (use_port_b && (q_b !=expected_b))
error <= 1'b1;

if (group_index ==2'd3) begin
updated_data <= q_a;
state <= S_DONE;
end
else begin
group_index <= group_index + 2'd1;
state <= S_READ;
end
end

S_DONE: begin
state <= S_DONE;
end

default: begin
state <=S_READ;
group_index <= 2'd0;
error<= 1'b1;
end

endcase
end
end

    // RAM address and control logic
always @(*) begin

en_a =1'b0;
we_a = 1'b0;
addr_a = 10'd0;
data_a = expected_a;

en_b= 1'b0;
we_b = 1'b0;
addr_b = 10'd0;
data_b= expected_b;
use_port_b = 1'b1;

// Select the address pair
case (group_index)

2'd0: begin
addr_a = 10'd0;
addr_b = 10'd1;
end

2'd1: begin
addr_a = 10'd2;
addr_b = 10'd510;
end

2'd2: begin
addr_a =10'd511;
addr_b =  10'd512;
end

2'd3: begin
addr_a = 10'd513;
addr_b= 10'd0;
use_port_b = 1'b0;
end

default: begin
addr_a = 10'd0;
addr_b = 10'd0;
use_port_b =1'b0;
end

endcase

        // Control the RAM during each state
case (state)

S_READ: begin
en_a = 1'b1;
en_b = use_port_b;
end

S_CAPTURE: begin
en_a = 1'b0;
en_b = 1'b0;
end

S_WRITE: begin
en_a =1'b1;
we_a = 1'b1;

en_b =  use_port_b;
we_b = use_port_b;
end

S_VERIFY: begin
en_a = 1'b1;
en_b =use_port_b;
end

S_CHECK: begin
en_a =    1'b0;
en_b = 1'b0;
end

S_DONE: begin
en_a = 1'b0;
en_b= 1'b0;
end

default: begin
en_a = 1'b0;
en_b =  1'b0;
end
endcase
end

endmodule
