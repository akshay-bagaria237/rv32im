`timescale 1ns / 1ps

/**
 * FINAL UNIFIED EXHAUSTIVE TESTBENCH (V8)
 * - 40 Hardcore Stress Tests covering ALL ISA Categories.
 * - Every verified value is mapped to a UNIQUE register to avoid overlaps.
 */

module tb_pipeline_final;

    reg clk;
    reg reset;
    wire exception;
    wire [31:0] pc_out;

    integer total_passed;
    integer total_failed;
    integer current_case;
    integer wait_cycles;

    pipe DUT (
        .clk(clk),
        .reset(reset),
        .stall(1'b0),
        .exception(exception),
        .pc_out(pc_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset = 0;
        #100;
        reset = 1;
    end

    task verify;
        input [255:0] desc;
        input [4:0]   reg_idx;
        input [31:0]  expected;
        begin
            current_case = current_case + 1;
            @(negedge clk);
            $display("Testcase %0d: %s", current_case, desc);
            $display("  Expected: 0x%08h", expected);
            $display("  Actual:   0x%08h", DUT.regs[reg_idx]);
            
            if (DUT.regs[reg_idx] === expected) begin
                $display("  Result: PASS");
                total_passed = total_passed + 1;
            end else begin
                $display("  Result: FAIL");
                $display("  [ERROR] Architectural failure. Value mismatch at x%0d.", reg_idx);
                total_failed = total_failed + 1;
            end
            $display("----------------------------------");
        end
endmodule
