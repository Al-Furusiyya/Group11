`timescale 1ns / 1ps


// 16-register by 16-bit register file
// The register file has two combinational read ports, one clocked write port, read-enable controls, one active-high reset
// Registers R0 through R15 are all writable
 
module RegisterFile (

    input wire clk,
    input wire reset,

    // rd port A
    input wire read_enable_a,
    input wire [3:0] read_address_a,
    output wire [15:0] read_data_a,

    // rd port B
    input wire read_enable_b,
    input wire [3:0]  read_address_b,
    output wire [15:0] read_data_b,

    // Write port
    input wire write_enable,
    input wire [3:0] write_address,
    input wire [15:0] write_data
);

    /*
     * 16 regs
     *
     * registers[0] = R0
     * registers[1] = R1
     * ...
     * registers[15] represents R15
     */
    reg [15:0] registers [0:15];

    /*
     * Combinational read port A.
     *
     * If read_enable_a is 1, the selected register appears
     * on read_data_a
     *
     * If read_enable_a is 0, read_data_a is zero
     */
    assign read_data_a =
        read_enable_a
        ? registers[read_address_a]
        : 16'h0000;

    /*
     * Combinational read port B.
     */
    assign read_data_b =
        read_enable_b
        ? registers[read_address_b]
        : 16'h0000;

    /*
     * Register writes happen on the rising edge of the clock
     *
     * Reset is asynch and active high. When reset becomes
     * 1, every register is immediately cleared
     */
    always @(posedge clk or posedge reset) begin

        if (reset) begin

            registers[0]  <= 16'h0000;
            registers[1]  <= 16'h0000;
            registers[2]  <= 16'h0000;
            registers[3]  <= 16'h0000;
            registers[4]  <= 16'h0000;
            registers[5]  <= 16'h0000;
            registers[6]  <= 16'h0000;
            registers[7]  <= 16'h0000;
            registers[8]  <= 16'h0000;
            registers[9]  <= 16'h0000;
            registers[10] <= 16'h0000;
            registers[11] <= 16'h0000;
            registers[12] <= 16'h0000;
            registers[13] <= 16'h0000;
            registers[14] <= 16'h0000;
            registers[15] <= 16'h0000;

        end
        else if (write_enable) begin

            registers[write_address] <= write_data;

        end

    end

endmodule