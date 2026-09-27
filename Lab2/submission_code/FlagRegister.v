`timescale 1ns / 1ps

/*
 *
 *     stored_flags[4] = C, Carry
 *     stored_flags[3] = L, Unsigned Less Than
 *     stored_flags[2] = N, Signed Less Than
 *     stored_flags[1] = F, Overflow
 *     stored_flags[0] = Z, Zero or Equal
 *

 */
module FlagRegister (

    input wire clk,
    input wire reset,

    input wire [4:0] new_flags,

    input wire [4:0] flag_write_enable,

    output reg [4:0] stored_flags
);

    
    always @(posedge clk or posedge reset) begin

        if (reset) begin

            stored_flags <= 5'b00000;

        end
        else begin

            if (flag_write_enable[4] == 1'b1)
                stored_flags[4] <= new_flags[4];

            if (flag_write_enable[3] == 1'b1)
                stored_flags[3] <= new_flags[3];

            if (flag_write_enable[2] == 1'b1)
                stored_flags[2] <= new_flags[2];

            if (flag_write_enable[1] == 1'b1)
                stored_flags[1] <= new_flags[1];

            if (flag_write_enable[0] == 1'b1)
                stored_flags[0] <= new_flags[0];

        end

    end

endmodule
