//====================================================================
// Unified UART TX chip RTL (single file)
// Contains: baud_gen, uart_tx, uart_tx_top (top-level)
// Synthesizable with SKY130 using OpenLane/OpenROAD flow
//====================================================================

// -----------------------------
// Module: baud_gen
// -----------------------------
module baud_gen #(
    parameter integer CLKS_PER_BIT = 434  // e.g., 50MHz/115200 ≈ 434
) (
    input  wire clk,
    input  wire rst_n,     // active-low synchronous reset
    output reg  baud_tick  // 1-clock pulse at bit boundaries
);
    // Sizing counter width via constant function
    function integer clog2;
        input integer value;
        integer i;
        begin
            i = 0;
            value = value - 1;
            for (i = 0; value > 0; i = i + 1)
                value = value >> 1;
            clog2 = i;
        end
    endfunction

    localparam integer CTR_WIDTH = (CLKS_PER_BIT > 1) ? clog2(CLKS_PER_BIT) : 1;
    reg [CTR_WIDTH-1:0] ctr;

    always @(posedge clk) begin
        if (!rst_n) begin
            ctr       <= {CTR_WIDTH{1'b0}};
            baud_tick <= 1'b0;
        end else begin
            if (ctr == CLKS_PER_BIT-1) begin
                ctr       <= {CTR_WIDTH{1'b0}};
                baud_tick <= 1'b1;
            end else begin
                ctr       <= ctr + {{(CTR_WIDTH-1){1'b0}}, 1'b1};
                baud_tick <= 1'b0;
            end
        end
    end
endmodule

// -----------------------------
// Module: uart_tx
// Parameterized UART transmitter
// Aligns all bit transitions to baud_tick for exact bit widths
// -----------------------------
module uart_tx #(
    parameter integer DATA_BITS   = 8,
    parameter integer PARITY_MODE = 0, // 0=None, 1=Even, 2=Odd
    parameter integer STOP_BITS   = 1  // 1 or 2
) (
    input  wire                   clk,
    input  wire                   rst_n,      // active-low synchronous reset
    // Handshake
    input  wire                   tx_valid,   // present data when tx_ready=1
    output wire                   tx_ready,   // high when ready to accept a byte
    input  wire [DATA_BITS-1:0]   tx_data,
    // Timing
    input  wire                   baud_tick,  // 1-cycle pulse per bit period
    // Outputs
    output reg                    txd,        // serial line, idle=1
    output reg                    busy,       // high while transmitting
    output reg                    done        // 1-cycle pulse when frame completed
);
    // constant function for sizing
    function integer clog2;
        input integer value;
        integer i;
        begin
            i = 0;
            value = value - 1;
            for (i = 0; value > 0; i = i + 1)
                value = value >> 1;
            clog2 = i;
        end
    endfunction

    localparam integer BITIDX_W = (DATA_BITS <= 1) ? 1 : clog2(DATA_BITS);

    localparam [2:0]
        S_IDLE      = 3'd0,
        S_WAIT      = 3'd1, // wait for next baud_tick before asserting START
        S_START     = 3'd2,
        S_DATA      = 3'd3,
        S_PARITY    = 3'd4,
        S_STOP      = 3'd5;

    reg [2:0] state, next_state;

    reg [DATA_BITS-1:0] shreg;
    reg [BITIDX_W-1:0]  bit_idx; // counts 0..DATA_BITS-1
    reg                  parity_bit;
    reg [1:0]            stop_cnt; // supports up to 2 stop bits

    wire parity_en = (PARITY_MODE != 0);

    // ready when idle
    assign tx_ready = (state == S_IDLE);

    // Next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (tx_valid) next_state = S_WAIT;
            end
            S_WAIT: begin
                if (baud_tick) next_state = S_START;
            end
            S_START: begin
                if (baud_tick) next_state = S_DATA;
            end
            S_DATA: begin
                if (baud_tick) begin
                    if (bit_idx == DATA_BITS-1) begin
                        next_state = parity_en ? S_PARITY : S_STOP;
                    end else begin
                        next_state = S_DATA;
                    end
                end
            end
            S_PARITY: begin
                if (baud_tick) next_state = S_STOP;
            end
            S_STOP: begin
                if (baud_tick) begin
                    if (stop_cnt == (STOP_BITS-1)) next_state = S_IDLE;
                    else next_state = S_STOP;
                end
            end
            default: next_state = S_IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            shreg      <= {DATA_BITS{1'b0}};
            bit_idx    <= {BITIDX_W{1'b0}};
            parity_bit <= 1'b0;
            stop_cnt   <= 2'd0;
            txd        <= 1'b1; // idle high
            busy       <= 1'b0;
            done       <= 1'b0;
        end else begin
            state <= next_state;
            done  <= 1'b0; // default

            case (state)
                S_IDLE: begin
                    txd      <= 1'b1;
                    busy     <= 1'b0;
                    stop_cnt <= 2'd0;
                    bit_idx  <= {BITIDX_W{1'b0}};
                    if (tx_valid) begin
                        shreg <= tx_data; // latch data when valid & ready
                        // precompute parity
                        case (PARITY_MODE)
                            1: parity_bit <= ~^tx_data; // even
                            2: parity_bit <=  ^tx_data; // odd
                            default: parity_bit <= 1'b0;
                        endcase
                        busy <= 1'b1; // indicate pending frame
                    end
                end
                S_WAIT: begin
                    txd  <= 1'b1; // keep line idle high until first tick
                    busy <= 1'b1;
                end
                S_START: begin
                    // drive start bit low for exactly one baud interval
                    txd  <= 1'b0;
                    busy <= 1'b1;
                end
                S_DATA: begin
                    // drive current LSB, advance on baud_tick
                    txd  <= shreg[0];
                    busy <= 1'b1;
                    if (baud_tick) begin
                        shreg   <= {1'b0, shreg[DATA_BITS-1:1]}; // shift right, LSB first
                        bit_idx <= bit_idx + {{(BITIDX_W-1){1'b0}}, 1'b1};
                    end
                end
                S_PARITY: begin
                    txd  <= parity_bit;
                    busy <= 1'b1;
                end
                S_STOP: begin
                    txd  <= 1'b1;
                    busy <= 1'b1;
                    if (baud_tick) begin
                        if (stop_cnt == (STOP_BITS-1)) begin
                            done     <= 1'b1; // frame complete
                            busy     <= 1'b0;
                            stop_cnt <= 2'd0;
                        end else begin
                            stop_cnt <= stop_cnt + 1'b1;
                        end
                    end
                end
                default: begin
                    txd  <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end
endmodule

// -----------------------------
// Module: uart_tx_top (TOP)
// Computes CLKS_PER_BIT from params and instantiates baud_gen + uart_tx
// -----------------------------
module uart_tx_top #(
    parameter integer CLOCK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE   = 115_200,
    parameter integer DATA_BITS   = 8,
    parameter integer PARITY_MODE = 0, // 0=None,1=Even,2=Odd
    parameter integer STOP_BITS   = 1
) (
    input  wire                 clk,
    input  wire                 rst_n,
    // Transmit interface
    input  wire                 tx_valid,
    output wire                 tx_ready,
    input  wire [DATA_BITS-1:0] tx_data,
    // Line output
    output wire                 txd,
    output wire                 busy,
    output wire                 done
);
    // Rounded integer division for CLKS_PER_BIT
    localparam integer CLKS_PER_BIT = (BAUD_RATE == 0) ? 1 :
                                      ((CLOCK_FREQ + (BAUD_RATE/2)) / BAUD_RATE);

    wire baud_tick;

    baud_gen #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_baud (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick)
    );

    uart_tx #(
        .DATA_BITS(DATA_BITS),
        .PARITY_MODE(PARITY_MODE),
        .STOP_BITS(STOP_BITS)
    ) u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),
        .tx_data(tx_data),
        .baud_tick(baud_tick),
        .txd(txd),
        .busy(busy),
        .done(done)
    );
endmodule
