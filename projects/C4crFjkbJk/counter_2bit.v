// 2-bit Synchronous Counter with Active-Low Asynchronous Reset and Enable
// File: counter_2bit.v

module counter_2bit (
    input  logic clk,      // Clock input
    input  logic rst_n,    // Active-low asynchronous reset
    input  logic enable,   // Enable counting
    output logic [1:0] count // 2-bit counter output
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 2'b00; // Asynchronous reset to 0
        end else begin
            if (enable) begin
                count <= count + 1; // Increment on enable
            end
            // If enable is low, the value is held implicitly
        end
    end

endmodule
