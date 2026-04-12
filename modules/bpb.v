`timescale 1ns/1ps

module bpb #(
    parameter INDEX_BITS = 8
) (
    input clk,
    input rst,
    input [31:0] read_pc,
    output predict_dir,
    
    input [31:0] update_pc,
    input update_en,
    input update_dir
);
endmodule
