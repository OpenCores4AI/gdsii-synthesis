module adder2(
  input  wire       clk,
  input  wire       rst,
  input  wire [1:0] a,
  input  wire [1:0] b,
  input  wire       cin,
  output reg  [1:0] sum,
  output reg        cout
);
  always @(posedge clk) begin
    if (rst) {cout, sum} <= 3'b000;
    else     {cout, sum} <= a + b + cin;
  end
endmodule
