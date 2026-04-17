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
endmodule
