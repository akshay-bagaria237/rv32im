`timescale 1ns / 1ps
module top_fpga #(
    parameter IMEMSIZE = 4096,
    parameter DMEMSIZE = 4096
)(
    input  wire clk,        // Fast board clock (100 MHz)
    input  wire reset,      // Active-low reset
    input  wire [2:0] sw,   // Slide switches [2:0]
    output [15:0] led,
    output reg [6:0] seg,   // 7-segment display segments (A-G)
    output reg [7:0] an     // 7-segment anodes (8 digits for Nexys A7)
);

wire [31:0] pc_display;
wire [31:0] led_display;
wire exception;
assign led = pc_display[15:0]; 

reg [25:0] clk_div;
always @(posedge clk or negedge reset) begin
    if (!reset) clk_div <= 0;
    else clk_div <= clk_div + 1;
end

wire slow_clk;
BUFG bufg_inst (
    .I(clk_div[23]),  // ~12 Hz for human-visible cache demo
    .O(slow_clk)
);

wire [31:0] l1_hit_cnt, l1_miss_cnt, cycle_cnt;

pipe pipe_u (
    .clk(slow_clk), .reset(reset), .stall(1'b0), .sw(sw),
    .exception(exception), .pc_out(pc_display), .led_out(led_display),
endmodule
