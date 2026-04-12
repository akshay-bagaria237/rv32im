`timescale 1ns/1ps

module l1_cache #(
    parameter WAYS = 4,
    parameter SETS = 4
) (
    input clk,
    input rst,
    input [31:0] addr,
    input [31:0] wdata,
    input we,
    input re,
    output [31:0] rdata,
    output hit,
    output reg dirty_evict,
    output reg [31:0] evict_addr,
    output reg [31:0] evict_data
);
endmodule
