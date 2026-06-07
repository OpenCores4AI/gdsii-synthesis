`timescale 1ns/1ps
`default_nettype none

module tb;
    reg  a, b;
    wire sum, carry_out;

    // DUT instantiation
    half_adder dut (
        .a(a),
        .b(b),
        .sum(sum),
        .carry_out(carry_out)
    );

    integer i;
    reg exp_sum, exp_carry;

    initial begin
        $dumpfile("half_adder.vcd");
        $dumpvars(0, tb);

        // Initialize
        a = 1'b0;
        b = 1'b0;
        #1;

        // Walk all four input combinations: 00, 01, 10, 11
        for (i = 0; i < 4; i = i + 1) begin
            a = (i >> 1) & 1'b1; // MSB
            b = (i >> 0) & 1'b1; // LSB
            #1; // allow signals to propagate

            exp_sum   = a ^ b;
            exp_carry = a & b;

            if (sum !== exp_sum || carry_out !== exp_carry) begin
                $error("Mismatch at vector %0d: a=%0b b=%0b -> sum=%0b carry=%0b (expected sum=%0b carry=%0b)",
                       i, a, b, sum, carry_out, exp_sum, exp_carry);
                $fatal;
            end
        end

        $display("All half-adder test vectors passed.");
        $finish;
    end
endmodule

`default_nettype wire
