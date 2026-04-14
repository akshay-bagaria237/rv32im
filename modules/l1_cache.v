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

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < SETS; i = i + 1) begin
                replace_ptr[i] <= 0;
                for (j = 0; j < WAYS; j = j + 1) begin
                    valid_array[i][j] <= 0;
                    dirty_array[i][j] <= 0;
                end
            end
        end else begin
            dirty_evict <= 0;
            if (we && hit) begin
                if (hit0) begin data_array[index][0] <= wdata; dirty_array[index][0] <= 1; end
                else if (hit1) begin data_array[index][1] <= wdata; dirty_array[index][1] <= 1; end
                else if (hit2) begin data_array[index][2] <= wdata; dirty_array[index][2] <= 1; end
                else if (hit3) begin data_array[index][3] <= wdata; dirty_array[index][3] <= 1; end
            end 
            else if ((we || re) && !hit) begin
                // MISS: Evict and Allocate
                if (valid_array[index][replace_ptr[index]] && dirty_array[index][replace_ptr[index]]) begin
                    dirty_evict <= 1;
                    evict_addr <= {tag_array[index][replace_ptr[index]], index, 2'b00};
                    evict_data <= data_array[index][replace_ptr[index]];
                end
                
                valid_array[index][replace_ptr[index]] <= 1;
                tag_array[index][replace_ptr[index]]   <= tag;
                data_array[index][replace_ptr[index]]  <= wdata;
                dirty_array[index][replace_ptr[index]] <= we;
                replace_ptr[index] <= replace_ptr[index] + 1;
            end
        end
    end
endmodule
