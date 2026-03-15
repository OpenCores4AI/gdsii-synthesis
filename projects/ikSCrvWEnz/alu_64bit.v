// alu_64bit.v
// Elite Hardware Engineer: 64-bit Arithmetic Logic Unit (ALU)
// A synthesizable, registered ALU for a 64-bit processor core.

module alu_64bit (
    // System Inputs
    input wire clk,
    input wire reset,

    // Data Inputs
    input wire [63:0] operand_a,
    input wire [63:0] operand_b,
    input wire [3:0]  opcode,

    // Data Outputs
    output reg [63:0] result,

    // Status Flag Outputs
    output reg zero_flag,
    output reg carry_flag,
    output reg overflow_flag,
    output reg negative_flag
);

    // Opcode Definitions
    localparam OP_ADD  = 4'b0000;
    localparam OP_SUB  = 4'b0001;
    localparam OP_AND  = 4'b0010;
    localparam OP_OR   = 4'b0011;
    localparam OP_XOR  = 4'b0100;
    localparam OP_SLL  = 4'b0101; // Shift Left Logical
    localparam OP_SRL  = 4'b0110; // Shift Right Logical
    localparam OP_SRA  = 4'b0111; // Shift Right Arithmetic
    localparam OP_SLT  = 4'b1000; // Set on Less Than (signed)
    localparam OP_SLTU = 4'b1001; // Set on Less Than (unsigned)
    localparam OP_LUI  = 4'b1010; // Load Upper Immediate (conceptual)

    // Internal combinatorial signals
    reg [63:0] result_next;
    reg zero_flag_next;
    reg carry_flag_next;
    reg overflow_flag_next;
    reg negative_flag_next;
    
    // Extended signals for arithmetic carry/borrow
    wire [64:0] extended_a;
    wire [64:0] extended_b;
    wire [64:0] sum;
    wire [64:0] diff;

    assign extended_a = {1'b0, operand_a};
    assign extended_b = {1'b0, operand_b};
    assign sum = extended_a + extended_b;
    assign diff = extended_a - extended_b;

    // Combinatorial logic for ALU operations and flags
    always_comb begin
        // Default values
        result_next = 64'd0;
        carry_flag_next = 1'b0;
        overflow_flag_next = 1'b0;

        case (opcode)
            OP_ADD: begin
                result_next = sum[63:0];
                carry_flag_next = sum[64];
                // Overflow if signs of operands are same, but result sign is different
                overflow_flag_next = (operand_a[63] == operand_b[63]) && (result_next[63] != operand_a[63]);
            end
            OP_SUB: begin
                result_next = diff[63:0];
                carry_flag_next = ~diff[64]; // Not a borrow
                // Overflow if signs of operands are different, and result sign matches operand_b
                overflow_flag_next = (operand_a[63] != operand_b[63]) && (result_next[63] == operand_b[63]);
            end
            OP_AND: begin
                result_next = operand_a & operand_b;
            end
            OP_OR: begin
                result_next = operand_a | operand_b;
            end
            OP_XOR: begin
                result_next = operand_a ^ operand_b;
            end
            OP_SLL: begin
                result_next = operand_a << operand_b[5:0];
            end
            OP_SRL: begin
                result_next = operand_a >> operand_b[5:0];
            end
            OP_SRA: begin
                result_next = $signed(operand_a) >>> operand_b[5:0];
            end
            OP_SLT: begin
                result_next = ($signed(operand_a) < $signed(operand_b)) ? 64'd1 : 64'd0;
            end
            OP_SLTU: begin
                result_next = (operand_a < operand_b) ? 64'd1 : 64'd0;
            end
            OP_LUI: begin
                // This is a conceptual LUI, often handled differently in a full CPU.
                // Here it places B in the upper bits. A more typical LUI would use a 16 or 20-bit immediate.
                // For this example, we'll shift B left by 16.
                result_next = operand_b << 16;
            end
            default: begin
                result_next = 64'd0;
                carry_flag_next = 1'b0;
                overflow_flag_next = 1'b0;
            end
        endcase

        // Common flags calculated based on the result_next
        zero_flag_next = (result_next == 64'd0);
        negative_flag_next = result_next[63];
    end

    // Sequential logic to register the outputs
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 64'd0;
            zero_flag <= 1'b1;
            carry_flag <= 1'b0;
            overflow_flag <= 1'b0;
            negative_flag <= 1'b0;
        end else begin
            result <= result_next;
            zero_flag <= zero_flag_next;
            carry_flag <= carry_flag_next;
            overflow_flag <= overflow_flag_next;
            negative_flag <= negative_flag_next;
        end
    end

endmodule