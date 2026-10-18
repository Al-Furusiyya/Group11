module bram
#(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 10
)
(
    input wire [DATA_WIDTH-1:0] data_a,
    input wire [DATA_WIDTH-1:0] data_b,

    input wire [ADDR_WIDTH-1:0] addr_a,
    input wire [ADDR_WIDTH-1:0] addr_b,

    input wire we_a,
    input wire we_b,
    input wire clk,

    output reg [DATA_WIDTH-1:0] q_a,
    output reg [DATA_WIDTH-1:0] q_b
);

    // True dual-port memory array
    reg [DATA_WIDTH-1:0] ram [0:(2**ADDR_WIDTH)-1];

    // Load the CPU program and data.
    initial begin
        $readmemh("memory_init.hex", ram);
    end

    // Port A
    always @(posedge clk) begin
        if (we_a) begin
            ram[addr_a] <= data_a;
            q_a <= data_a;
        end
        else begin
            q_a <= ram[addr_a];
        end
    end

    // Port B
    always @(posedge clk) begin
        if (we_b) begin
            ram[addr_b] <= data_b;
            q_b <= data_b;
        end
        else begin
            q_b <= ram[addr_b];
        end
    end

endmodule