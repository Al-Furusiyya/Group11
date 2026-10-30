module BranchCondition (
 input wire [3:0] condition,
 input wire [4:0] stored_flags,
 output reg condition_met
);

 // stored_flags[4] = C, Carry
// stored_flags[3] = L, Unsigned Less Than
 // stored_flags[2] = N, Signed Less Than
 // stored_flags[1] = F, Overflow
 // stored_flags[0] = Z, Zero or Equal
 always @(condition or stored_flags) begin
 condition_met = 1'b0;
  case (condition)

 // EQ: Equal
 4'h0: begin
 condition_met = stored_flags[0];
 end

  // NE: Not equal
 4'h1: begin
   condition_met = ~stored_flags[0];
  end

 // CS: Carry set
4'h2: begin
  condition_met = stored_flags[4];
   end

 // CC: Carry clear
 4'h3: begin
condition_met = ~stored_flags[4];
  end

// HI: Unsigned higher than
 4'h4: begin
   condition_met = stored_flags[3];
  end

// LS: Unsigned lower than or same
4'h5: begin
condition_met = ~stored_flags[3];
end

// GT: Signed greater than
4'h6: begin
condition_met = stored_flags[2];
end

// LE: Signed less than or equal
4'h7: begin
condition_met = ~stored_flags[2];
end

// FS: Overflow flag set
4'h8: begin
condition_met = stored_flags[1];
end

// FC: Overflow flag clear
4'h9: begin
condition_met = ~stored_flags[1];
end

// LO: Unsigned lower than
4'hA: begin
condition_met =
(~stored_flags[3]) &&
                    (~stored_flags[0]);
end

// HS: Unsigned higher than or same
4'hB: begin
condition_met =
stored_flags[3] ||
stored_flags[0];
end

// LT: Signed less than
4'hC: begin
condition_met =
(~stored_flags[2]) &&
(~stored_flags[0]);
end

// GE: Signed greater than or equal
4'hD: begin
condition_met =
stored_flags[2] ||
                    stored_flags[0];
end

// UC: Unconditional
4'hE: begin
                condition_met = 1'b1;
end

            // Never branch
4'hF: begin
condition_met = 1'b0;
end

default: begin
condition_met = 1'b0;
end
endcase
end
endmodule
