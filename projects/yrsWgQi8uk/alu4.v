`timescale 1ns/1ps
`default_nettype none

module alu4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [2:0] op,     // 000 ADD, 001 SUB, 010 AND, 011 OR, 100 XOR, 101 SLL1, 110 SRL1, 111 PASS A
    output reg  [3:0] y,
    output reg        carry_out,   // For ADD: carry; For SUB: no-borrow (carry from a + ~b + 1). 0 for others.
    output reg        overflow,    // Two's complement overflow for ADD/SUB; 0 for others.
    output wire       zero
);

    // 5-bit intermediates to capture carry
    wire [4:0] add5 = {1'b0, a} + {1'b0, b};
    wire [4:0] sub5 = {1'b0, a} + {1'b0, ~b} + 5'b00001;

    // Signed overflow detection for 4-bit two's complement
    wire ovf_add = (~(a[3] ^ b[3])) & (a[3] ^ add5[3]);
    wire ovf_sub =  (a[3] ^ b[3])  & (a[3] ^ sub5[3]);

    // Main combinational ALU
    always @* begin
        // defaults
        y         = 4'b0000;
        carry_out = 1'b0;
        overflow  = 1'b0;

        case (op)
            3'b000: begin // ADD
                y         = add5[3:0];
                carry_out = add5[4];
                overflow  = ovf_add;
            end
            3'b001: begin // SUB (a - b) = a + (~b + 1)
                y         = sub5[3:0];
                carry_out = sub5[4]; // "no borrow" when 1
                overflow  = ovf_sub;
            end
            3'b010: begin // AND
                y = a & b;
            end
            3'b011: begin // OR
                y = a | b;
            end
            3'b100: begin // XOR
                y = a ^ b;
            end
            3'b101: begin // SLL1
                y = {a[2:0], 1'b0};
            end
            3'b110: begin // SRL1
                y = {1'b0, a[3:1]};
            end
            3'b111: begin // PASS A
                y = a;
            end
            default: begin
                y = 4'b0000;
            end
        endcase
    end

    assign zero = (y == 4'b0000);

endmodule

`default_nettype wire
