`timescale 1ns / 1ps

module top_bpb_fpga #(
    parameter INDEX_BITS = 8
)(
    input  wire clk,        // 100 MHz board clock
    (* PACKAGE_PIN = "C12", IOSTANDARD = "LVCMOS33" *)
    input  wire reset_n,    // Active-low reset (CPU_RESETN)
    input  wire [2:0] sw,   // sw[0]: Step mode, sw[1]: Manual step
    output [15:0] led,
    output reg [6:0] seg,
    output reg [7:0] an     // 8 anodes for Nexys A7
);

    wire rst = !reset_n;      // reset_n is active-low on Nexys A7 CPU_RESETN

    
    // Clock divider for visible stepping
    reg [25:0] clk_div;
    always @(posedge clk or posedge rst) begin
        if (rst) clk_div <= 0;
        else clk_div <= clk_div + 1;
    end
    
    // Select trigger signal
    wire step_signal = sw[0] ? sw[1] : clk_div[23]; 
    
    // Edge detection for the step signal
    reg step_reg_sync, step_reg_prev;
    always @(posedge clk) begin
        step_reg_sync <= step_signal;
        step_reg_prev <= step_reg_sync;
    end
    wire step_edge = (step_reg_sync && !step_reg_prev); // Rising edge detection

    // ROM and Counters
    reg [8:0] trace_addr;
    wire [31:0] trace_pc;
    wire trace_outcome;
    reg [15:0] hit_count;
    reg [15:0] total_count;
    
    trace_rom rom_u (
        .addr(trace_addr),
        .pc(trace_pc),
        .outcome(trace_outcome)
    );

    // BPB instantiation
    wire predict_dir;
    reg update_en;
    
    bpb #(
        .INDEX_BITS(INDEX_BITS)
    ) bpb_u (
        .clk(clk),
        .rst(rst),
        .read_pc(trace_pc),
        .predict_dir(predict_dir),
        .update_pc(trace_pc),
        .update_en(update_en),
        .update_dir(trace_outcome)
    );

    // State machine
    reg [1:0] state;
    localparam S_READ   = 2'd0;
    localparam S_UPDATE = 2'd1;
    localparam S_WAIT   = 2'd2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            trace_addr <= 0;
            hit_count <= 0;
            total_count <= 0;
            update_en <= 0;
            state <= S_WAIT;
        end else begin
            case (state)
                S_WAIT: begin
                    update_en <= 0;
                    if (step_edge && total_count < 421) begin
                        state <= S_READ;
                    end
                end
                S_READ: begin
                    // Check prediction before update
                    if (predict_dir == trace_outcome) hit_count <= hit_count + 1;
                    total_count <= total_count + 1;
                    update_en <= 1; // Enable training
                    state <= S_UPDATE;
                end
                S_UPDATE: begin
                    update_en <= 0;
                    trace_addr <= trace_addr + 1;
                    state <= S_WAIT;
                end
            endcase
        end
    end

    // Accuracy: (hit * 100) / total
    wire [15:0] accuracy = (total_count == 0) ? 0 : (hit_count * 100) / total_count;
    assign led = accuracy;

    // 7-segment display logic
    reg [3:0] hex_digit;
    always @(*) begin
        an = 8'b11111111;
        case (clk_div[18:17])
            2'b00: begin an[0] = 0; hex_digit = accuracy % 10; end
            2'b01: begin an[1] = 0; hex_digit = (accuracy / 10) % 10; end
            2'b10: begin an[2] = 0; hex_digit = (accuracy / 100) % 10; end
            2'b11: begin an[3] = 0; hex_digit = 4'hF; end // Empty
        endcase
    end

    always @(*) begin
        case (hex_digit)
            4'h0: seg = 7'b1000000; 4'h1: seg = 7'b1111001; 4'h2: seg = 7'b0100100; 4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001; 4'h5: seg = 7'b0010010; 4'h6: seg = 7'b0000010; 4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000; 4'h9: seg = 7'b0010000; 
            default: seg = 7'b1111111; 
        endcase
    end
endmodule
