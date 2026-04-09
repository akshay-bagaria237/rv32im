`timescale 1ns/1ps

module multiplier (
    input  [31:0] operand1,
    input  [31:0] operand2,
    input  [2:0]  funct3,
    output [31:0] result
);

`include "opcode.vh"

wire [63:0] m_s_s = $signed(operand1) * $signed(operand2);
endmodule
