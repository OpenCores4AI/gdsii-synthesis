/*
 * Complete single-file Verilog implementation of the RV32I Core
 */

// Module: alu
module alu(
    input wire [31:0] A,
    input wire [31:0] B,
    input wire [3:0] ALU_Ctrl,
    output reg [31:0] Result,
    output wire Zero
);
    always @(*) begin
        case (ALU_Ctrl)
            4'b0000: Result = A + B;  // ADD
            4'b0001: Result = A - B;  // SUB
            4'b0010: Result = A & B;  // AND
            4'b0011: Result = A | B;  // OR
            4'b0100: Result = A ^ B;  // XOR
            default: Result = 32'hxxxxxxxx;
        endcase
    end
    assign Zero = (Result == 32'h00000000);
endmodule

// Module: reg_file
module reg_file(
    input wire clk,
    input wire RegWrite,
    input wire [4:0] ReadAddr1,
    input wire [4:0] ReadAddr2,
    input wire [4:0] WriteAddr,
    input wire [31:0] WriteData,
    output wire [31:0] ReadData1,
    output wire [31:0] ReadData2
);
    reg [31:0] registers[31:1];

    assign ReadData1 = (ReadAddr1 == 5'b0) ? 32'b0 : registers[ReadAddr1];
    assign ReadData2 = (ReadAddr2 == 5'b0) ? 32'b0 : registers[ReadAddr2];

    always @(posedge clk) begin
        if (RegWrite && (WriteAddr != 5'b0)) begin
            registers[WriteAddr] <= WriteData;
        end
    end
endmodule

// Module: imm_gen
module imm_gen(
    input wire [31:0] instr,
    input wire [1:0] Imm_Sel, // 00:I, 01:S, 10:B
    output reg [31:0] ImmData
);
    always @(*) begin
        case (Imm_Sel)
            2'b00: ImmData = {{20{instr[31]}}, instr[31:20]}; // I-type
            2'b01: ImmData = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type
            2'b10: ImmData = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type
            default: ImmData = 32'hxxxxxxxx;
        endcase
    end
endmodule

// Module: control_unit
module control_unit(
    input wire [6:0] opcode,
    output reg ALUSrc,
    output reg MemtoReg,
    output reg RegWrite,
    output reg MemRead,
    output reg MemWrite,
    output reg Branch,
    output reg [1:0] Imm_Sel,
    output reg [1:0] ALUOp
);
    always @(*) begin
        // Default values
        ALUSrc = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead = 1'b0;
        MemWrite = 1'b0;
        Branch = 1'b0;
        Imm_Sel = 2'bxx;
        ALUOp = 2'bxx;

        case (opcode)
            7'b0110011: begin // R-type (ADD, SUB)
                ALUSrc = 1'b0;
                RegWrite = 1'b1;
                MemRead = 1'b0;
                MemWrite = 1'b0;
                ALUOp = 2'b10;
            end
            7'b0010011: begin // I-type (ADDI)
                ALUSrc = 1'b1;
                RegWrite = 1'b1;
                MemRead = 1'b0;
                MemWrite = 1'b0;
                Imm_Sel = 2'b00;
                ALUOp = 2'b00;
            end
            7'b0000011: begin // I-type (LW)
                ALUSrc = 1'b1;
                MemtoReg = 1'b1;
                RegWrite = 1'b1;
                MemRead = 1'b1;
                MemWrite = 1'b0;
                Imm_Sel = 2'b00;
                ALUOp = 2'b00;
            end
            7'b0100011: begin // S-type (SW)
                ALUSrc = 1'b1;
                RegWrite = 1'b0;
                MemRead = 1'b0;
                MemWrite = 1'b1;
                Imm_Sel = 2'b01;
                ALUOp = 2'b00;
            end
            7'b1100011: begin // B-type (BEQ)
                ALUSrc = 1'b0;
                Branch = 1'b1;
                RegWrite = 1'b0;
                MemRead = 1'b0;
                MemWrite = 1'b0;
                Imm_Sel = 2'b10;
                ALUOp = 2'b01;
            end
            default: begin
                RegWrite = 1'b0;
                MemRead = 1'b0;
                MemWrite = 1'b0;
            end
        endcase
    end
endmodule

// Module: instruction_memory (ROM)
module instruction_memory(
    input wire [31:0] Address,
    output wire [31:0] Instr
);
    reg [31:0] rom[1023:0];
    initial begin
        rom[0] = 32'h00500093; // addi x1, x0, 5
        rom[1] = 32'h00A00113; // addi x2, x0, 10
        rom[2] = 32'h002081B3; // add x3, x1, x2
        rom[3] = 32'h00302023; // sw x3, 0(x0)
    end
    assign Instr = rom[Address[11:2]];
endmodule

// Module: data_memory (RAM)
module data_memory(
    input wire clk,
    input wire MemWrite,
    input wire MemRead,
    input wire [31:0] Address,
    input wire [31:0] WriteData,
    output wire [31:0] ReadData
);
    reg [31:0] ram[1023:0];
    assign ReadData = MemRead ? ram[Address[11:2]] : 32'bz;
    always @(posedge clk) begin
        if (MemWrite) begin
            ram[Address[11:2]] <= WriteData;
        end
    end
endmodule

// Module: riscv_core (TOP LEVEL)
module riscv_core(
    input wire clk,
    input wire rst
);
    wire [31:0] pc, next_pc, pc_plus_4, pc_branch;
    wire [31:0] instruction;
    wire [31:0] reg_read_data1, reg_read_data2;
    wire [31:0] imm_ext;
    wire [31:0] alu_input_b;
    wire [31:0] alu_result;
    wire alu_zero;
    wire [31:0] mem_read_data;
    wire [31:0] reg_write_data;
    wire alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch;
    wire [1:0] imm_sel, alu_op;
    wire [3:0] alu_ctrl;
    wire pc_src;

    reg [31:0] pc_reg;
    assign pc = pc_reg;

    assign pc_plus_4 = pc + 32'd4;
    assign pc_branch = pc + imm_ext;
    assign pc_src = branch & alu_zero;
    assign next_pc = pc_src ? pc_branch : pc_plus_4;

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc_reg <= 32'h00000000;
        else
            pc_reg <= next_pc;
    end

    instruction_memory imem ( .Address(pc), .Instr(instruction) );

    control_unit ctrl (
        .opcode(instruction[6:0]),
        .ALUSrc(alu_src), .MemtoReg(mem_to_reg), .RegWrite(reg_write),
        .MemRead(mem_read), .MemWrite(mem_write), .Branch(branch),
        .Imm_Sel(imm_sel), .ALUOp(alu_op)
    );

    reg_file rf (
        .clk(clk), .RegWrite(reg_write),
        .ReadAddr1(instruction[19:15]), .ReadAddr2(instruction[24:20]),
        .WriteAddr(instruction[11:7]), .WriteData(reg_write_data),
        .ReadData1(reg_read_data1), .ReadData2(reg_read_data2)
    );

    imm_gen imm ( .instr(instruction), .Imm_Sel(imm_sel), .ImmData(imm_ext) );

    // ALU Control Decoder
    assign alu_ctrl = (alu_op == 2'b10) ? (instruction[30] ? 4'b0001 : 4'b0000) : 
                      (alu_op == 2'b01) ? 4'b0001 : 4'b0000;

    assign alu_input_b = alu_src ? imm_ext : reg_read_data2;
    
    alu main_alu (
        .A(reg_read_data1), .B(alu_input_b),
        .ALU_Ctrl(alu_ctrl), .Result(alu_result), .Zero(alu_zero)
    );

    data_memory dmem (
        .clk(clk), .MemWrite(mem_write), .MemRead(mem_read),
        .Address(alu_result), .WriteData(reg_read_data2),
        .ReadData(mem_read_data)
    );

    assign reg_write_data = mem_to_reg ? mem_read_data : alu_result;

endmodule
