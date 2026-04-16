`timescale 1ns / 1ps

module tb_fpu;

    reg clk;
    reg rst;
    reg start;
    reg [3:0] op;
    reg [31:0] a;
    reg [31:0] b;
    wire [31:0] result;
    wire ready;

    // Cycle tracking
    integer cycles;
    integer start_cycle;
    integer total_cycles;

    // Instantiate the FPU
    fpu uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .op(op),
        .a(a),
        .b(b),
        .out(result),
        .rm(3'b000),
        .fflags(),
        .ready(ready)
    );

    // Clock generation
    initial begin
        clk = 0;
        cycles = 0;
        forever begin
            #5 clk = ~clk;
            if (clk) cycles = cycles + 1;
        end
    end

    // Task to run a single test and evaluate the result
    task run_test;
        input [3:0] test_op;
        input [31:0] test_a;
        input [31:0] test_b;
        input [31:0] expected_result;
        input [8*25:1] test_desc; 
        reg [40:0] op_name;
        begin
            case (test_op)
                4'd0: op_name  = "FADD ";
                4'd1: op_name  = "FSUB ";
                4'd2: op_name  = "FLR  ";
                4'd3: op_name  = "CEIL ";
                4'd4: op_name  = "RND  ";
                4'd5: op_name  = "FMUL ";
                4'd6: op_name  = "FDIV ";
                4'd7: op_name  = "FMIN ";
                4'd8: op_name  = "FMAX ";
                4'd9: op_name  = "FEQ  ";
                4'd10: op_name = "FLT  ";
                4'd11: op_name = "FLE  ";
                4'd12: op_name = "FCTWS";
                4'd13: op_name = "FCWUS";
                4'd14: op_name = "FCTSW";
                4'd15: op_name = "FCSWU";
                default: op_name = "UNKWN";
            endcase

            @(posedge clk);
            a = test_a;
            b = test_b;
            op = test_op;
            #1;
            start = 1;
            start_cycle = cycles;

            @(posedge clk);
            #1;
            start = 0;

            // Wait until the operation is done
            wait(ready == 1);
            #1; // Delay to ensure NBA region completes (result stabilization)
            total_cycles = cycles - start_cycle;

            if (result !== expected_result) begin
                $display("[FAIL] %s | %s | A:%h B:%h | Exp:%h Got:%h | Cycles: %d", op_name, test_desc, test_a, test_b, expected_result, result, total_cycles);
            end else begin
                $display("[PASS] %s | %s | A:%h B:%h | Result:%h | Cycles: %d", op_name, test_desc, test_a, test_b, result, total_cycles);
            end
            
            @(posedge clk);
            #10;
        end
    endtask

    initial begin
        // Initialize Inputs
        start = 0;
        op = 0;
        a = 0;
        b = 0;
        rst = 1;

        // Reset the FPU
        #20;
        rst = 0;
        #20;

        $display("\n=========================================================================");
        $display("                     FPU COMPREHENSIVE TEST SUITE ");
        $display("=========================================================================\n");

        $display("-------------------------------------------------------------------------");
        $display(" 1. FADD / FSUB Arithmetic Tests");
        $display("-------------------------------------------------------------------------");
        // Basics
        run_test(4'd0, 32'h3FC00000, 32'h40200000, 32'h40800000, "1.5 + 2.5 = 4.0          ");
        run_test(4'd0, 32'h40800000, 32'hC0800000, 32'h00000000, "4.0 + (-4.0) = 0.0       ");
        run_test(4'd1, 32'h40800000, 32'h3FC00000, 32'h40200000, "4.0 - 1.5 = 2.5          ");
        run_test(4'd1, 32'h40800000, 32'h40800000, 32'h00000000, "4.0 - 4.0 = 0.0          ");
        // Negatives and zeros
        run_test(4'd0, 32'h00000000, 32'h80000000, 32'h00000000, "0.0 + (-0.0) = 0.0       ");
        run_test(4'd0, 32'hC0000000, 32'hC0400000, 32'hC0A00000, "-2.0 + (-3.0) = -5.0     ");
        run_test(4'd1, 32'h00000000, 32'h40A00000, 32'hC0A00000, "0.0 - 5.0 = -5.0         ");
        run_test(4'd1, 32'hC0000000, 32'hC0400000, 32'h3F800000, "-2.0 - (-3.0) = 1.0      ");
        // Large differences
        run_test(4'd0, 32'h4B189680, 32'h3F800000, 32'h4B189680, "1M + 1.0 = ~1M           ");
        
        $display("-------------------------------------------------------------------------");
        $display(" 2. FMUL / FDIV Arithmetic Tests");
        $display("-------------------------------------------------------------------------");
        // Basics
        run_test(4'd5, 32'h40000000, 32'h40400000, 32'h40C00000, "2.0 * 3.0 = 6.0          ");
        run_test(4'd5, 32'hC0000000, 32'h40400000, 32'hC0C00000, "-2.0 * 3.0 = -6.0        ");
        run_test(4'd6, 32'h40C00000, 32'h40000000, 32'h40400000, "6.0 / 2.0 = 3.0          ");
        run_test(4'd6, 32'h40A00000, 32'h40000000, 32'h40200000, "5.0 / 2.0 = 2.5          ");
        // Negatives and Fractions
        run_test(4'd5, 32'h3F800000, 32'hBF800000, 32'hBF800000, "1.0 * -1.0 = -1.0        ");
        run_test(4'd5, 32'hC0000000, 32'hC0000000, 32'h40800000, "-2.0 * -2.0 = 4.0        ");
        run_test(4'd6, 32'h3F800000, 32'h40000000, 32'h3F000000, "1.0 / 2.0 = 0.5          ");
        run_test(4'd6, 32'hC0C00000, 32'hC0000000, 32'h40400000, "-6.0 / -2.0 = 3.0        ");

        $display("-------------------------------------------------------------------------");
        $display(" 3. FFLOOR Tests (Rounds to negative infinity)");
        $display("-------------------------------------------------------------------------");
        run_test(4'd2, 32'h402CCCCD, 32'h00000000, 32'h40000000, "floor(2.7) = 2.0         ");
        run_test(4'd2, 32'h40000000, 32'h00000000, 32'h40000000, "floor(2.0) = 2.0         ");
        run_test(4'd2, 32'hC02CCCCD, 32'h00000000, 32'hC0400000, "floor(-2.7) = -3.0       ");
        run_test(4'd2, 32'h00000000, 32'h00000000, 32'h00000000, "floor(0.0) = 0.0         ");
        run_test(4'd2, 32'h3F000000, 32'h00000000, 32'h00000000, "floor(0.5) = 0.0         ");
        run_test(4'd2, 32'hBF000000, 32'h00000000, 32'hBF800000, "floor(-0.5) = -1.0       ");
        run_test(4'd2, 32'h3E99999A, 32'h00000000, 32'h00000000, "floor(0.3) = 0.0         ");
        run_test(4'd2, 32'hBE99999A, 32'h00000000, 32'hBF800000, "floor(-0.3) = -1.0       ");

        $display("-------------------------------------------------------------------------");
        $display(" 4. FCEIL Tests (Rounds to positive infinity)");
        $display("-------------------------------------------------------------------------");
        run_test(4'd3, 32'h40133333, 32'h00000000, 32'h40400000, "ceil(2.3) = 3.0          ");
        run_test(4'd3, 32'h40000000, 32'h00000000, 32'h40000000, "ceil(2.0) = 2.0          ");
        run_test(4'd3, 32'hC0133333, 32'h00000000, 32'hC0000000, "ceil(-2.3) = -2.0        ");
        run_test(4'd3, 32'h00000000, 32'h00000000, 32'h00000000, "ceil(0.0) = 0.0          ");
        run_test(4'd3, 32'h3F000000, 32'h00000000, 32'h3F800000, "ceil(0.5) = 1.0          ");
        run_test(4'd3, 32'hBF000000, 32'h00000000, 32'h80000000, "ceil(-0.5) = -0.0        ");
        run_test(4'd3, 32'h3E99999A, 32'h00000000, 32'h3F800000, "ceil(0.3) = 1.0          ");
        run_test(4'd3, 32'hBE99999A, 32'h00000000, 32'h80000000, "ceil(-0.3) = -0.0        ");

        $display("-------------------------------------------------------------------------");
        $display(" 5. FROUND Tests (Rounds to nearest, ties to even)");
        $display("-------------------------------------------------------------------------");
        run_test(4'd4, 32'h40133333, 32'h00000000, 32'h40000000, "round(2.3) = 2.0         ");
        run_test(4'd4, 32'h402CCCCD, 32'h00000000, 32'h40400000, "round(2.7) = 3.0         ");
        run_test(4'd4, 32'h40200000, 32'h00000000, 32'h40000000, "round(2.5) = 2.0(even)   "); 
        run_test(4'd4, 32'h40600000, 32'h00000000, 32'h40800000, "round(3.5) = 4.0(even)   ");
        run_test(4'd4, 32'hC0200000, 32'h00000000, 32'hC0000000, "round(-2.5) = -2.0(even) ");
        run_test(4'd4, 32'h3F000000, 32'h00000000, 32'h00000000, "round(0.5) = 0.0(even)   ");
        run_test(4'd4, 32'h3F800000, 32'h00000000, 32'h3F800000, "round(1.0) = 1.0         ");

        $display("-------------------------------------------------------------------------");
        $display(" 6. Edge Cases (Zeroes, Infinity, NaN)");
        $display("-------------------------------------------------------------------------");
        run_test(4'd0, 32'h7F800000, 32'h40000000, 32'h7F800000, "Inf + 2.0 = Inf          ");
        run_test(4'd0, 32'hFF800000, 32'hC0000000, 32'hFF800000, "-Inf + -2.0 = -Inf       ");
        run_test(4'd5, 32'h40000000, 32'h00000000, 32'h00000000, "2.0 * 0.0 = 0.0          ");
        run_test(4'd5, 32'h7F800000, 32'h40000000, 32'h7F800000, "Inf * 2.0 = Inf          ");
        run_test(4'd6, 32'h40000000, 32'h00000000, 32'h7F800000, "2.0 / 0.0 = Inf          ");
        run_test(4'd6, 32'hC0000000, 32'h00000000, 32'hFF800000, "-2.0 / 0.0 = -Inf        ");
endmodule
