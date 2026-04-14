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
    
    assign predict_dir = bht[read_idx][1]; // MSB is the prediction
    
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i=0; i<NUM_ENTRIES; i=i+1) begin
                bht[i] <= 2'b01; // Weakly not taken
            end
        end else if (update_en) begin
            case (bht[update_idx])
                2'b00: bht[update_idx] <= update_dir ? 2'b01 : 2'b00;
                2'b01: bht[update_idx] <= update_dir ? 2'b10 : 2'b00;
                2'b10: bht[update_idx] <= update_dir ? 2'b11 : 2'b01;
                2'b11: bht[update_idx] <= update_dir ? 2'b11 : 2'b10;
            endcase
        end
    end
endmodule
