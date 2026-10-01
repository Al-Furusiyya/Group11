// True dual-port block RAM
// 1024 words, 16 bits per word
// Both ports use the same clock

module bram
#(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 10
)
(
    input clk,

    // Port A
    input en_a,
    input we_a,
    input[ADDR_WIDTH-1:0] addr_a,
    input[DATA_WIDTH-1:0] data_a,
    output reg [DATA_WIDTH-1:0] q_a,

    // Port B
    input en_b,
    input we_b,
    input[ADDR_WIDTH-1:0] addr_b,
    input[DATA_WIDTH-1:0] data_b,
    output reg [DATA_WIDTH-1:0] q_b
);

    // 1024 memory locations, each 16 bits wide
    reg [DATA_WIDTH-1:0] ram [0:(2**ADDR_WIDTH)-1];

    // Load the initial memory values
    initial begin
        $readmemh("memory_init.hex", ram);
    end

    // Port A
    always @(posedge clk) begin
        if (en_a) begin
            if (we_a) begin
                ram[addr_a] <= data_a;
                q_a <= data_a;
            end
            else begin
                q_a <= ram[addr_a];
            end
        end
    end

    // Port B
    always @(posedge clk) begin
        if (en_b) begin
            if (we_b) begin
                ram[addr_b] <= data_b;
                q_b <= data_b;
            end
            else begin
                q_b <= ram[addr_b];
            end
        end
    end

endmodule