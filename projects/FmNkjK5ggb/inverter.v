// A simple inverter module
// It takes a single-bit input 'a' and produces a single-bit output 'y'
// where y is the logical NOT of a.

module inverter (
  input  wire a,
  output wire y
);

  // Continuous assignment for the inversion logic
  assign y = ~a;

endmodule
