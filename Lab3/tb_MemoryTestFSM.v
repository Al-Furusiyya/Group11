`timescale 1ns / 1ps

module tb_MemoryTestFSM;
reg clk;
reg reset;

wire [15:0] original_data;
wire [15:0] updated_data;
wire error;
wire done;
wire [2:0] state_debug;
wire [1:0] group_debug;

integer error_count;

MemoryTestFSM dut (
.clk(clk),
.reset(reset),
.original_data(original_data),
.updated_data(updated_data),
.error(error),
.done(done),
.state_debug(state_debug),
.group_debug(group_debug)
);
    // 10 ns clock period
always #5 clk = ~clk;

initial begin
clk = 1'b0;
reset = 1'b1;
error_count = 0;

// Hold reset for two clock cycles
repeat (2) @(posedge clk);
@(negedge clk);
reset = 1'b0;

// Allow enough time for all four address groups
repeat (20)@(posedge clk);
#1;

// Check that the FSM finished
if (done == 1'b1)
$display("PASS TEST 1: FSM reached the DONE state.");
else begin
$display("FAIL TEST 1: FSM did not reach the DONE state.");
error_count = error_count + 1;
    end

// Check the FSM error output
if (error ==1'b0)
$display("PASS TEST 2: FSM verified every memory write.");
else begin
$display("FAIL TEST 2: FSM detected a memory error.");
            error_count = error_count + 1;
end

// Check the displayed value from address 513
if (original_data ==16'h5201)
$display("PASS TEST 3: Original address 513 value was 5201.");
else begin
$display("FAIL TEST 3: Original value was %h, expected 5201.",
original_data);
error_count = error_count + 1;
end

if (updated_data ==16'h5202)
       $display("PASS TEST 4: Updated address 513 value is 5202.");
else begin
$display("FAIL TEST 4: Updated value was %h, expected 5202.",
updated_data);
error_count = error_count + 1;
end

// Check all seven modified memory locations
if (dut.memory.ram[0] == 16'h1001)
$display("PASS TEST 5: Address 0 updated correctly.");
else begin
$display("FAIL TEST 5: Address 0 contains %h.",
dut.memory.ram[0]);
error_count= error_count +1;
end

if (dut.memory.ram[1] ==16'h1002)
$display("PASS TEST 6: Address 1 updated correctly.");
else begin
$display("FAIL TEST 6: Address 1 contains %h.",
dut.memory.ram[1]);
error_count = error_count + 1;
end

if (dut.memory.ram[2] == 16'h1003)
$display("PASS TEST 7: Address 2 updated correctly.");
else begin
     $display("FAIL TEST 7: Address 2 contains %h.",
     dut.memory.ram[2]);
error_count = error_count +1;
end

if (dut.memory.ram[510] == 16'h51FF)
$display("PASS TEST 8: Address 510 updated correctly.");
        else begin
    $display("FAIL TEST 8: Address 510 contains %h.",
 dut.memory.ram[510]);
  error_count = error_count + 1;
end

if (dut.memory.ram[511] == 16'h5200)
$display("PASS TEST 9: Address 511 updated correctly.");
else begin
 $display("FAIL TEST 9: Address 511 contains %h.",
 dut.memory.ram[511]);
error_count = error_count + 1;
    
end
    

if (dut.memory.ram[512]== 16'h5201)
$display("PASS TEST 10: Address 512 updated correctly.");
else begin
$display("FAIL TEST 10: Address 512 contains %h.",
dut.memory.ram[512]);
error_count = error_count + 1;
end

if (dut.memory.ram[513] == 16'h5202)
$display("PASS TEST 11: Address 513 updated correctly.");
else begin
$display("FAIL TEST 11: Address 513 contains %h.",
  dut.memory.ram[513]);
error_count =error_count + 1;
end

if (error_count == 0) begin
  $display("---");
  $display("SUCCESS: ALL MEMORY FSM TESTS PASSED.");
end
    
else begin
$display("-----");
$display("FAILURE: %0d MEMORY FSM TEST(S) FAILED.",
error_count);
end

$finish;
end
endmodule
