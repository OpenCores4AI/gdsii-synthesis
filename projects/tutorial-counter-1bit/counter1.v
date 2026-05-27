module counter1 (
  input  wire clk,
  input  wire rst,
  output reg  q
);
  always @(posedge clk) begin
    if (rst) q <= 1'b0;
    else     q <= ~q;
  end
endmodule
