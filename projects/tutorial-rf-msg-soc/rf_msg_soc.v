// rf_msg_soc — message-inference SoC with dual bus + RF I/O.
//
// Receives an 8-byte message from EITHER a parallel bus OR the RF modem
// interface (digital baseband), stores it in on-chip memory, runs a BitNet
// ternary inference over it, and emits the 1-byte response on BOTH the bus and
// the RF interface. All inference + memory is on-chip. The RF analog frontend
// (antenna/LNA/PA) is a separate custom layout; this is the synthesizable
// digital core that drives it and works the same on a Xilinx FPGA wired to a
// WiFi/BT radio.
module rf_msg_soc #(
  parameter MSG_LEN = 8,
  parameter SHIFT   = 2
) (
  input  wire       clk,
  input  wire       rst,          // synchronous, active high
  // Bus receive / transmit (byte stream)
  input  wire [7:0] bus_rx_data,
  input  wire       bus_rx_valid,
  output reg  [7:0] bus_tx_data,
  output reg        bus_tx_valid,
  // RF modem receive / transmit (digital baseband byte stream)
  input  wire [7:0] rf_rx_data,
  input  wire       rf_rx_valid,
  output reg  [7:0] rf_tx_data,
  output reg        rf_tx_valid,
  output reg        busy
);
  // Ternary weight per message position (2'b01=+1, 2'b10=-1, 2'b00=0).
  function [1:0] kw; input [3:0] i; begin
    case (i)
      0: kw=2'b01; 1: kw=2'b10; 2: kw=2'b01; 3: kw=2'b00;
      4: kw=2'b01; 5: kw=2'b10; 6: kw=2'b10; 7: kw=2'b01;
      default: kw=2'b00;
    endcase end
  endfunction

  // On-chip message memory.
  reg  [7:0] mem [0:MSG_LEN-1];
  reg  [3:0] count;
  reg  [1:0] state;
  localparam IDLE=2'd0, RECV=2'd1, INFER=2'd2, RESP=2'd3;

  // Source select (bus has priority).
  wire        rx_valid = bus_rx_valid | rf_rx_valid;
  wire [7:0]  rx_data  = bus_rx_valid ? bus_rx_data : rf_rx_data;

  // Combinational ternary inference over stored message.
  integer k;
  reg signed [19:0] acc;
  always @* begin
    acc = 20'sd0;
    for (k = 0; k < MSG_LEN; k = k + 1) begin
      case (kw(k[3:0]))
        2'b01: acc = acc + $signed({{12{mem[k][7]}}, mem[k]});
        2'b10: acc = acc - $signed({{12{mem[k][7]}}, mem[k]});
        default: ;
      endcase
    end
  end
  wire signed [19:0] relu = acc[19] ? 20'sd0 : acc;
  wire        [19:0] shifted = relu >>> SHIFT;
  wire        [7:0]  result = (|shifted[19:8]) ? 8'hFF : shifted[7:0];

  integer j;
  always @(posedge clk) begin
    if (rst) begin
      state<=IDLE; count<=0; busy<=0;
      bus_tx_valid<=0; rf_tx_valid<=0; bus_tx_data<=0; rf_tx_data<=0;
    end else begin
      bus_tx_valid<=0; rf_tx_valid<=0;
      case (state)
        IDLE: begin
          busy<=0;
          if (rx_valid) begin mem[0]<=rx_data; count<=1; busy<=1; state<=RECV; end
        end
        RECV: begin
          if (rx_valid) begin
            mem[count]<=rx_data;
            if (count==MSG_LEN-1) begin count<=0; state<=INFER; end
            else count<=count+1;
          end
        end
        INFER: state<=RESP;  // acc settles combinationally
        RESP: begin
          bus_tx_data<=result; bus_tx_valid<=1;
          rf_tx_data<=result;  rf_tx_valid<=1;
          state<=IDLE;
        end
      endcase
    end
  end
endmodule
