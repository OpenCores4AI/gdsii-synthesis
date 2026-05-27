module alu64 (
  input  wire [63:0] a,
  input  wire [63:0] b,
  input  wire [2:0]  op,
  output reg  [63:0] result,
  output wire        zero,
  output wire        negative,
  output reg         overflow
);
  wire [63:0] sum     = a + b;
  wire [63:0] diff    = a - b;
  wire        add_ovf = (a[63] == b[63]) && (sum[63]  != a[63]);
  wire        sub_ovf = (a[63] != b[63]) && (diff[63] != a[63]);
  always @* begin
    overflow = 1'b0;
    case (op)
      3'b000: begin result = sum;            overflow = add_ovf; end
      3'b001: begin result = diff;           overflow = sub_ovf; end
      3'b010:        result = a & b;
      3'b011:        result = a | b;
      3'b100:        result = a ^ b;
      3'b101:        result = a << b[5:0];
      3'b110:        result = a >> b[5:0];
      3'b111:        result = $signed(a) >>> b[5:0];
      default:       result = 64'b0;
    endcase
  end
  assign zero     = (result == 64'b0);
  assign negative = result[63];
endmodule
