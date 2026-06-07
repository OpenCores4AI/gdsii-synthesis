`timescale 1ns/1ps
`default_nettype none

module half_adder (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry_out
);
    // Combinational half-adder logic
    assign sum       = a ^ b;
    assign carry_out = a & b;
endmodule

`default_nettype wire
