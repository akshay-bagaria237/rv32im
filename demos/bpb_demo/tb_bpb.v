`timescale 1ns / 1ps

module tb_bpb;
    parameter INDEX_BITS = 8;
    
    // Ports
    reg clk;
    reg rst;
    reg [31:0] read_pc;
    wire predict_dir;
    reg [31:0] update_pc;
    reg update_en;
    reg update_dir;

    // Counters
    integer total_branches = 0;
    integer correct_predictions = 0;
    real accuracy;
    
    // File I/O
    integer file;
    integer scan_status;
    reg [31:0] trace_pc;
    reg trace_outcome;

    // Instantiate BPB
    bpb #(
        .INDEX_BITS(INDEX_BITS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .read_pc(read_pc),
        .predict_dir(predict_dir),
        .update_pc(update_pc),
        .update_en(update_en),
        .update_dir(update_dir)
    );

    // Clock generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        read_pc = 0;
        update_pc = 0;
        update_en = 0;
        update_dir = 0;
        
endmodule
