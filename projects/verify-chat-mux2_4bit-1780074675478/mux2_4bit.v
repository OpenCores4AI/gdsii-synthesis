// 4-bit 2-to-1 multiplexer, combinational
module mux2_4bit (
    input  [3:0] a,
    input  [3:0] b,
    input        sel,
    output [3:0] y
);
    // Combinational select: choose b when sel=1, otherwise a
    assign y = sel ? b : a;
endmodule
