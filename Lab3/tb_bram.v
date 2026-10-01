`timescale 1ns / 1ps

module tb_bram;
reg clk;

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
    integer error_count;
reg [15:0] saved_q_a;

// Device under test
bram dut (
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

    // 10 ns clock period
always #5 clk= ~clk;
initial begin

// Initial signal values
clk = 1'b0;

en_a =1'b0;
we_a = 1'b0;
addr_a = 10'd0;
data_a = 16'h0000;

en_b = 1'b0;
we_b = 1'b0;
addr_b = 10'd0;
data_b = 16'h0000;

error_count= 0;
saved_q_a = 16'h0000;

        // Test read initialized addresses 0 and 1
@(negedge clk);
en_a = 1'b1;
we_a = 1'b0;
addr_a = 10'd0;

en_b = 1'b1;
we_b = 1'b0;
addr_b = 10'd1;

@(posedge clk);
#1;
if ((q_a == 16'h1000) && (q_b == 6'h1001))
$display("PASS TEST 1: Addresses 0 and 1 read correctly.");
else begin
$display("FAIL TEST 1: q_a=%h q_b=%h", q_a, q_b);
error_count = error_count+ 1;
end

// Test read initialized addresses 2 and 510
@(negedge clk);
addr_a =10'd2;
addr_b = 10'd510;

@(posedge clk);
#1;

if ((q_a == 16'h1002) && (q_b ==16'h51FE))
$display("PASS TEST 2: Addresses 2 and 510 read correctly.");
else begin
$display("FAIL TEST 2: q_a=%h q_b=%h", q_a, q_b);
error_count = error_count + 1;
end

// Test read across the 511 to 512 boundary
@(negedge clk);
addr_a = 10'd511;
addr_b = 10'd512;

@(posedge clk);
#1;

if ((q_a == 16'h51FF) && (q_b == 16'h5200))
$display("PASS TEST 3: Addresses 511 and 512 read correctly.");
else begin
$display("FAIL TEST 3: q_a=%h q_b=%h", q_a, q_b);
error_count = error_count + 1;
end

// Test read initialized address 513
@(negedge clk);
        en_a = 1'b0;

en_b = 1'b1;
we_b = 1'b0;
addr_b = 10'd513;

@(posedge clk);
#1;

        if (q_b == 16'h5201)
$display("PASS TEST 4: Address 513 read correctly.");
else begin
$display("FAIL TEST 4: q_b=%h", q_b);
error_count = error_count + 1;
        end

@(negedge clk);
en_a = 1'b1;
we_a = 1'b1;
addr_a = 10'd20;
data_a = 16'hABCD;

en_b = 1'b0;

@(posedge clk);
#1;

if (q_a == 16'hABCD)
$display("PASS TEST 5: Port A write-first output is correct.");
else begin
       $display("FAIL TEST 5: q_a=%h", q_a);
error_count = error_count + 1;
end
// Test read back Port A written value
@(negedge clk);
we_a = 1'b0;
        addr_a = 10'd20;

@(posedge clk);
#1;

if (q_a == 16'hABCD)
$display("PASS TEST 6: Port A read-back is correct.");
        else begin
$display("FAIL TEST 6: q_a=%h",q_a);
error_count = error_count + 1;
end
        // Test simultaneous writes to different addresses
@(negedge clk);
en_a = 1'b1;
we_a = 1'b1;
addr_a = 10'd100;
data_a = 16'h1234;

en_b = 1'b1;
we_b = 1'b1;
addr_b = 10'd900;
data_b = 16'hBEEF;

@(posedge clk);
#1;

if ((q_a == 16'h1234) && (q_b== 16'hBEEF))
$display("PASS TEST 7: Simultaneous writes completed.");
        else begin
$display("FAIL TEST 7: q_a=%h q_b=%h",q_a, q_b);
error_count = error_count + 1;
end

        // Test read back both written values
@(negedge clk);
we_a = 1'b0;
we_b = 1'b0;

@(posedge clk);
#1;

if ((q_a == 16'h1234) && (q_b == 16'hBEEF))
$display("PASS TEST 8: Both written values read correctly.");
else begin
$display("FAIL TEST 8: q_a=%h q_b=%h", q_a, q_b);
error_count = error_count + 1;
end

        // Test disabled port holds its previous output
@(negedge clk);
saved_q_a = q_a;
en_a = 1'b0;
addr_a = 10'd0;

@(posedge clk);
#1;

if (q_a == saved_q_a)
$display("PASS TEST 9: Disabled Port A held its output.");
else begin
$display("FAIL TEST 9: q_a=%h expected=%h", q_a, saved_q_a);
error_count = error_count + 1;
end

// Test port A writes while Port B reads
        @(negedge clk);
en_a =1'b1;
we_a = 1'b1;
addr_a = 10'd30;
data_a= 16'h7777;

en_b = 1'b1;
we_b = 1'b0;
addr_b =10'd2;

@(posedge clk);
#1;
if ((q_a== 16'h7777) && (q_b == 16'h1002))
$display("PASS TEST 10: Port A wrote while Port B read.");
else begin
    $display("FAIL TEST 10: q_a=%h q_b=%h", q_a, q_b);
   error_count =error_count + 1;
end

// Final result
$display("---");

if (error_count == 0)
      $display("SUCCESS: ALL TRUE DUAL-PORT RAM TESTS PASSED.");
else
$display("FAILURE: %0d RAM TESTS FAILED.",error_count);

$finish;
end
endmodule
