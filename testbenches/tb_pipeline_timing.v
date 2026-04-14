`timescale 1ns/1ps

module tb_pipeline_timing;

    reg clk;
    reg reset;
    reg stall;
    wire exception;
    wire [31:0] pc_out;

    // Instantiate the pipeline
    pipe dut (
        .clk(clk),
        .reset(reset),
        .stall(stall),
        .exception(exception),
        .pc_out(pc_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instruction memory for lookup (for logging)
    reg [31:0] imem [0:1023];
    
    // Improved function to return full instruction strings
    function [255:0] get_instr_str(input [31:0] instr);
        reg [6:0] opcode;
        reg [2:0] f3;
        reg [6:0] f7;
        reg [4:0] rd, rs1, rs2;
        reg [31:0] imm;
        reg [127:0] mnem;
        begin
            opcode = instr[6:0];
            f3 = instr[14:12];
            f7 = instr[31:25];
            rd = instr[11:7];
            rs1 = instr[19:15];
            rs2 = instr[24:20];
            
            if (instr == 32'h0000_0013) get_instr_str = "nop";
            else if (instr == 0) get_instr_str = "bubble";
            else begin
                case (opcode)
                    7'b0110111: begin // LUI
                        imm = {instr[31:12], 12'b0};
endmodule
