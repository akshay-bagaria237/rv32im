`timescale 1ns/1ps

module fetch
#(
    parameter [31:0] RESET = 32'h0000_0000,
    parameter INIT_FILE = "C:/Users/Lenovo/Downloads/riscv-32im/riscv-32im.srcs/sources_1/imports/5-stage-version/imem_fpga.hex"
)
(
    input               clk,
    input               reset,
    input               stall,
    input               flush,
    input               branch_taken,
    input  [31:0]       branch_target,
    output reg [31:0]   pc_out,
    output reg [31:0]   pc_plus4_out,
    output reg [31:0]   instruction_out,
    output reg          valid_out,
    output [31:0]       current_pc
);

`include "opcode.vh"

reg [31:0] pc;
wire [31:0] pc_next;

// Internal memory for instructions
(* ram_style = "distributed" *) reg [31:0] imem [0:1023];
initial begin
    if (INIT_FILE != "") begin
        $readmemh(INIT_FILE, imem);
    end
end

wire l1_hit;
wire [31:0] l1_rdata;
wire [31:0] instruction_rom = imem[pc[11:2]];

wire [31:0] fetch_instruction = instruction_rom;

// Wait, reset is active low (!reset). So req = 1 when running
assign current_pc = pc;

assign pc_next = branch_taken ? branch_target : pc + 4;

wire effective_stall = stall;

always @(posedge clk or negedge reset) begin
    if (!reset) pc <= RESET;
    else if (!effective_stall) pc <= pc_next;
end

always @(posedge clk or negedge reset) begin
    if (!reset || flush) begin
        pc_out <= 0;
        pc_plus4_out <= 0;
        instruction_out <= NOP;
        valid_out <= 0;
    end else if (!effective_stall) begin
        pc_out <= pc;
        pc_plus4_out <= pc + 4;
        instruction_out <= fetch_instruction;
        valid_out <= 1;
    end
end

endmodule
