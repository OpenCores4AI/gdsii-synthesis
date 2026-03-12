// uart_tx.v
//
// A synthesizable Verilog module for a UART transmitter.
// Transmits data in 8-N-1 format (8 data bits, no parity, 1 stop bit).
//
// Parameters:
//   CLKS_PER_BIT: The number of system clock cycles per serial bit.
//                 Determines the baud rate.
//                 Formula: CLKS_PER_BIT = (System Clock Freq) / (Baud Rate)
//                 Example: 50MHz clock, 9600 baud => 50,000,000 / 9600 = 5208

module uart_tx #(
    parameter CLKS_PER_BIT = 5208
) (
    input wire           i_clk,
    input wire           i_rst_n,

    // Data interface
    input wire [7:0]     i_tx_data,
    input wire           i_tx_dv,     // Data valid strobe

    // UART interface
    output wire          o_tx_serial,
    output wire          o_tx_busy
);

    // FSM States
    localparam [1:0] ST_IDLE      = 2'b00;
    localparam [1:0] ST_START_BIT = 2'b01;
    localparam [1:0] ST_DATA_BITS = 2'b10;
    localparam [1:0] ST_STOP_BIT  = 2'b11;

    // Registers
    reg [1:0]  r_state;
    reg [15:0] r_clk_counter; // Counter for baud rate generation
    reg [2:0]  r_bit_index;   // Counts which data bit is being sent
    reg [7:0]  r_tx_data;     // Latched data to be transmitted
    reg        r_tx_serial;
    reg        r_tx_busy;

    // Wires
    wire w_tick; // Baud rate tick

    // Baud Rate Generator
    assign w_tick = (r_clk_counter == CLKS_PER_BIT - 1);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_clk_counter <= 16'd0;
        end else begin
            if (r_state == ST_IDLE) begin
                r_clk_counter <= 16'd0;
            end else begin
                if (w_tick) begin
                    r_clk_counter <= 16'd0;
                end else begin
                    r_clk_counter <= r_clk_counter + 1'b1;
                end
            end
        end
    end

    // Main FSM
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_state     <= ST_IDLE;
            r_tx_data   <= 8'd0;
            r_bit_index <= 3'd0;
            r_tx_serial <= 1'b1; // UART idle is high
            r_tx_busy   <= 1'b0;
        end else begin
            case (r_state)
                ST_IDLE: begin
                    r_tx_serial <= 1'b1;
                    r_tx_busy   <= 1'b0;
                    r_bit_index <= 3'd0;

                    if (i_tx_dv) begin
                        r_tx_data <= i_tx_data;
                        r_tx_busy <= 1'b1;
                        r_state   <= ST_START_BIT;
                    end
                end

                ST_START_BIT: begin
                    r_tx_serial <= 1'b0; // Drive start bit low
                    if (w_tick) begin
                        r_state <= ST_DATA_BITS;
                    end
                end

                ST_DATA_BITS: begin
                    r_tx_serial <= r_tx_data[r_bit_index];
                    if (w_tick) begin
                        if (r_bit_index == 3'd7) begin
                            r_bit_index <= 3'd0;
                            r_state     <= ST_STOP_BIT;
                        end else begin
                            r_bit_index <= r_bit_index + 1'b1;
                        end
                    end
                end

                ST_STOP_BIT: begin
                    r_tx_serial <= 1'b1; // Drive stop bit high
                    if (w_tick) begin
                        r_tx_busy <= 1'b0;
                        r_state   <= ST_IDLE;
                    end
                end

                default: begin
                    r_state <= ST_IDLE;
                end
            endcase
        end
    end

    // Assign outputs
    assign o_tx_serial = r_tx_serial;
    assign o_tx_busy   = r_tx_busy;

endmodule