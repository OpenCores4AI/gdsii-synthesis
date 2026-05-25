// alu4.v - 4-bit ALU with two's-complement overflow detection
module alu4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [2:0] op,   // 000 ADD, 001 SUB, 010 AND, 011 OR, 100 XOR, 101 PASS A, 110 SLL1, 111 SRL1
    output reg  [3:0] y,
    output reg        overflow
);
    always @* begin
        // Safe defaults
        y        = 4'b0000;
        overflow = 1'b0;

        case (op)
            3'b000: begin // ADD
                y        = a + b; // lower 4 bits
                overflow = (~(a[3] ^ b[3])) & (y[3] ^ a[3]);
            end
            3'b001: begin // SUB
                y        = a - b; // lower 4 bits
                overflow = (a[3] ^ b[3]) & (y[3] ^ a[3]);
            end
            3'b010: begin // AND
                y        = a & b;
                overflow = 1'b0;
            end
            3'b011: begin // OR
                y        = a | b;
                overflow = 1'b0;
            end
            3'b100: begin // XOR
                y        = a ^ b;
                overflow = 1'b0;
            end
            3'b101: begin // PASS A
                y        = a;
                overflow = 1'b0;
            end
            3'b110: begin // SLL1
                y        = a << 1; // {a[2:0], 1'b0}
                overflow = 1'b0;
            end
            3'b111: begin // SRL1
                y        = a >> 1; // {1'b0, a[3:1]}
                overflow = 1'b0;
            end
            default: begin
                y        = 4'b0000;
                overflow = 1'b0;
            end
        endcase
    end
endmodule
