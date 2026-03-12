// adder_32bit.v
// A 32-bit full adder circuit.

module adder_32bit (
    input  [31:0] a,
    input  [31:0] b,
    input         cin,
    output [31:0] sum,
    output        cout
);

    // The addition of two 32-bit numbers and a carry-in can result in a 33-bit number.
    // The concatenation {cout, sum} captures this 33-bit result.
    // The MSB is the carry-out, and the lower 32 bits are the sum.
    assign {cout, sum} = a + b + cin;

endmodule
