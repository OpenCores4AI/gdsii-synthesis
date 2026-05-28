`timescale 1ns/1ps
// half_adder.v - 1-bit half-adder (synthesizable)
module half_adder (
  input  wire a,
  input  wire b,
  output wire sum,
  output wire carry_out
);
  assign sum       = a ^ b;
  assign carry_out = a & b;
endmodule
