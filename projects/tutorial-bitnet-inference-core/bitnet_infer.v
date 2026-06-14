module bitnet_infer #(
  parameter LANES = 16,
  parameter SHIFT = 5
) (
  input  wire                clk,
  input  wire                rst,
  input  wire                en,
  input  wire                first,
  input  wire                last,
  input  wire [LANES*8-1:0]  act_vec,
  input  wire [LANES*2-1:0]  twe_vec,
  output reg  [7:0]          y,
  output reg                 y_valid
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
  reg signed [31:0] tile_sum;
  integer k;
  always @* begin
    tile_sum = 32'sd0;
    for (k = 0; k < LANES; k = k + 1) begin
      tile_sum = tile_sum + {{16{lane_contrib[k][15]}}, lane_contrib[k]};
    end
  end
  reg signed [31:0] acc;
  wire signed [31:0] acc_next = (first ? 32'sd0 : acc) + tile_sum;
  wire signed [31:0] relu      = (acc_next[31]) ? 32'sd0 : acc_next;
  wire        [31:0] shifted   = relu >>> SHIFT;
  wire        [7:0]  saturated = (|shifted[31:8]) ? 8'hFF : shifted[7:0];
  always @(posedge clk) begin
    if (rst) begin
      acc <= 32'sd0; y <= 8'd0; y_valid <= 1'b0;
    end else if (en) begin
      acc <= acc_next; y <= last ? saturated : y; y_valid <= last;
    end else begin
      y_valid <= 1'b0;
    end
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
