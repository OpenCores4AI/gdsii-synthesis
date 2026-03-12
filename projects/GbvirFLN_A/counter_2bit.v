// A simple 2-bit synchronous counter with enable and reset
module counter_2bit (
    // Inputs
    input wire clk,
    input wire reset,
    input wire enable,
    // Outputs
    output wire [1:0] q
);

    // Internal register to hold the count value
    reg [1:0] count_reg;

    // Synchronous logic block
    always @(posedge clk) begin
        if (reset) begin
            // On reset, set the counter to 0
            count_reg <= 2'b00;
        end else if (enable) begin
            // If enabled, increment the counter
            count_reg <= count_reg + 1;
        end
        // If not reset and not enabled, the register holds its value
    end

    // Assign the internal register to the output port
    assign q = count_reg;

endmodule
