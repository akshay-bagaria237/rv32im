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
endmodule
