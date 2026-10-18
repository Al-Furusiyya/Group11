module InstructionDecoder (
    input wire [15:0] instruction,

    output reg [3:0] alu_op,
    output reg use_immediate,
    output reg [15:0] immediate_value,
    output reg use_carry,

    output reg register_write,
    output reg [4:0] flag_write_enable,
    output reg valid_execute,

    output reg is_load,
    output reg is_store
);

    // Operations used by ALU.v
    localparam ZEXT = 4'h0;
    localparam SEXT = 4'h1;
    localparam ADD  = 4'h2;
    localparam SUB  = 4'h3;
    localparam AND  = 4'h4;
    localparam OR   = 4'h5;
    localparam XOR  = 4'h6;
    localparam MULT = 4'h7;
    localparam LUI  = 4'h8;
    localparam LSH  = 4'h9;
    localparam ASH  = 4'hA;
    localparam PASS = 4'hB;
    localparam NOP  = 4'hF;

    always @(instruction) begin

        // Safe default values
        alu_op = NOP;
        use_immediate = 1'b0;
        immediate_value = 16'h0000;
        use_carry = 1'b0;

        register_write = 1'b0;
        flag_write_enable = 5'b00000;
        valid_execute = 1'b0;

        is_load = 1'b0;
        is_store = 1'b0;

        case (instruction[15:12])

            // Register-to-register instructions
            4'h0: begin
                case (instruction[7:4])

                    // WAIT
                    4'h0: begin
                        alu_op = NOP;
                        valid_execute = 1'b1;
                    end

                    // AND
                    4'h1: begin
                        alu_op = AND;
                        register_write = 1'b1;
                        valid_execute = 1'b1;
                    end

                    // OR
                    4'h2: begin
                        alu_op = OR;
                        register_write = 1'b1;
                        valid_execute = 1'b1;
                    end

                    // XOR
                    4'h3: begin
                        alu_op = XOR;
                        register_write = 1'b1;
                        valid_execute = 1'b1;
                    end

                    // ADD
                    4'h5: begin
                        alu_op = ADD;
                        register_write = 1'b1;
                        flag_write_enable = 5'b10010;
                        valid_execute = 1'b1;
                    end

                    // ADDU
                    4'h6: begin
                        alu_op = ADD;
                        register_write = 1'b1;
                        valid_execute = 1'b1;
                    end

                    // ADDC
                    4'h7: begin
                        alu_op = ADD;
                        use_carry = 1'b1;
                        register_write = 1'b1;
                        flag_write_enable = 5'b10010;
                        valid_execute = 1'b1;
                    end

                    // SUB
                    4'h9: begin
                        alu_op = SUB;
                        register_write = 1'b1;
                        flag_write_enable = 5'b10010;
                        valid_execute = 1'b1;
                    end

                    // SUBC
                    4'hA: begin
                        alu_op = SUB;
                        use_carry = 1'b1;
                        register_write = 1'b1;
                        flag_write_enable = 5'b10010;
                        valid_execute = 1'b1;
                    end

                    // CMP
                    4'hB: begin
                        alu_op = SUB;
                        register_write = 1'b0;
                        flag_write_enable = 5'b01101;
                        valid_execute = 1'b1;
                    end

                    // MOV
                    4'hD: begin
                        alu_op = PASS;
                        register_write = 1'b1;
                        valid_execute = 1'b1;
                    end

                    // MUL
                    4'hE: begin
                        alu_op = MULT;
                        register_write = 1'b1;
                        valid_execute = 1'b1;
                    end

                    default: begin
                        alu_op = NOP;
                    end

                endcase
            end

            // ANDI
            4'h1: begin
                alu_op = AND;
                use_immediate = 1'b1;
                immediate_value = {8'h00, instruction[7:0]};
                register_write = 1'b1;
                valid_execute = 1'b1;
            end

            // ORI
            4'h2: begin
                alu_op = OR;
                use_immediate = 1'b1;
                immediate_value = {8'h00, instruction[7:0]};
                register_write = 1'b1;
                valid_execute = 1'b1;
            end

            // XORI
            4'h3: begin
                alu_op = XOR;
                use_immediate = 1'b1;
                immediate_value = {8'h00, instruction[7:0]};
                register_write = 1'b1;
                valid_execute = 1'b1;
            end

            // Special instructions
            4'h4: begin
                case (instruction[7:4])

                    // LOAD Rdest, Raddr
                    4'h0: begin
                        is_load = 1'b1;
                    end

                    // SNXB
                    4'h2: begin
                        alu_op = SEXT;
                        register_write = 1'b1;
                        valid_execute = 1'b1;
                    end

                    // STOR Rsrc, Raddr
                    4'h4: begin
                        is_store = 1'b1;
                    end

                    // ZRXB
                    4'h6: begin
                        alu_op = ZEXT;
                        register_write = 1'b1;
                        valid_execute = 1'b1;
                    end

                    default: begin
                        alu_op = NOP;
                    end

                endcase
            end

            // ADDI
            4'h5: begin
                alu_op = ADD;
                use_immediate = 1'b1;
                immediate_value =
                    {{8{instruction[7]}}, instruction[7:0]};
                register_write = 1'b1;
                flag_write_enable = 5'b10010;
                valid_execute = 1'b1;
            end

            // ADDUI
            4'h6: begin
                alu_op = ADD;
                use_immediate = 1'b1;
                immediate_value =
                    {{8{instruction[7]}}, instruction[7:0]};
                register_write = 1'b1;
                valid_execute = 1'b1;
            end

            // ADDCI
            4'h7: begin
                alu_op = ADD;
                use_immediate = 1'b1;
                immediate_value =
                    {{8{instruction[7]}}, instruction[7:0]};
                use_carry = 1'b1;
                register_write = 1'b1;
                flag_write_enable = 5'b10010;
                valid_execute = 1'b1;
            end

            // Shift instructions
            4'h8: begin

                // Register LSH
                if (instruction[7:4] == 4'h4) begin
                    alu_op = LSH;
                    register_write = 1'b1;
                    valid_execute = 1'b1;
                end

                // Register ASHU
                else if (instruction[7:4] == 4'h6) begin
                    alu_op = ASH;
                    register_write = 1'b1;
                    valid_execute = 1'b1;
                end

                // Immediate LSHI
                else if (instruction[7:5] == 3'b000) begin
                    alu_op = LSH;
                    use_immediate = 1'b1;
                    immediate_value =
                        {{11{instruction[4]}}, instruction[4:0]};
                    register_write = 1'b1;
                    valid_execute = 1'b1;
                end

                // Immediate ASHUI
                else if (instruction[7:5] == 3'b001) begin
                    alu_op = ASH;
                    use_immediate = 1'b1;
                    immediate_value =
                        {{11{instruction[4]}}, instruction[4:0]};
                    register_write = 1'b1;
                    valid_execute = 1'b1;
                end
            end

            // SUBI
            4'h9: begin
                alu_op = SUB;
                use_immediate = 1'b1;
                immediate_value =
                    {{8{instruction[7]}}, instruction[7:0]};
                register_write = 1'b1;
                flag_write_enable = 5'b10010;
                valid_execute = 1'b1;
            end

            // SUBCI
            4'hA: begin
                alu_op = SUB;
                use_immediate = 1'b1;
                immediate_value =
                    {{8{instruction[7]}}, instruction[7:0]};
                use_carry = 1'b1;
                register_write = 1'b1;
                flag_write_enable = 5'b10010;
                valid_execute = 1'b1;
            end

            // CMPI
            4'hB: begin
                alu_op = SUB;
                use_immediate = 1'b1;
                immediate_value =
                    {{8{instruction[7]}}, instruction[7:0]};
                register_write = 1'b0;
                flag_write_enable = 5'b01101;
                valid_execute = 1'b1;
            end

            // MOVI
            4'hD: begin
                alu_op = PASS;
                use_immediate = 1'b1;
                immediate_value = {8'h00, instruction[7:0]};
                register_write = 1'b1;
                valid_execute = 1'b1;
            end

            // MULI
            4'hE: begin
                alu_op = MULT;
                use_immediate = 1'b1;
                immediate_value =
                    {{8{instruction[7]}}, instruction[7:0]};
                register_write = 1'b1;
                valid_execute = 1'b1;
            end

            // LUI
            4'hF: begin
                alu_op = LUI;
                use_immediate = 1'b1;
                immediate_value = {8'h00, instruction[7:0]};
                register_write = 1'b1;
                valid_execute = 1'b1;
            end

            default: begin
                alu_op = NOP;
            end

        endcase
    end

endmodule