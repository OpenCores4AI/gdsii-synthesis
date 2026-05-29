`timescale 1ns/1ps
module shift_reg8 (
    input  wire       clk,
    input  wire       rst,        // synchronous, active-high
    input  wire       load,       // parallel load enable (priority over shift)
    input  wire [7:0] din,        // parallel data input
    output reg        serial_out  // MSB-first serial output, registered
);
    reg [7:0] shreg;

    always @(posedge clk) begin
        if (rst) begin
            shreg      <= 8'd0;
            serial_out <= 1'b0;
        end else begin
            // Present current MSB on serial_out, then update shreg
            serial_out <= shreg[7];
            if (load) begin
                shreg <= din;                       // parallel load
            end else begin
                shreg <= {shreg[6:0], 1'b0};        // shift left, zero-fill LSB
            end
        end
    end
endmodule
