`timescale 1ns/1ps
module tb;
    reg        clk;
    reg        rst;
    reg        load;
    reg [7:0]  din;
    wire       serial_out;

    // DUT
    shift_reg8 dut (
        .clk(clk),
        .rst(rst),
        .load(load),
        .din(din),
        .serial_out(serial_out)
    );

    // Clock generation: 100 MHz
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Expected sequence tracking
    reg [7:0] exp;
    integer i;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);

        // Init
        rst  = 1'b1;
        load = 1'b0;
        din  = 8'h00;

        // Hold reset for two clock edges (synchronous)
        repeat (2) @(posedge clk);
        rst = 1'b0;

        // Prepare a one-cycle parallel load of known value
        @(negedge clk);
        din  = 8'hB6; // 1011_0110, MSB-first should be: 1 0 1 1 0 1 1 0
        load = 1'b1;

        // Load happens on this rising edge; serial_out still reflects pre-load MSB (0 after reset)
        @(posedge clk);
        if (serial_out !== 1'b0) begin
            $error("On load edge, expected serial_out=0 from pre-load register, got %0b", serial_out);
        end
        load = 1'b0;

        // Now verify 8 MSB-first bits starting next rising edge
        exp = 8'hB6;
        for (i = 7; i >= 0; i = i - 1) begin
            @(posedge clk);
            if (serial_out !== exp[i]) begin
                $error("Mismatch at bit %0d: expected %0b, got %0b", i, exp[i], serial_out);
            end else begin
                $display("Bit %0d OK: %0b", i, serial_out);
            end
        end

        // After 8 shifts, output should be zeros
        repeat (3) begin
            @(posedge clk);
            if (serial_out !== 1'b0) begin
                $error("Expected serial_out=0 after all bits shifted out, got %0b", serial_out);
            end
        end

        $display("All checks completed.");
        $finish;
    end
endmodule
