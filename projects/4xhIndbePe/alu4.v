`timescale 1ns/1ps
`default_nettype none

// 4-bit ALU with carry, overflow, zero flags
module alu4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [2:0] op,     // 000=ADD, 001=SUB, 010=AND, 011=OR, 100=XOR
    output reg  [3:0] y,
    output reg        carry,      // ADD: carry-out; SUB: 1 = no borrow, 0 = borrow
    output reg        overflow,   // Two's complement overflow for ADD/SUB
    output wire       zero
);

    // Precompute arithmetic paths
    wire [4:0] add5  = {1'b0, a} + {1'b0, b};
    wire [3:0] add4  = add5[3:0];
    wire       add_c = add5[4];
    wire       add_v = (a[3] == b[3]) && (add4[3] != a[3]);

    wire [4:0] sub5  = {1'b0, a} + {1'b0, ~b} + 5'b00001; // a - b = a + (~b) + 1
    wire [3:0] sub4  = sub5[3:0];
    wire       sub_c = sub5[4]; // 1 = no borrow, 0 = borrow
    wire       sub_v = (a[3] != b[3]) && (sub4[3] != a[3]);

    // Logic ops
    wire [3:0] and4 = a & b;
    wire [3:0] or4  = a | b;
    wire [3:0] xor4 = a ^ b;

    // Opcode map
    localparam [2:0] OP_ADD = 3'b000;
    localparam [2:0] OP_SUB = 3'b001;
    localparam [2:0] OP_AND = 3'b010;
    localparam [2:0] OP_OR  = 3'b011;
    localparam [2:0] OP_XOR = 3'b100;

    always @* begin
        // Safe defaults
        y        = 4'b0000;
        carry    = 1'b0;
        overflow = 1'b0;

        case (op)
            OP_ADD: begin
                y        = add4;
                carry    = add_c;
                overflow = add_v;
            end
            OP_SUB: begin
                y        = sub4;
                carry    = sub_c;   // 1 = no borrow
                overflow = sub_v;
            end
            OP_AND: begin
                y        = and4;
                carry    = 1'b0;
                overflow = 1'b0;
            end
            OP_OR: begin
                y        = or4;
                carry    = 1'b0;
                overflow = 1'b0;
            end
            OP_XOR: begin
                y        = xor4;
                carry    = 1'b0;
                overflow = 1'b0;
            end
            default: begin
                y        = 4'b0000;
                carry    = 1'b0;
                overflow = 1'b0;
            end
        endcase
    end

    assign zero = (y == 4'b0000);

endmodule

`default_nettype wire
