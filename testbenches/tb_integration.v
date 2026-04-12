`timescale 1ns/1ps

module tb_bpb_cache;
    reg clk;
    reg rst;
    
    // ==========================================
    // 1. BPB Signals (Branch Prediction Buffer)
    // ==========================================
    reg [31:0] read_pc, update_pc;
    reg update_en, update_dir;
    wire predict_dir;
    
    bpb #(.INDEX_BITS(8)) dut_bpb (
        .clk(clk), .rst(rst), 
        .read_pc(read_pc), .predict_dir(predict_dir),
        .update_pc(update_pc), .update_en(update_en), .update_dir(update_dir)
    );
    
    // ==========================================
    // 2. L1 Cache Signals (128 Lines, 7-bit Idx)
    // ==========================================
    reg [31:0] l1_addr, l1_wdata;
    reg l1_we, l1_re;
    wire [31:0] l1_rdata;
    wire l1_hit;
    
    l1_cache dut_l1 (
        .clk(clk), .rst(rst), 
        .addr(l1_addr), .wdata(l1_wdata), .we(l1_we), .re(l1_re),
        .rdata(l1_rdata), .hit(l1_hit)
    );

    // ==========================================
    // 3. L2 Cache Signals (512 Lines, 9-bit Idx)
    // ==========================================
    reg [31:0] l2_addr, l2_wdata;
    reg l2_we, l2_re;
    wire [31:0] l2_rdata;
    wire l2_hit;

    l2_cache dut_l2 (
        .clk(clk), .rst(rst), 
        .addr(l2_addr), .wdata(l2_wdata), .we(l2_we), .re(l2_re),
        .rdata(l2_rdata), .hit(l2_hit)
    );
    
    // ==========================================
    // Testing Automation Variables
    // ==========================================
    integer pass_count = 0;
    integer fail_count = 0;

    task run_test;
        input [500:0] test_name;
        input [31:0] expected_result;
        input [31:0] actual_result;
        begin
            if (expected_result == actual_result) begin
                $display("[PASS] %s", test_name);
endmodule
