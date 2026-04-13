`timescale 1ns/1ps
module fpu(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [3:0] op,    // 0=fadd, 1=fsub, 2=floor, 3=ceil, 4=round, 5=fmul, 6=fdiv, 7=fmin, 8=fmax, 9=feq, 10=flt, 11=fle
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [2:0] rm,    // rounding mode
    output reg [31:0] out,
    output reg ready,
    output reg [4:0] fflags // nv, dz, of, uf, nx
);

    // -------------------------------------------------------------------------
    // Simple Multi-Cycle FPU (Best for Cycle Time & Easy to Read)
    // -------------------------------------------------------------------------
    
    localparam IDLE           = 3'd0;
    localparam ALIGN_MUL_DIV  = 3'd1;
    localparam ADD            = 3'd2;
    localparam NORM           = 3'd3;
    localparam DIVIDE_LOOP    = 3'd4;

    reg [2:0] state;
    reg sign_a, sign_b, sign_res;
    reg [8:0] exp_a, exp_b;
    reg signed [9:0] exp_res; // Extra bits for overflow/underflow checks
    reg [24:0] mant_a, mant_b, mant_res;
    
    reg [47:0] div_P; // For multi-cycle division
    reg [47:0] div_A;
    reg [5:0] div_count;
    
    // Combinational helpers for single-cycle operations
    wire [8:0] exp_diff_ab = exp_a - exp_b;
    wire [8:0] exp_diff_ba = exp_b - exp_a;
    reg [4:0] shift_amt;
    reg [24:0] shifted_mant;

    // Rounding specific combinational logic
    function [31:0] compute_round;
        input [31:0] a;
        input [3:0] op;
        reg r_sign;
        reg [7:0] r_exp;
        reg [22:0] r_mant;
        reg [4:0] mask_shift;
        reg [23:0] frac_mask;
        reg [23:0] mant_mask;
endmodule
