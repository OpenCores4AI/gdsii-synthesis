`timescale 1ns/1ps

module tb;
  reg clk;
  reg rst_n;
  reg  a, b;
  wire sum, carry_out;

  half_adder dut (
    .a(a),
    .b(b),
    .sum(sum),
    .carry_out(carry_out)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 1'b0;
    a = 1'b0;
    b = 1'b0;
    #12;
    rst_n = 1'b1;
  end

  integer i;
  reg exp_sum, exp_carry;

  initial begin
    @(posedge rst_n);
    for (i = 0; i < 4; i = i + 1) begin
      @(posedge clk);
      a <= i[0];
      b <= i[1];
      #1;
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
