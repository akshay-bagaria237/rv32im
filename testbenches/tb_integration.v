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
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %s | Expected: %h, Got: %h", test_name, expected_result, actual_result);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $display("========================================");
        $display(" STARTING FULL HIERARCHICAL TEST SUITE  ");
        $display("========================================");
        
        // ------------------------------------------
        // PHASE 1: BPB COMMON & EDGE CASES
        // ------------------------------------------
        rst = 1;
        update_en = 0; l1_we = 0; l1_re = 0; l2_we = 0; l2_re = 0;
        read_pc = 32'h0000_1000; update_pc = 32'h0; update_dir = 0;
        #25 rst = 0;

        // Test 1: Cold State
        run_test("Test 1: BPB Initial State Returns Weakly Not Taken (0)", 32'h0, predict_dir);
        
        // Edge Case: 2-bit counter saturation climbing
        update_pc = 32'h0000_1000; update_en = 1; update_dir = 1; #10; update_en = 0; read_pc = 32'h0000_1000; #10;
        run_test("Test 2: BPB Correctly transitions 01 -> 10 (Weak Taken)", 32'h1, predict_dir);

        update_en = 1; #10; update_en = 0; read_pc = 32'h0000_1000; #10;
        run_test("Test 3: BPB Correctly transitions 10 -> 11 (Strong Taken)", 32'h1, predict_dir);

        update_en = 1; #10; update_en = 0; read_pc = 32'h0000_1000; #10;
        run_test("Test 4: BPB Saturates at 11 (Cannot overflow to 00)", 32'h1, predict_dir);

        // Edge Case: 2-bit counter saturation descending
        update_dir = 0; // Not taken
        update_en = 1; #10; update_en = 0; read_pc = 32'h0000_1000; #10;
        run_test("Test 5: BPB Recovers 11 -> 10 (Weakly Taken)", 32'h1, predict_dir);

        update_en = 1; #10; update_en = 0; read_pc = 32'h0000_1000; #10;
        run_test("Test 6: BPB Recovers 10 -> 01 (Weakly Not Taken)", 32'h0, predict_dir);

        update_en = 1; #10; update_en = 0; read_pc = 32'h0000_1000; #10;
        run_test("Test 7: BPB Descends 01 -> 00 (Strongly Not Taken)", 32'h0, predict_dir);

        update_en = 1; #10; update_en = 0; read_pc = 32'h0000_1000; #10;
        run_test("Test 8: BPB Saturates at 00 (Cannot underflow to 11)", 32'h0, predict_dir);

        // Edge Case: Aliasing Collision
        // 0x1000 -> Bits[9:2] are 0000_0000.  0x2000 -> Bits[9:2] are 0000_0000.
        read_pc = 32'h0000_2000; #10;
        run_test("Test 9: BPB Successfully handles index aliasing", 32'h0, predict_dir);


        // ------------------------------------------
endmodule
