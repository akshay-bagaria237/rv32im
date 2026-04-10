`timescale 1ns/1ps

module divider (
    input               clk,
    input               reset,
    input               start,
    input  [31:0]       operand1,
    input  [31:0]       operand2,
    input  [2:0]        funct3,
    output reg [31:0]   result,
    output              busy
);

`include "opcode.vh"

localparam IDLE = 0, DIVIDE = 1, FINISH = 2;
reg [1:0] state;
reg [5:0] count;

reg [31:0] abs_op2;
reg [31:0] quotient_reg;
reg [31:0] remainder_reg;
reg        neg_quotient;
reg        neg_remainder;
reg [31:0] saved_operand1;
reg        saved_div_by_zero;
reg        saved_overflow;

assign busy = (state != IDLE) || start;

endmodule
