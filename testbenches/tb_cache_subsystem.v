`timescale 1ns/1ps

module tb_cache_subsystem;

    // Inputs
    reg clk;
    reg rst;

    // CPU IF Interface
    reg [31:0] cpu_if_addr;
    reg cpu_if_req;
    wire [31:0] cpu_if_rdata;
    wire cpu_if_ready;

    // CPU MEM Interface
    reg [31:0] cpu_mem_addr;
    reg [31:0] cpu_mem_wdata;
    reg cpu_mem_we;
    reg cpu_mem_req;
    wire [31:0] cpu_mem_rdata;
    wire cpu_mem_ready;

    // Instantiate Unit Under Test (UUT)
    cache_subsystem uut (
        .clk(clk),
        .rst(rst),
        
        .cpu_if_addr(cpu_if_addr),
        .cpu_if_req(cpu_if_req),
        .cpu_if_rdata(cpu_if_rdata),
        .cpu_if_ready(cpu_if_ready),
        
        .cpu_mem_addr(cpu_mem_addr),
        .cpu_mem_wdata(cpu_mem_wdata),
        .cpu_mem_we(cpu_mem_we),
        .cpu_mem_req(cpu_mem_req),
        .cpu_mem_rdata(cpu_mem_rdata),
        .cpu_mem_ready(cpu_mem_ready)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Statistics
    integer start_time, end_time, latency;
    integer pass_count = 0;
    integer fail_count = 0;

    // ------------- TASKS -------------
    
    // Write Data (Data Cache)
    task write_data;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            cpu_mem_addr = addr;
            cpu_mem_wdata = data;
            cpu_mem_we = 1'b1;
            cpu_mem_req = 1'b1;
            start_time = $time;
            
            @(posedge clk);
            while (!cpu_mem_ready) @(posedge clk);
            
            end_time = $time;
            latency = (end_time - start_time) / 10;
            $display("  [D-Write] Addr:%0h Data:%0h | Latency: %0d cycles", addr, data, latency);
            
            @(negedge clk);
            cpu_mem_req = 1'b0;
            cpu_mem_we = 1'b0;
        end
    endtask

    // Read Data (Data Cache) with Expectation & Max Latency checks
    task check_data_read;
        input [31:0] addr;
        input [31:0] expected;
        input integer max_latency; // Assert fail if it takes longer than this
        input [8*20:1] test_name;
        begin
            @(negedge clk);
            cpu_mem_addr = addr;
            cpu_mem_we = 1'b0;
            cpu_mem_req = 1'b1;
            start_time = $time;
            
            @(posedge clk);
            while (!cpu_mem_ready) @(posedge clk);
            
            end_time = $time;
            latency = (end_time - start_time) / 10;
            
            if (cpu_mem_rdata !== expected) begin
                $display("FAIL [%s]: Data mismatch at %0h. Exp: %0h, Got: %0h", test_name, addr, expected, cpu_mem_rdata);
                fail_count = fail_count + 1;
            end else if (latency > max_latency) begin
                $display("FAIL [%s]: Latency exceeded at %0h. Allowed: %0d, Got: %0d", test_name, addr, max_latency, latency);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [%s]: Addr:%0h, Got:%0h | Latency: %0d cycles", test_name, addr, cpu_mem_rdata, latency);
                pass_count = pass_count + 1;
            end
            
            @(negedge clk);
            cpu_mem_req = 1'b0;
        end
    endtask

    // Read Instruction (Instruction Cache)
    task check_inst_read;
        input [31:0] addr;
        input integer max_latency;
        input [8*20:1] test_name;
        begin
            @(negedge clk);
            cpu_if_addr = addr;
            cpu_if_req = 1'b1;
            start_time = $time;
            
            @(posedge clk);
            while (!cpu_if_ready) @(posedge clk);
            
            end_time = $time;
            latency = (end_time - start_time) / 10;
            
            if (latency > max_latency) begin
                $display("FAIL [%s] IF-Cache: Latency exceeded at %0h. Allowed: %0d, Got: %0d", test_name, addr, max_latency, latency);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS [%s] IF-Cache: Addr:%0h | Latency: %0d cycles", test_name, addr, latency);
                pass_count = pass_count + 1;
            end
            
            @(negedge clk);
            cpu_if_req = 1'b0;
        end
    endtask

    initial begin
        // Defaults
        clk = 0;
        rst = 1;
        cpu_if_addr = 0;
        cpu_if_req = 0;
        cpu_mem_addr = 0;
        cpu_mem_wdata = 0;
        cpu_mem_we = 0;
        cpu_mem_req = 0;

        $display("==================================================");
        $display("   STARTING CACHE HIERARCHY RIGOROUS TESTBENCH    ");
        $display("==================================================");

        // Reset system
        #100;
        @(negedge clk);
        rst = 0;
        
        $display("\n--- Phase 1: Basic Write & Read (Cold -> Warm) ---");
        // Write to an address (L1 invalidate, L2 write/allocate, Mem fetch)
        write_data(32'h0000_1000, 32'hDEADBEEF);
        
        // Read back (L1 miss, L2 hit -> L1 allocates) -> Should hit L2 (latency ~2-4)
        check_data_read(32'h0000_1000, 32'hDEADBEEF, 5, "L2 Hit, L1 Miss");
        
        // Read back again (L1 hit) -> Should take 1 cycle
        check_data_read(32'h0000_1000, 32'hDEADBEEF, 1, "L1 Warm Hit");


        $display("\n--- Phase 2: Write-back Evictions (Thrashing L2) ---");
        // L2 is 1KB (256 words). Stride 0x0400 hits the exact same index 0.
        // We write to 0x1000, 0x1400, 0x1800, 0x1C00.
        // These will all alias and evict each other in L2, forcing Dirty write-backs to L3.
        write_data(32'h0000_1400, 32'hCAFE_0001);
        write_data(32'h0000_1800, 32'hCAFE_0002);
        write_data(32'h0000_1C00, 32'hCAFE_0003); 
        // 0x1000 is now evicted from L2 to L3!
        
        // Read 0x1000 -> L1 miss, L2 miss, L3 hit!
        // Should take longer than L2 hit, but faster than Memory.
        check_data_read(32'h0000_1000, 32'hDEADBEEF, 10, "L3 Hit, L2/L1 Miss");


        $display("\n--- Phase 3: Total Eviction to Main Memory ---");
        // L3 is 4KB (stride 0x1000). 
        // Thrash L3 by writing to 0x1000, 0x2000, 0x3000, 0x4000.
        write_data(32'h0000_2000, 32'hBAAD_0001);
        write_data(32'h0000_3000, 32'hBAAD_0002);
        write_data(32'h0000_4000, 32'hBAAD_0003);
        // By now, L2 and L3 caches for index 0 are totally scrambled. 0x1000 is pushed down to L4.
        
        check_data_read(32'h0000_1000, 32'hDEADBEEF, 15, "L4 Hit, L3 Miss");
        check_data_read(32'h0000_1000, 32'hDEADBEEF, 1,  "L1 Re-arm Hit");


        $display("\n--- Phase 4: Instruction Cache Latency ---");
        // Read new instruction address (Cold Miss -> DRAM, > 10 cycles)
        check_inst_read(32'h0000_A000, 24, "IF Cold Miss");
        // Read same instruction address (Warm L1 Hit -> 1 cycle)
        check_inst_read(32'h0000_A000, 1,  "IF Warm Hit");


        $display("\n--- Phase 5: Arbiter Conflict ---");
        // Request I-Cache and D-Cache perfectly simultaneously
        @(negedge clk);
        cpu_if_addr = 32'h0000_B000;
        cpu_if_req  = 1'b1;
        
        cpu_mem_addr  = 32'h0000_C000;
        cpu_mem_wdata = 32'h5555_AAAA;
        cpu_mem_we    = 1'b1;
        cpu_mem_req   = 1'b1;
        
        // Wait for both to assert ready
        fork
            begin
                while (!cpu_if_ready) @(posedge clk);
                $display("  [Arbiter] IFachieved lock & finish.");
            end
            begin
                while (!cpu_mem_ready) @(posedge clk);
                $display("  [Arbiter] MEM achieved lock & finish.");
            end
        join
        
        // Check 0xC000 was written
        @(negedge clk);
        cpu_if_req = 1'b0;
        cpu_mem_req = 1'b0;
        @(negedge clk);
        check_data_read(32'h0000_C000, 32'h5555_AAAA, 5, "Arbiter Data Check");


        $display("\n--- Phase 6: Byte Offset Alignment Assurance ---");
        // Caches use the [31:2] bits for indexing and tags. Lower 2 bits should not affect hit/miss mapping isolation!
        // We write to word-aligned boundaries in the pipeline, but ensuring no interference.
        write_data(32'h0000_0104, 32'h11111111);
        write_data(32'h0000_0108, 32'h22222222);
        check_data_read(32'h0000_0104, 32'h11111111, 1, "Verify Align 1");
        check_data_read(32'h0000_0108, 32'h22222222, 1, "Verify Align 2");

        #50;
        $display("==================================================");
        $display("Final Cache Subsystem Tests: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("==================================================");
        $finish;
    end

endmodule
