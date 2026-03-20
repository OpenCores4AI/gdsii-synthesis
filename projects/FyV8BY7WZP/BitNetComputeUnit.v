// OpenCores AI - BitNetComputeUnit.v
// This module performs the core 1.58-bit ternary operation for the BitNet architecture.
// It replaces traditional multiplication with conditional addition/subtraction.

module BitNetComputeUnit (
    // System Signals
    input wire          clk,
    input wire          rst_n,

    // Input Data
    input wire          i_valid,
    input wire [7:0]    i_activation,   // 8-bit activation value
    input wire [1:0]    i_weight,       // 2-bit encoded ternary weight (01: +1, 10: -1, 00: 0)
    input wire [31:0]   i_accum_in,     // Incoming accumulation value

    // Output Data
    output reg          o_valid,
    output reg [31:0]   o_accum_out     // Result of the operation
);

    // Internal register for pipelining
    reg [31:0] result_reg;

    // Ternary Weight Constants
    localparam WEIGHT_ZERO = 2'b00;
    localparam WEIGHT_PLUS_ONE = 2'b01;
    localparam WEIGHT_MINUS_ONE = 2'b10;

    // The core computational logic is combinatorial
    always @(*) begin
        // Default assignment to handle the '0' weight case
        result_reg = i_accum_in; 

        case (i_weight)
            WEIGHT_PLUS_ONE: begin
                // Add activation to accumulator
                result_reg = i_accum_in + {{24{i_activation[7]}}, i_activation}; // Sign-extend activation
            end
            WEIGHT_MINUS_ONE: begin
                // Subtract activation from accumulator
                result_reg = i_accum_in - {{24{i_activation[7]}}, i_activation}; // Sign-extend activation
            end
            // For WEIGHT_ZERO (2'b00) and unused (2'b11), we do nothing (pass-through)
            default: begin
                result_reg = i_accum_in;
            end
        endcase
    end

    // The output registers are updated on the clock edge for a single-cycle pipeline
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_accum_out <= 32'b0;
            o_valid     <= 1'b0;
        end else begin
            o_accum_out <= result_reg;
            o_valid     <= i_valid;
        end
    end

endmodule
