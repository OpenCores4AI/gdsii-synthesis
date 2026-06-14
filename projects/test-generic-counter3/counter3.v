module counter3(input wire clk, input wire rst, input wire en, output reg [2:0] q, output wire tc);
  always @(posedge clk) begin
    if (rst) q <= 3'b000;
    else if (en) q <= q + 3'b001;
  end
  assign tc = (q == 3'b111);
endmodule
