// alu4.v - 4-bit ALU with signed overflow detection (top-level)
module alu4 (
  input  wire [3:0] a,
  input  wire [3:0] b,
  input  wire [2:0] op,     // 000=ADD, 001=SUB, 010=AND, 011=OR, 100=XOR
  output reg  [3:0] y,
  output reg        overflow
);

  // 5-bit intermediates to capture carry/borrow but we only export overflow (signed)
  wire [4:0] add5;
  wire [4:0] sub5;
  assign add5 = {1'b0, a} + {1'b0, b};
  assign sub5 = {1'b0, a} - {1'b0, b};

  // Two's-complement signed overflow detection
  wire add_ovf;
  wire sub_ovf;
  assign add_ovf = (a[3] == b[3]) && (add5[3] != a[3]);
  assign sub_ovf = (a[3] != b[3]) && (sub5[3] != a[3]);

  always @* begin
    y        = 4'b0000;
    overflow = 1'b0;
    case (op)
      3'b000: begin // ADD
        y        = add5[3:0];
        overflow = add_ovf;
      end
      3'b001: begin // SUB
        y        = sub5[3:0];
        overflow = sub_ovf;
      end
      3'b010: begin // AND
        y        = a & b;
        overflow = 1'b0;
      end
      3'b011: begin // OR
        y        = a | b;
        overflow = 1'b0;
      end
      3'b100: begin // XOR
        y        = a ^ b;
        overflow = 1'b0;
      end
      default: begin
        y        = 4'b0000;
        overflow = 1'b0;
      end
    endcase
  end

endmodule
