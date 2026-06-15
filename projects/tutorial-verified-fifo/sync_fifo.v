// 8-deep, 8-bit synchronous FIFO with empty/full flags.
//
// Single-clock domain — read and write logic share `clk`. Pointers are
// one bit wider than strictly needed so empty/full can be distinguished
// by comparing the MSBs of the read and write pointers.
module sync_fifo #(
  parameter DEPTH = 8,
  parameter WIDTH = 8
) (
  input  wire              clk,
  input  wire              rst,
  input  wire              wr_en,
  input  wire              rd_en,
  input  wire [WIDTH-1:0]  din,
  output reg  [WIDTH-1:0]  dout,
  output wire              empty,
  output wire              full
);
  localparam AW = 3; // log2(DEPTH)
  reg [WIDTH-1:0] mem [0:DEPTH-1];
  reg [AW:0] wr_ptr;
  reg [AW:0] rd_ptr;

  wire do_wr = wr_en && !full;
  wire do_rd = rd_en && !empty;

  always @(posedge clk) begin
    if (rst) begin
      wr_ptr <= {(AW+1){1'b0}};
      rd_ptr <= {(AW+1){1'b0}};
      dout   <= {WIDTH{1'b0}};
    end else begin
      if (do_wr) begin
        mem[wr_ptr[AW-1:0]] <= din;
        wr_ptr <= wr_ptr + 1'b1;
      end
      if (do_rd) begin
        dout   <= mem[rd_ptr[AW-1:0]];
        rd_ptr <= rd_ptr + 1'b1;
      end
    end
  end

  assign empty = (wr_ptr == rd_ptr);
  assign full  = (wr_ptr[AW] != rd_ptr[AW])
              && (wr_ptr[AW-1:0] == rd_ptr[AW-1:0]);
endmodule
