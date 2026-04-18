`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////
// Top FPGA Module for 5-Stage RISC-V Pipeline
// Memories are integrated in fetch (imem) and memory (dmem) stages
//////////////////////////////////////////////////////////////
module top_fpga #(
    parameter IMEMSIZE = 4096,
    parameter DMEMSIZE = 4096
)(
    input  wire clk,        // Fast board clock (e.g. 100 MHz)
    input  wire reset,      // Active-low reset
    input  wire [2:0] sw,   // Slide switches [2:0]
    output [15:0] led,
    output reg [6:0] seg,   // 7-segment display segments (A-G)
    output reg [7:0] an     // 7-segment anodes (8 digits for Nexys A7)
);

//////////////////////////////////////////////////////////////
// Drive the board LEDs from the CPU PC
//////////////////////////////////////////////////////////////
wire [31:0] pc_display;
wire [31:0] led_display;
wire exception;
assign led = pc_display[15:0]; // Show lower 16 bits of PC on LEDs

//////////////////////////////////////////////////////////////
// Clock Divider for FPGA observation (approx 1 Hz to 2 Hz with 100MHz clock)
//////////////////////////////////////////////////////////////
reg [25:0] clk_div;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        clk_div <= 0;
    end else begin
        clk_div <= clk_div + 1;
    end
end

// Use a Global Clock Buffer (BUFG) for the slow clock 
// to ensure it routes cleanly on the FPGA clock tree, 
// avoiding clock skew that can cause erratic/fast glitches.
wire slow_clk;
BUFG bufg_inst (
    .I(clk_div[23]),  // ~11.9 Hz from 100 MHz for visible but responsive execution
    .O(slow_clk)
);

//////////////////////////////////////////////////////////////
// 5-Stage Pipeline CPU
// (instruction and data memories are integrated inside)
//////////////////////////////////////////////////////////////
wire [31:0] l1_hit_cnt;
wire [31:0] l1_miss_cnt;
wire [31:0] cycle_cnt;

pipe pipe_u (
    .clk        (slow_clk),
    .reset      (reset),
    .stall      (1'b0),
    .sw         (sw), // Pass slide switches into pipeline for MMIO reading
    .exception  (exception),
    .pc_out     (pc_display),
    .led_out    (led_display),
    .l1_hit_count (l1_hit_cnt),
    .l1_miss_count(l1_miss_cnt),
    .cycle_count(cycle_cnt)
);

//////////////////////////////////////////////////////////////
// 7-Segment Display Controller (Hexadecimal rendering)
//////////////////////////////////////////////////////////////
// Display mode:
// If sw[2] is 1, display led_display (Program Output)
// If sw[2] is 0, use sw[1:0] for metrics: 00->hits, 01->misses, 10->req, 11->cycles.
wire [31:0] req_cnt = l1_hit_cnt + l1_miss_cnt;
wire [15:0] value_to_display = (sw[2]) ? led_display[15:0] :
                               (sw[1:0] == 2'b00) ? l1_hit_cnt[15:0]  :
                               (sw[1:0] == 2'b01) ? l1_miss_cnt[15:0] :
                               (sw[1:0] == 2'b10) ? req_cnt[15:0]     :
                                                    cycle_cnt[15:0];

reg [1:0] seg_sel;         // To select which of the 4 digits to refresh
always @(posedge clk or negedge reset) begin
    if (!reset) seg_sel <= 0;
    else if (clk_div[16:0] == 0) seg_sel <= seg_sel + 1; // Slow refresh rate for multiplexing
end
endmodule
