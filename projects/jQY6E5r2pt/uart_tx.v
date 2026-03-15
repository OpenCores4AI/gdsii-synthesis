// uart_tx.v
//
// Elite Hardware Engineer: Design by an expert VLSI Architect
// Description: A synthesizable, parameterized UART transmitter module.
//
// Parameters:
//   CLKS_PER_BIT: Number of system clock cycles for one serial bit period.
//                 Baud Rate = System Clock Frequency / CLKS_PER_BIT
//
// Interface:
//   i_clk        : System clock
//   i_rst_n      : Active-low asynchronous reset
//   i_tx_dv      : Data valid pulse. A single-cycle pulse to start transmission.
//   i_tx_data    : 8-bit data to be transmitted.
//   o_tx_serial  : Serial data output line.
//   o_tx_busy    : High when a transmission is in progress.

module uart_tx #(
    parameter CLKS_PER_BIT = 16
) (
    input  wire           i_clk,
    input  wire           i_rst_n,
    input  wire           i_tx_dv,
    input  wire [7:0]     i_tx_data,
    output wire           o_tx_serial,
    output wire           o_tx_busy
);

    // FSM State Definitions
    localparam [1:0] S_IDLE      = 2'b00;
    localparam [1:0] S_START_BIT = 2'b01;
    localparam [1:0] S_DATA_BITS = 2'b10;
    localparam [1:0] S_STOP_BIT  = 2'b11;

    // Internal Registers
    reg [1:0]  r_state;
    reg [7:0]  r_tx_data;
    reg        r_tx_serial;
    reg        r_tx_busy;
    
    // Counters
    reg [$clog2(CLKS_PER_BIT)-1:0] r_clk_count;
    reg [2:0]                     r_bit_index;

    // Wires
    wire w_bit_done;

    // FSM and Datapath Logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state     <= S_IDLE;
            r_clk_count <= 0;
            r_bit_index <= 0;
            r_tx_data   <= 8'b0;
            r_tx_serial <= 1'b1; // UART line is idle high
            r_tx_busy   <= 1'b0;
        end else begin
            case (r_state)
                S_IDLE: begin
                    r_tx_serial <= 1'b1;
                    r_tx_busy   <= 1'b0;
                    r_clk_count <= 0;
                    r_bit_index <= 0;
                    if (i_tx_dv) begin
                        r_tx_busy   <= 1'b1;
                        r_tx_data   <= i_tx_data;
                        r_state     <= S_START_BIT;
                    end
                end

                S_START_BIT: begin
                    r_tx_serial <= 1'b0; // Drive start bit low
                    if (w_bit_done) begin
                        r_clk_count <= 0;
                        r_state     <= S_DATA_BITS;
                    end else begin
                        r_clk_count <= r_clk_count + 1;
                    end
                end

                S_DATA_BITS: begin
                    r_tx_serial <= r_tx_data[r_bit_index];
                    if (w_bit_done) begin
                        r_clk_count <= 0;
                        if (r_bit_index == 3'd7) begin
                            r_bit_index <= 0;
                            r_state     <= S_STOP_BIT;
                        end else begin
                            r_bit_index <= r_bit_index + 1;
                        end
                    end else begin
                        r_clk_count <= r_clk_count + 1;
                    end
                end

                S_STOP_BIT: begin
                    r_tx_serial <= 1'b1; // Drive stop bit high
                    if (w_bit_done) begin
                        r_clk_count <= 0;
                        r_state     <= S_IDLE;
                    end else begin
                        r_clk_count <= r_clk_count + 1;
                    end
                end
                
                default: begin
                    r_state <= S_IDLE;
                end
            endcase
        end
    end

    // Combinational Logic
    assign w_bit_done  = (r_clk_count == CLKS_PER_BIT - 1);
    assign o_tx_serial = r_tx_serial;
    assign o_tx_busy   = r_tx_busy;

endmodule