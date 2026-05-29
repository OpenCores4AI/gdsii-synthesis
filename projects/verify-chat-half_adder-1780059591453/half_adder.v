// half_adder.v - 1-bit half-adder (synthesizable)
module half_adder (
  input  wire a,
  input  wire b,
  output wire sum,
  output wire carry_out
);
  // Combinational logic
  assign sum       = a ^ b;
  assign carry_out = a & b;
endmodule

`timescale 1ns/1ps

module tb;
  // Optional clock/reset for uniform harness operation
  reg clk;
  reg rst_n;

  // Stimulus to DUT
  reg  a, b;
  wire sum, carry_out;

  // Device Under Test
  half_adder dut (
    .a(a),
    .b(b),
    .sum(sum),
    .carry_out(carry_out)
  );

  // Clock generation (100 MHz)
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Reset
  initial begin
    rst_n = 1'b0;
    a = 1'b0;
    b = 1'b0;
    #12;        // cross a rising edge
    rst_n = 1'b1;
  end

  integer i;
  reg exp_sum, exp_carry;

  initial begin
    // Wait for reset deassertion
    @(posedge rst_n);

    // Walk all 4 combinations of a,b
    for (i = 0; i < 4; i = i + 1) begin
      @(posedge clk);
      a <= i[0];
      b <= i[1];
      #1; // allow combinational settle

      exp_sum   = i[0] ^ i[1];
      exp_carry = i[0] & i[1];

      if ((sum !== exp_sum) || (carry_out !== exp_carry)) begin
        $error("Mismatch: a=%0b b=%0b -> got sum=%0b carry=%0b, expected sum=%0b carry=%0b",
               i[0], i[1], sum, carry_out, exp_sum, exp_carry);
      end else begin
        $display("PASS: a=%0b b=%0b -> sum=%0b carry=%0b", i[0], i[1], sum, carry_out);
      end
    end

    @(posedge clk);
    $display("All tests passed.");
    $finish;
  end
endmodule
