module bitnet_mac #(
  parameter LANES = 8
) (
  input  wire                       clk,
  input  wire                       rst,
  input  wire                       enable,
  input  wire [LANES*8-1:0]         act_vec,
  input  wire [LANES*2-1:0]         twe_vec,
  output reg  [23:0]                acc
);
  wire signed [15:0] lane_contrib [0:LANES-1];
  genvar i;
  generate
    for (i = 0; i < LANES; i = i + 1) begin : g_lane
      bitnet_lane u_lane (
        .act    ($signed(act_vec[i*8 +: 8])),
        .twe    (twe_vec[i*2 +: 2]),
        .contrib(lane_contrib[i])
      );
    end
  endgenerate
  reg signed [23:0] tree_sum;
  integer k;
  always @* begin
    tree_sum = 24'sd0;
    for (k = 0; k < LANES; k = k + 1) begin
      tree_sum = tree_sum + {{8{lane_contrib[k][15]}}, lane_contrib[k]};
    end
  end
  always @(posedge clk) begin
    if (rst)         acc <= 24'd0;
    else if (enable) acc <= acc + $unsigned(tree_sum);
  end
endmodule

module bitnet_lane (
  input  wire signed [7:0]  act,
  input  wire        [1:0]  twe,
  output reg  signed [15:0] contrib
);
  wire signed [15:0] act_ext = {{8{act[7]}}, act};
  always @* begin
    case (twe)
      2'b00:   contrib = 16'sd0;
      2'b01:   contrib =  act_ext;
      2'b10:   contrib = -act_ext;
      default: contrib = 16'sd0;
    endcase
  end
endmodule
