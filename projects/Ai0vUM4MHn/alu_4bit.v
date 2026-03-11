module alu_4bit (
    input wire [3:0] a,
    input wire [3:0] b,
    input wire [2:0] opcode,
    output reg [3:0] result,
    output reg overflow_flag,
    output reg zero_flag
);

    // Internal wire to hold the 5-bit result for arithmetic operations
    wire [4:0] temp_result_add, temp_result_sub;
    wire signed_overflow_add, signed_overflow_sub;

    // Perform addition and subtraction in parallel to derive results and flags
    assign temp_result_add = {a[3], a} + {b[3], b};
    assign temp_result_sub = {a[3], a} - {b[3], b};

    // Overflow detection for signed two's complement arithmetic
    // Overflow on ADD: signs of operands are the same, but sign of result is different.
    assign signed_overflow_add = (a[3] == b[3]) && (temp_result_add[3] != a[3]);
    // Overflow on SUB: signs of operands are different, and sign of result is same as B's.
    assign signed_overflow_sub = (a[3] != b[3]) && (temp_result_sub[3] == b[3]);


    // Combinational logic block for ALU operations
    always @* begin
        // Default assignments
        result = 4'b0000;
        overflow_flag = 1'b0;

        case (opcode)
            // 3'b000: ADD
            3'b000: begin
                result = temp_result_add[3:0];
                overflow_flag = signed_overflow_add;
            end
            // 3'b001: SUB
            3'b001: begin
                result = temp_result_sub[3:0];
                overflow_flag = signed_overflow_sub;
            end
            // 3'b010: AND
            3'b010: begin
                result = a & b;
                overflow_flag = 1'b0;
            end
            // 3'b011: OR
            3'b011: begin
                result = a | b;
                overflow_flag = 1'b0;
            end
            // 3'b100: XOR
            3'b100: begin
                result = a ^ b;
                overflow_flag = 1'b0;
            end
            // 3'b101: NOT A
            3'b101: begin
                result = ~a;
                overflow_flag = 1'b0;
            end
            // 3'b110: Shift Left Logical A by 1
            3'b110: begin
                result = a << 1;
                overflow_flag = 1'b0;
            end
            // 3'b111: Shift Right Logical A by 1
            3'b111: begin
                result = a >> 1;
                overflow_flag = 1'b0;
            end
            default: begin
                result = 4'bxxxx;
                overflow_flag = 1'bx;
            end
        endcase
    end

    // Zero flag logic is independent of the operation
    // It is asserted if the final result is zero.
    assign zero_flag = (result == 4'b0000);

endmodule