`timescale 1ns/1ps

module tb_fpga_cache_demo;
    reg clk;
    reg reset;
    reg [2:0] sw;

    wire exception;
    wire [31:0] pc_out;
    wire [31:0] led_out;
    wire [31:0] l1_hit_count;
    wire [31:0] l1_miss_count;
    wire [31:0] cycle_count;

    integer timeout;

    pipe dut (
        .clk(clk),
        .reset(reset),
        .stall(1'b0),
        .sw(sw),
        .exception(exception),
        .pc_out(pc_out),
        .led_out(led_out),
        .l1_hit_count(l1_hit_count),
        .l1_miss_count(l1_miss_count),
        .cycle_count(cycle_count)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        reset = 1'b0;
        sw = 3'b000;
        timeout = 0;

        #40;
        reset = 1'b1;

        while ((l1_hit_count + l1_miss_count) < 32'd10 && timeout < 5000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if ((l1_hit_count + l1_miss_count) !== 32'd10) begin
            $display("[ERROR] Timed out waiting for 10 cache accesses. hits=%0d misses=%0d", l1_hit_count, l1_miss_count);
            $fatal;
        end

        repeat (20) @(posedge clk);

        if (l1_hit_count !== 32'd6) begin
            $display("[ERROR] Expected 6 hits, got %0d", l1_hit_count);
            $fatal;
        end

        if (l1_miss_count !== 32'd4) begin
            $display("[ERROR] Expected 4 misses, got %0d", l1_miss_count);
            $fatal;
        end

        if (led_out[9:0] !== 10'h3FF) begin
            $display("[ERROR] Expected LED completion pattern 0x3FF, got 0x%0h", led_out[9:0]);
            $fatal;
        end

        $display("[OK] Deterministic FPGA cache demo reached 6 hits and 4 misses.");
        $finish;
    end
endmodule
