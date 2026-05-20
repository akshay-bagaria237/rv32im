`timescale 1ns/1ps

// L2 Cache - 4-Way Set Associative
module l2_cache #(
    parameter WAYS = 4,
    parameter TOTAL_LINES = 32,
    parameter SETS = TOTAL_LINES / WAYS // 8 Sets
) (
    input clk,
    input rst,
    input cache_bypass,
    input [31:0] addr,
    input [31:0] wdata,
    input we,
    input re,
    output reg [31:0] rdata,
    output reg hit
);
    // 8 Sets = 3 bits of index (addr[4:2])
    // Tag Bits: 32 - 3 - 2 = 27 Tag Bits (addr[31:5])
    wire [2:0]  index = addr[4:2];  
    wire [26:0] tag   = addr[31:5]; 

    // Create 4 parallel ways for Data, Tag, and Valid bits
    reg [31:0] data_array_0 [0:SETS-1];
    reg [31:0] data_array_1 [0:SETS-1];
    reg [31:0] data_array_2 [0:SETS-1];
    reg [31:0] data_array_3 [0:SETS-1];

    reg [26:0] tag_array_0 [0:SETS-1];
    reg [26:0] tag_array_1 [0:SETS-1];
    reg [26:0] tag_array_2 [0:SETS-1];
    reg [26:0] tag_array_3 [0:SETS-1];

    reg valid_array_0 [0:SETS-1];
    reg valid_array_1 [0:SETS-1];
    reg valid_array_2 [0:SETS-1];
    reg valid_array_3 [0:SETS-1];

    // Pseudo-Random Replacement Counter
    reg [1:0] replace_way;
    
    integer s;

    // Initialize valid bits for FPGA BRAM inference
    initial begin
        for (s=0; s<SETS; s=s+1) begin
            valid_array_0[s] = 0;
            valid_array_1[s] = 0;
            valid_array_2[s] = 0;
            valid_array_3[s] = 0;
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            replace_way <= 0;
        end else begin
            replace_way <= replace_way + 1;

            if (we && !cache_bypass) begin
                // Update Hit
                if      (valid_array_0[index] && tag_array_0[index] == tag) data_array_0[index] <= wdata;
                else if (valid_array_1[index] && tag_array_1[index] == tag) data_array_1[index] <= wdata;
                else if (valid_array_2[index] && tag_array_2[index] == tag) data_array_2[index] <= wdata;
                else if (valid_array_3[index] && tag_array_3[index] == tag) data_array_3[index] <= wdata;
                // Miss: Empty Fill
                else if (!valid_array_0[index]) begin valid_array_0[index] <= 1; tag_array_0[index] <= tag; data_array_0[index] <= wdata; end
                else if (!valid_array_1[index]) begin valid_array_1[index] <= 1; tag_array_1[index] <= tag; data_array_1[index] <= wdata; end
                else if (!valid_array_2[index]) begin valid_array_2[index] <= 1; tag_array_2[index] <= tag; data_array_2[index] <= wdata; end
                else if (!valid_array_3[index]) begin valid_array_3[index] <= 1; tag_array_3[index] <= tag; data_array_3[index] <= wdata; end
                // Miss: Evict Random
                else begin
                    case (replace_way)
                        2'b00: begin valid_array_0[index] <= 1; tag_array_0[index] <= tag; data_array_0[index] <= wdata; end
                        2'b01: begin valid_array_1[index] <= 1; tag_array_1[index] <= tag; data_array_1[index] <= wdata; end
                        2'b10: begin valid_array_2[index] <= 1; tag_array_2[index] <= tag; data_array_2[index] <= wdata; end
                        2'b11: begin valid_array_3[index] <= 1; tag_array_3[index] <= tag; data_array_3[index] <= wdata; end
                    endcase
                end
            end
        end
    end
    
    // READ LOGIC (Combinational check of all 4 ways)
    always @(*) begin
        hit = 0;
        rdata = 32'h0;
        
        if (!cache_bypass && (re || we)) begin
            if (valid_array_0[index] && tag_array_0[index] == tag) begin hit = 1; rdata = data_array_0[index]; end
            else if (valid_array_1[index] && tag_array_1[index] == tag) begin hit = 1; rdata = data_array_1[index]; end
            else if (valid_array_2[index] && tag_array_2[index] == tag) begin hit = 1; rdata = data_array_2[index]; end
            else if (valid_array_3[index] && tag_array_3[index] == tag) begin hit = 1; rdata = data_array_3[index]; end
        end
    end
endmodule