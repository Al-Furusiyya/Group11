module CPUControl (
    input wire clk,
    input wire reset,

    input wire valid_execute,
    input wire is_load,
    input wire is_store,
    input wire is_branch,
    input wire is_jump,

    output reg instruction_memory_enable,
    output reg data_memory_enable,
    output reg data_memory_write,

    output reg instruction_enable,
    output reg pc_enable,
    output reg execute_enable,
    output reg load_write_enable,
    output reg branch_jump_enable,

    output reg [2:0] state
);

    localparam FETCH        = 3'd0;
    localparam CAPTURE      = 3'd1;
    localparam DECODE       = 3'd2;
    localparam EXECUTE      = 3'd3;
    localparam LOAD_REQUEST = 3'd4;
    localparam LOAD_WRITE   = 3'd5;
    localparam STORE_WRITE  = 3'd6;
    localparam BRANCH_JUMP  = 3'd7;

    // State register and state transitions
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= FETCH;
        end
        else begin
            case (state)

                FETCH: begin
                    state <= CAPTURE;
                end

                CAPTURE: begin
                    state <= DECODE;
                end

                DECODE: begin
                    if (is_load)
                        state <= LOAD_REQUEST;
                    else if (is_store)
                        state <= STORE_WRITE;
                    else if (is_branch || is_jump)
                        state <= BRANCH_JUMP;
                    else if (valid_execute)
                        state <= EXECUTE;
                    else
                        state <= FETCH;
                end

                EXECUTE: begin
                    state <= FETCH;
                end

                LOAD_REQUEST: begin
                    state <= LOAD_WRITE;
                end

                LOAD_WRITE: begin
                    state <= FETCH;
                end

                STORE_WRITE: begin
                    state <= FETCH;
                end

                BRANCH_JUMP: begin
                    state <= FETCH;
                end

                default: begin
                    state <= FETCH;
                end

            endcase
        end
    end

    // Control outputs for each state
    always @(state) begin

        // Default values
        instruction_memory_enable = 1'b0;
        data_memory_enable = 1'b0;
        data_memory_write = 1'b0;

        instruction_enable = 1'b0;
        pc_enable = 1'b0;
        execute_enable = 1'b0;
        load_write_enable = 1'b0;
        branch_jump_enable = 1'b0;

        case (state)

            // Request the instruction from BRAM Port A.
            FETCH: begin
                instruction_memory_enable = 1'b1;
            end

            // Save the instruction and increment the PC.
            CAPTURE: begin
                instruction_enable = 1'b1;
                pc_enable = 1'b1;
            end

            // The decoder determines the next state.
            DECODE: begin
                instruction_memory_enable = 1'b0;
                data_memory_enable = 1'b0;
                data_memory_write = 1'b0;
                instruction_enable = 1'b0;
                pc_enable = 1'b0;
                execute_enable = 1'b0;
                load_write_enable = 1'b0;
                branch_jump_enable = 1'b0;
            end

            // Execute an ALU instruction.
            EXECUTE: begin
                execute_enable = 1'b1;
            end

            // Request data from BRAM Port B.
            LOAD_REQUEST: begin
                data_memory_enable = 1'b1;
                data_memory_write = 1'b0;
            end

            // Write the BRAM output into Rdest.
            LOAD_WRITE: begin
                load_write_enable = 1'b1;
            end

            // Write Rsrc into BRAM.
            STORE_WRITE: begin
                data_memory_enable = 1'b1;
                data_memory_write = 1'b1;
            end

            // Evaluate the branch or jump and update the PC.
            BRANCH_JUMP: begin
                branch_jump_enable = 1'b1;
            end

            default: begin
                instruction_memory_enable = 1'b0;
                data_memory_enable = 1'b0;
                data_memory_write = 1'b0;
                instruction_enable = 1'b0;
                pc_enable = 1'b0;
                execute_enable = 1'b0;
                load_write_enable = 1'b0;
                branch_jump_enable = 1'b0;
            end

        endcase
    end

endmodule