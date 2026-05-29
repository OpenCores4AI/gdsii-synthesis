`timescale 1ns/1ps
// Self-checking testbench for mux2_4bit
module tb;
    reg  [3:0] a, b;
    reg        sel;
    wire [3:0] y;

    // Patterns
    reg [3:0] avals [0:5];
    reg [3:0] bvals [0:5];
    integer i;
    reg [3:0] exp;

    mux2_4bit dut (
        .a(a),
        .b(b),
        .sel(sel),
        .y(y)
    );

    initial begin
        $dumpfile("mux2_4bit.vcd");
        $dumpvars(0, tb);

        // Initialize stimulus patterns
        avals[0]=4'h0; bvals[0]=4'hF;
        avals[1]=4'h5; bvals[1]=4'hA;
        avals[2]=4'hA; bvals[2]=4'h5;
        avals[3]=4'hF; bvals[3]=4'h0;
        avals[4]=4'h3; bvals[4]=4'hC;
        avals[5]=4'hC; bvals[5]=4'h3;

        // Defaults
        a = 0; b = 0; sel = 0; #1;

        // Walk both select values for each pattern
        for (i = 0; i < 6; i = i + 1) begin
            a = avals[i];
            b = bvals[i];

            sel = 0; #1;
            exp = a;
            if (y !== exp) begin
                $error("Mismatch sel=0 @i=%0d: a=%h b=%h -> y=%h exp=%h", i, a, b, y, exp);
            end

            sel = 1; #1;
            exp = b;
            if (y !== exp) begin
                $error("Mismatch sel=1 @i=%0d: a=%h b=%h -> y=%h exp=%h", i, a, b, y, exp);
            end
        end

        $display("All tests completed.");
        $finish;
    end
endmodule
