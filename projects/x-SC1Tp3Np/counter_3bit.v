module counter_3bit (
    input  wire       clk,    // Clock input
    input  wire       reset,  // Synchronous active-high reset
    input  wire       enable, // Enable counting on posedge clk
    output wire [2:0] q       // 3-bit counter output
);

    // Internal register to hold the count value
    reg [2:0] count_reg;

    // Synchronous logic for counting
    always @(posedge clk) begin
        if (reset) begin
            // On reset, clear the counter to 0
            count_reg <= 3'b000;
        end else if (enable) begin
            // If enabled, increment the counter
            count_reg <= count_reg + 1;
        end
        // If not reset and not enabled, the register holds its value (implicit)
    end

    // Assign the internal register to the output port
    assign q = count_reg;

endmodule