module CPU_Part1 (
input wire clk,
input wire reset,

// Board register selection
input wire [3:0] debug_register_select,
output wire [15:0] debug_register_value,

    // CPU observation outputs
    output wire [9:0] pc,
output wire [15:0] instruction,
output wire [2:0] state,

output wire [15:0] read_data_a,
    output wire [15:0] read_data_b,
output wire [15:0] alu_result,
output wire [4:0] stored_flags
);

// Memory control signals
wire instruction_memory_enable;
wire data_memory_enable;
wire data_memory_write;
wire [15:0] memory_output_a;
wire [15:0] memory_output_b;

// FSM control signals
    wire instruction_enable;
wire pc_enable;
wire execute_enable;
wire load_write_enable;
wire branch_jump_enable;

    // Decoder control signals
    wire [3:0] decoded_alu_op;
    wire decoded_use_immediate;
wire [15:0] decoded_immediate;
wire decoded_use_carry;
   wire decoded_register_write;
    wire [4:0] decoded_flag_write_enable;
wire valid_execute;
wire is_load;
    wire is_store;

    // Branch and jump decoder signals
wire is_branch;
wire is_jump;
wire [3:0] condition_code;
wire [9:0] branch_offset;

// Branch condition result
wire condition_met;

// Program counter loading signals
wire pc_load_enable;
wire [9:0] branch_target;
wire [9:0] jump_target;
wire [9:0] pc_load_value;

// Datapath signals
wire datapath_write_enable;
wire [4:0] datapath_flag_write_enable;
wire [15:0] selected_rhs;
wire [4:0] alu_flags;
wire [15:0] write_back_data;

    // Register write control
assign datapath_write_enable =(execute_enable && decoded_register_write) ||load_write_enable;

// Flags only change during an ALU execute state.
assign datapath_flag_write_enable =
execute_enable ? decoded_flag_write_enable : 5'b00000;

// A branch or jump changes the PC only when its
// condition is satisfied.
assign pc_load_enable =
branch_jump_enable && condition_met;

// The PC was already incremented during CAPTURE.
// Therefore, a branch target is:
//
// current PC + signed branch displacement
assign branch_target = pc + branch_offset;
// A jump target comes from the selected target register.
assign jump_target = read_data_b[9:0];
// Select either the branch target or register jump target.
assign pc_load_value =
is_jump ? jump_target : branch_target;

    // Program counter
ProgramCounter program_counter (
.clk(clk),
.reset(reset),
.enable(pc_enable),

    .load_enable(pc_load_enable),
.load_value(pc_load_value),

.pc(pc)
);

    // True dual-port BRAM
    bram memory (
.clk(clk),

// Port A continuously reads the instruction at the PC.
.data_a(16'h0000),
.addr_a(pc),
.we_a(1'b0),
.q_a(memory_output_a),

        // Port B reads and writes data memory.
        .data_b(read_data_a),
        .addr_b(read_data_b[9:0]),
.we_b(data_memory_write),
.q_b(memory_output_b)
);

// Instruction register
InstructionRegister instruction_register (
.clk(clk),
.reset(reset),
        .enable(instruction_enable),
.instruction_in(memory_output_a),
.instruction(instruction)
);

// Instruction decoder
    InstructionDecoder instruction_decoder (
.instruction(instruction),

.alu_op(decoded_alu_op),
.use_immediate(decoded_use_immediate),
.immediate_value(decoded_immediate),
.use_carry(decoded_use_carry),

        .register_write(decoded_register_write),
        .flag_write_enable(decoded_flag_write_enable),
        .valid_execute(valid_execute),
        .is_load(is_load),
.is_store(is_store),
.is_branch(is_branch),
.is_jump(is_jump),
.condition_code(condition_code),
        .branch_offset(branch_offset)
    );

    // Branch-condition checker
    BranchCondition branch_condition_checker (
.condition(condition_code),
.stored_flags(stored_flags),
.condition_met(condition_met)
);

// Control FSM
CPUControl control (
.clk(clk),
.reset(reset),

        .valid_execute(valid_execute),
        .is_load(is_load),
.is_store(is_store),
.is_branch(is_branch),
.is_jump(is_jump),

.instruction_memory_enable(instruction_memory_enable),
.data_memory_enable(data_memory_enable),
.data_memory_write(data_memory_write),

.instruction_enable(instruction_enable),
        .pc_enable(pc_enable),
        .execute_enable(execute_enable),
.load_write_enable(load_write_enable),
.branch_jump_enable(branch_jump_enable),
.state(state)
);

// ALU and register-file datapath
ALU_RegFile_Datapath datapath (
.clk(clk),
.reset(reset),

// Rdest for ALU operations or Rsrc for STOR.
.read_enable_a(1'b1),
.read_address_a(instruction[11:8]),
.read_data_a(read_data_a),

// Rsrc for ALU operations, Raddr for LOAD/STOR,
// or Rtarget for a jump.
.read_enable_b(1'b1),
.read_address_b(instruction[3:0]),
        .read_data_b(read_data_b),

.write_enable(datapath_write_enable),
.write_address(instruction[11:8]),
        .alu_op(decoded_alu_op),
.use_immediate(decoded_use_immediate),
.immediate_value(decoded_immediate),
.use_carry(decoded_use_carry),
.external_load(load_write_enable),
        .external_data(memory_output_b),
.flag_write_enable(datapath_flag_write_enable),

// Independent board display port
        .debug_address(debug_register_select),
.debug_data(debug_register_value),

.selected_rhs(selected_rhs),
        .alu_result(alu_result),
.alu_flags(alu_flags),
.stored_flags(stored_flags),
.write_back_data(write_back_data)
);

endmodule
