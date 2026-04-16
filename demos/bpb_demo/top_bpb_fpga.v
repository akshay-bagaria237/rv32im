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
    
endmodule
