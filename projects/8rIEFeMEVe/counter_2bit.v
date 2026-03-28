// A 2-bit synchronous up-counter with active-low reset.

module counter_2bit (
    input wire clk,
    input wire rst_n,
    output reg [1:0] count_out
);

    // This block handles the synchronous logic.
    // It triggers on the positive edge of the clock or the negative edge of the reset.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // On active-low reset, the counter is cleared to 0.
            count_out <= 2'b00;
        end else begin
            // On a clock edge, the counter increments.
            // It will automatically wrap around from 3 (11) to 0 (00).
            count_out <= count_out + 1;
        end
    end

endmodule
