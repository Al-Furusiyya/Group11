`timescale 1ns / 1ps
module tb_FlagRegister;
reg clk;
reg reset;
    reg [4:0] new_flags;
    reg [4:0] flag_write_enable;
    wire [4:0] stored_flags;
integer errors;
FlagRegister dut (
        .clk(clk),
        .reset(reset),
        .new_flags(new_flags),
        .flag_write_enable(flag_write_enable),
        .stored_flags(stored_flags)
    );
    always #5 clk = ~clk;
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        new_flags = 5'b00000;
        flag_write_enable = 5'b00000;
        errors = 0;
        #2;
        if (stored_flags !== 5'b00000) begin

$display(
"FAIL TEST 1: Reset expected 00000, got %b.",
stored_flags
);

            errors = errors + 1;
        end
else begin
$display(
"PASS TEST 1: Reset cleared all flags."
);
        end
        reset = 1'b0;
        new_flags = 5'b10101;
        flag_write_enable = 5'b11111;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b10101) begin

            $display(
                "FAIL TEST 2: Expected 10101, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 2: Wrote all flags as 10101."
            );
        end
        new_flags = 5'b00000;
        flag_write_enable = 5'b10000;

@(posedge clk);
#1;
if (stored_flags !== 5'b00101) begin

            $display(
"FAIL TEST 3: Expected 00101, got %b.",
stored_flags
);

errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 3: Updated only the C flag."
            );
        end
        new_flags = 5'b01010;
        flag_write_enable = 5'b01010;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b01111) begin

            $display(
                "FAIL TEST 4: Expected 01111, got %b.",
                stored_flags
);
errors = errors + 1;
end
else begin
$display(
"PASS TEST 4: Updated only L and F."
);
        end
        new_flags = 5'b00000;
        flag_write_enable = 5'b00101;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b01010) begin

            $display(
"FAIL TEST 5: Expected 01010, got %b.",
stored_flags
);

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 5: Cleared only N and Z."
            );
        end
        new_flags = 5'b11111;
        flag_write_enable = 5'b00000;

        @(posedge clk);
        #1;

        if (stored_flags !== 5'b01010) begin

            $display(
                "FAIL TEST 6: Flags changed while enables were zero."
            );

            errors = errors + 1;
        end
        else begin
            $display(
"PASS TEST 6: Disabled flags kept their values."
);
end
        new_flags = 5'b10101;
        flag_write_enable = 5'b10101;

@(posedge clk);
#1;
        if (stored_flags !== 5'b11111) begin
$display(
"FAIL TEST 7: Expected 11111, got %b.",
stored_flags
);

errors = errors + 1;
end
else begin
$display(
"PASS TEST 7: Updated C, N, and Z."
);
end
        new_flags = 5'b00000;
        flag_write_enable = 5'b11111;

        #2;

        if (stored_flags !== 5'b11111) begin

            $display(
                "FAIL TEST 8A: Flags changed before the clock edge."
            );
errors = errors + 1;
end
else begin
            $display(
                "PASS TEST 8A: Flags stayed unchanged before the edge."
            );
        end

        @(posedge clk);
        #1;
if (stored_flags !== 5'b00000) begin

            $display(
"FAIL TEST 8B: Expected 00000 after edge, got %b.",
                stored_flags
            );
            errors = errors + 1;
end
else begin
            $display(
                "PASS TEST 8B: Flags changed on the rising edge."
            );
end
        new_flags = 5'b11011;
        flag_write_enable = 5'b11111;
@(posedge clk);
#1;

if (stored_flags !== 5'b11011) begin

            $display(
                "FAIL TEST 9A: Expected 11011, got %b.",
                stored_flags
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "PASS TEST 9A: Stored 11011 before reset."
            );
        end
        reset = 1'b1;
        #1;

if (stored_flags !== 5'b00000) begin
$display(
"FAIL TEST 9B: Asynchronous reset failed."
);

errors = errors + 1;
end
        else begin
            $display(
                "PASS TEST 9B: Asynchronous reset cleared flags."
            );
        end
        reset = 1'b0;
        flag_write_enable = 5'b00000;
        $display(
            "----"
        );

        if (errors == 0) begin
$display(
"ALL FLAG REGISTER TESTS PASSED."
);
end
else begin
            $display(
                "%0d FLAG REGISTER TEST(S) FAILED.",
                errors
            );
end
$finish;
end
endmodule
