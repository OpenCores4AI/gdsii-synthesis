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

    integer i;
    reg expected_sum, expected_carry;

    initial begin
        $dumpfile("half_adder_tb.vcd");
        $dumpvars(0, tb);

        a = 1'b0; b = 1'b0;
        #1;

        for (i = 0; i < 4; i = i + 1) begin
            a = i[0];
            b = i[1];
            #1;

            expected_sum   = a ^ b;
            expected_carry = a & b;

            if (sum !== expected_sum || carry_out !== expected_carry) begin
                $error("Mismatch for a=%0b b=%0b: got sum=%0b carry=%0b, expected sum=%0b carry=%0b",
                       a, b, sum, carry_out, expected_sum, expected_carry);
            end else begin
                $display("OK: a=%0b b=%0b -> sum=%0b carry=%0b", a, b, sum, carry_out);
            end
        end

        $display("All half-adder tests completed.");
        $finish;
    end
endmodule
