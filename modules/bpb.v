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

    localparam NUM_ENTRIES = 1 << INDEX_BITS;
    reg [1:0] bht [0:NUM_ENTRIES-1];
    
    wire [INDEX_BITS-1:0] read_idx = read_pc[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] update_idx = update_pc[INDEX_BITS+1:2];
endmodule
