`timescale 1ns/1ps
module tb;
    reg  a, b;
    wire sum, carry_out;
    half_adder dut (
        .a(a),
        .b(b),
        .sum(sum),
        .carry_out(carry_out)
    );
    reg clk = 0;
    always #5 clk = ~clk;
    integer i;
    reg exp_sum, exp_carry;
    initial begin
        $dumpfile("half_adder.vcd");
        $dumpvars(0, tb);
        for (i = 0; i < 4; i = i + 1) begin
            {a, b} = i[1:0];
            #1;
            exp_sum   = a ^ b;
            exp_carry = a & b;
            if (sum !== exp_sum) begin
                $error("SUM mismatch: a=%0b b=%0b -> got %0b expected %0b", a, b, sum, exp_sum);
            end
            if (carry_out !== exp_carry) begin
                $error("CARRY mismatch: a=%0b b=%0b -> got %0b expected %0b", a, b, carry_out, exp_carry);
            end
            $display("a=%0b b=%0b -> sum=%0b carry_out=%0b (ok)", a, b, sum, carry_out);
            #9;
        end
        $display("All combinations tested. Testbench completed.");
        $finish;
    end
endmodule
