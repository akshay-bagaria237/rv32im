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
    wire [1:0]  index = addr[3:2];
    wire [27:0] tag   = addr[31:4];
    
    reg [31:0] data_array  [0:SETS-1][0:WAYS-1];
    reg [27:0] tag_array   [0:SETS-1][0:WAYS-1];
    reg        valid_array [0:SETS-1][0:WAYS-1];
    reg        dirty_array [0:SETS-1][0:WAYS-1];

    reg [1:0] replace_ptr [0:SETS-1];

endmodule
