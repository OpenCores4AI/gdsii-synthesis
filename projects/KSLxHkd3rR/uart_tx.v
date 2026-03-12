// Elite Hardware Engineer: UART Transmitter Module
//
// Description:
// This module implements a synthesizable UART (Universal Asynchronous
// Receiver-Transmitter) transmitter. It takes 8-bit parallel data,
// and upon a start signal, serializes it according to the standard
// UART protocol: 1 start bit, 8 data bits (LSB first), 1 stop bit.
// The module is parameterized for easy integration with different
// system clock frequencies and baud rates.

module uart_tx #(
    parameter CLKS_PER_BIT = 10417 // Example for 100MHz clock and 9600 baud (100,000,000 / 9600)
) (
    input                       i_clk,
    input                       i_rst_n,

    // Interface to the system
    input       [7:0]           i_data,
    input                       i_tx_start,
    output reg                  o_tx_busy,

    // Serial output
    output reg                  o_tx_serial
);

    // FSM State Definitions
    localparam [1:0] ST_IDLE     = 2'b00;
    localparam [1:0] ST_START_BIT = 2'b01;
    localparam [1:0] ST_DATA_BITS = 2'b10;
    localparam [1:0] ST_STOP_BIT  = 2'b11;

    // Internal Registers
    reg [1:0]   r_state;
    reg [19:0]  r_clk_counter;  // Counter for baud rate generation, sized for large divisors
    reg [2:0]   r_bit_counter;  // Counts the 8 data bits being sent
    reg [7:0]   r_tx_buffer;    // Holds the data to be transmitted

    // Wires
    wire        w_tick;

    // Baud Rate Tick Generator
    // Generates a single-cycle pulse at the specified baud rate
    assign w_tick = (r_clk_counter == CLKS_PER_BIT - 1);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_clk_counter <= 20'd0;
        end else begin
            if (r_state == ST_IDLE) begin
                r_clk_counter <= 20'd0;
            end else begin
                if (r_clk_counter == CLKS_PER_BIT - 1) begin
                    r_clk_counter <= 20'd0;
                end else begin
                    r_clk_counter <= r_clk_counter + 1;
                end
            end
        end
    end

    // FSM and Datapath Logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state       <= ST_IDLE;
            r_bit_counter <= 3'd0;
            r_tx_buffer   <= 8'd0;
            o_tx_serial   <= 1'b1; // UART line is high when idle
            o_tx_busy     <= 1'b0;
        end else begin
            case (r_state)
                ST_IDLE: begin
                    o_tx_serial <= 1'b1; // Keep line high
                    o_tx_busy   <= 1'b0;
                    if (i_tx_start) begin
                        r_state     <= ST_START_BIT;
                        r_tx_buffer <= i_data; // Latch input data
                        o_tx_busy   <= 1'b1;
                    end
                end

                ST_START_BIT: begin
                    o_tx_serial <= 1'b0; // Send start bit (low)
                    if (w_tick) begin
                        r_state       <= ST_DATA_BITS;
                        r_bit_counter <= 3'd0;
                    end
                end

                ST_DATA_BITS: begin
                    o_tx_serial <= r_tx_buffer[r_bit_counter]; // Send current data bit (LSB first)
                    if (w_tick) begin
                        if (r_bit_counter < 7) begin
                            r_bit_counter <= r_bit_counter + 1;
                        end else begin
                            r_state <= ST_STOP_BIT;
                        end
                    end
                end

                ST_STOP_BIT: begin
                    o_tx_serial <= 1'b1; // Send stop bit (high)
                    if (w_tick) begin
                        r_state   <= ST_IDLE;
                        o_tx_busy <= 1'b0;
                    end
                end

                default: begin
                    r_state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule