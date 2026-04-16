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
        
        // Open trace file
        file = $fopen("branch_trace.txt", "r");
        if (file == 0) begin
            $display("Error: Could not open branch_trace.txt");
            $finish;
        end

        // Reset
        #20 rst = 0;
        #10;

        // Process trace
        while (!$feof(file)) begin
            scan_status = $fscanf(file, "%h %b\n", trace_pc, trace_outcome);
            if (scan_status == 2) begin
                total_branches = total_branches + 1;
                
                // Step 1: Read Prediction
                read_pc = trace_pc;
                #1; // Small delay to let combinatorial logic settle
                
                // Capture prediction BEFORE update
                if (predict_dir == trace_outcome) begin
                    correct_predictions = correct_predictions + 1;
                end
                
                // Step 2: Update/Train BPB on next clock edge
                update_pc = trace_pc;
                update_dir = trace_outcome;
                update_en = 1;
                
                @(posedge clk);
                #2; // Hold time
                update_en = 0;
            end
        end

        // Results
        if (total_branches > 0) begin
            accuracy = (correct_predictions * 100.0) / total_branches;
            $display("\n--- BPB Test Results ---");
            $display("Total branches: %d", total_branches);
            $display("Correct predictions: %d", correct_predictions);
            $display("Accuracy: %0.2f%%", accuracy);
            $display("------------------------\n");
        end else begin
            $display("No branches processed.");
        end

        $fclose(file);
        $finish;
    end

endmodule
