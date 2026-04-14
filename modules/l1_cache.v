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

    // --- COMBINATORIAL HIT DETECTION ---
    wire hit0 = valid_array[index][0] && (tag_array[index][0] == tag);
    wire hit1 = valid_array[index][1] && (tag_array[index][1] == tag);
    wire hit2 = valid_array[index][2] && (tag_array[index][2] == tag);
    wire hit3 = valid_array[index][3] && (tag_array[index][3] == tag);
    
    assign hit = (re || we) ? (hit0 || hit1 || hit2 || hit3) : 1'b0;
    
    assign rdata = hit0 ? data_array[index][0] :
                   hit1 ? data_array[index][1] :
                   hit2 ? data_array[index][2] :
                   hit3 ? data_array[index][3] : 32'h0;

    integer i, j;
    initial begin
        for (i = 0; i < SETS; i = i + 1) begin
            replace_ptr[i] = 0;
            for (j = 0; j < WAYS; j = j + 1) begin
                valid_array[i][j] = 0;
                dirty_array[i][j] = 0;
                tag_array[i][j] = 0;
                data_array[i][j] = 0;
            end
        end
    end

endmodule
