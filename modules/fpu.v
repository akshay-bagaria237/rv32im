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
    
endmodule
