module cordic_rotate #(
  parameter WIDTH = 16,
  parameter ITERS = 15
) (
  input  wire                clk,
  input  wire                rst,
  input  wire                start,
  input  wire [WIDTH-1:0]    x_in,
  input  wire [WIDTH-1:0]    y_in,
  input  wire [WIDTH-1:0]    angle,
  output reg  [WIDTH-1:0]    x_out,
  output reg  [WIDTH-1:0]    y_out,
  output reg                 valid
);
  function signed [WIDTH-1:0] atan_lut(input [4:0] i);
    case (i)
      5'd0:  atan_lut = 16'sd12868;
      5'd1:  atan_lut = 16'sd7596;
      5'd2:  atan_lut = 16'sd4014;
      5'd3:  atan_lut = 16'sd2037;
      5'd4:  atan_lut = 16'sd1023;
      5'd5:  atan_lut = 16'sd512;
      5'd6:  atan_lut = 16'sd256;
      5'd7:  atan_lut = 16'sd128;
      5'd8:  atan_lut = 16'sd64;
      5'd9:  atan_lut = 16'sd32;
      5'd10: atan_lut = 16'sd16;
      5'd11: atan_lut = 16'sd8;
      5'd12: atan_lut = 16'sd4;
      5'd13: atan_lut = 16'sd2;
      5'd14: atan_lut = 16'sd1;
      default: atan_lut = 16'sd0;
    endcase
  endfunction

  reg signed [WIDTH-1:0] x, y, z;
  reg        [4:0]       i;
  reg                    busy;

  wire signed [WIDTH-1:0] x_shift = x >>> i;
  wire signed [WIDTH-1:0] y_shift = y >>> i;
  wire                    dir_neg = z[WIDTH-1];

  always @(posedge clk) begin
    if (rst) begin
      busy <= 1'b0; valid <= 1'b0; i <= 5'd0;
      x <= 0; y <= 0; z <= 0; x_out <= 0; y_out <= 0;
    end else begin
      valid <= 1'b0;
      if (start && !busy) begin
        x <= $signed(x_in); y <= $signed(y_in); z <= $signed(angle);
        i <= 5'd0; busy <= 1'b1;
      end else if (busy) begin
        if (dir_neg) begin
          x <= x + y_shift;
          y <= y - x_shift;
          z <= z + atan_lut(i);
        end else begin
          x <= x - y_shift;
          y <= y + x_shift;
          z <= z - atan_lut(i);
        end
        if (i == ITERS-1) begin
          busy  <= 1'b0;
          valid <= 1'b1;
          x_out <= dir_neg ? (x + y_shift) : (x - y_shift);
          y_out <= dir_neg ? (y - x_shift) : (y + x_shift);
        end else begin
          i <= i + 5'd1;
        end
      end
    end
  end
endmodule
