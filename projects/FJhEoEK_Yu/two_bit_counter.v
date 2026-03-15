// two_bit_counter.v
// A simple 2-bit synchronous counter with asynchronous reset and enable.

module two_bit_counter (
    input wire clk,          // Clock input
    input wire reset,        // Asynchronous reset input (active-high)
    input wire enable,       // Enable counting
    output wire [1:0] count_out // 2-bit counter output
);

    // Internal register to hold the count value
    reg [1:0] count_reg;

    // Sequential logic for counting
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Asynchronously reset the counter to 0
            count_reg <= 2'b00;
        end else if (enable) begin
            // Increment the counter on the positive clock edge if enabled
            count_reg <= count_reg + 1;
        end
        // If not reset and not enabled, the register holds its value.
    end

    // Assign the internal register value to the output
    assign count_out = count_reg;

endmodule
