module counter_1bit(
  input wire clk,
  input wire rst,
  output reg count
);

  always @(posedge clk or posedge rst) begin
    if (rst)
      count <= 1'b0;
    else
      count <= ~count;
  end

endmodule