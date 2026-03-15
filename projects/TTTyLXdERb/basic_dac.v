// basic_dac.v
//
// A basic N-bit digital-to-analog converter digital core.
// This module registers the incoming digital value to provide a stable output
// for an external R-2R ladder network or other analog conversion circuitry.

module basic_dac #(
    parameter WIDTH = 8
) (
    // System signals
    input wire              clk,
    input wire              rst_n,

    // Data input
    input wire [WIDTH-1:0]  digital_in,

    // Output to analog circuitry
    output reg [WIDTH-1:0]  analog_out
);

    // Synchronous process to register the input value
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            analog_out <= {WIDTH{1'b0}};
        end else begin
            analog_out <= digital_in;
        end
    end

endmodule