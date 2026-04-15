`timescale 1ns / 1ps

module tb_fpu;

    reg clk;
    reg rst;
    reg start;
    reg [3:0] op;
    reg [31:0] a;
    reg [31:0] b;
    wire [31:0] result;
    wire ready;

    // Cycle tracking
    integer cycles;
    integer start_cycle;
    integer total_cycles;

    // Instantiate the FPU
    fpu uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .op(op),
        .a(a),
        .b(b),
        .out(result),
        .rm(3'b000),
        .fflags(),
        .ready(ready)
    );

    // Clock generation
    initial begin
        clk = 0;
        cycles = 0;
        forever begin
            #5 clk = ~clk;
            if (clk) cycles = cycles + 1;
        end
    end

    // Task to run a single test and evaluate the result
    task run_test;
        input [3:0] test_op;
        input [31:0] test_a;
        input [31:0] test_b;
        input [31:0] expected_result;
        input [8*25:1] test_desc; 
        reg [40:0] op_name;
        begin
            case (test_op)
                4'd0: op_name  = "FADD ";
                4'd1: op_name  = "FSUB ";
                4'd2: op_name  = "FLR  ";
                4'd3: op_name  = "CEIL ";
                4'd4: op_name  = "RND  ";
                4'd5: op_name  = "FMUL ";
                4'd6: op_name  = "FDIV ";
                4'd7: op_name  = "FMIN ";
endmodule
