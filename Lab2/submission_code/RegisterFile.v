`timescale 1ns / 1ps


 
module RegisterFile (

    input wire clk,
    input wire reset,

    input wire read_enable_a,
    input wire [3:0] read_address_a,
 output wire [15:0] read_data_a,

    input wire read_enable_b,
    input wire [3:0] read_address_b,
    output wire [15:0] read_data_b,

    input wire write_enable,
    input wire [3:0] write_address,
    input wire [15:0] write_data
);


    reg [15:0] registers [0:15];

    assign read_data_a =
        read_enable_a
        ? registers[read_address_a]
        : 16'h0000;


    assign read_data_b =
    read_enable_b
    ? registers[read_address_b]
       : 16'h0000;


    always @(posedge clk or posedge reset) begin

        if (reset) begin

            registers[0] <= 16'h0000;
            registers[1] <= 16'h0000;
            registers[2] <= 16'h0000;
            registers[3] <= 16'h0000;
            registers[4] <= 16'h0000;
            registers[5] <= 16'h0000;
            registers[6] <= 16'h0000;
            registers[7] <= 16'h0000;
            registers[8]<= 16'h0000;
            registers[9] <= 16'h0000;
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
