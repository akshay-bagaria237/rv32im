`timescale 1ns/1ps

module pipe
#(
    parameter [31:0] RESET = 32'h0000_0000,
    parameter IMEM_INIT_FILE = "C:/Users/Lenovo/Downloads/riscv-32im/riscv-32im.srcs/sources_1/imports/5-stage-version/imem_fpga.hex",
    parameter DMEM_INIT_FILE = "C:/Users/Lenovo/Downloads/riscv-32im/riscv-32im.srcs/sources_1/imports/5-stage-version/dmem_fpga.hex"
)
(
    input               clk,
    input               reset,
    input               stall,          
    input  [7:0]        sw,
    output              exception,
    output [31:0]       pc_out,
    output [31:0]       led_out,
    output [31:0]       l1_hit_count,
    output [31:0]       l1_miss_count,
    output reg [31:0]   cycle_count,
    output wire         uart_tx_en,
    output wire [7:0]   uart_tx_data,
    input wire          uart_tx_busy
);

`include "opcode.vh"

// --- Signal Declarations ---
wire stall_if, stall_id, stall_ex, stall_mem;
wire flush_if, flush_id, flush_ex, flush_mem;
wire branch_taken;
wire predict_dir; // BPB prediction from IF
wire load_use_hazard;
wire id_is_m_ext;

wire bp_mispredict; // Error detection from EX stage
wire ex_branch_out; // To be driven by execute stage



wire [31:0] if_pc, if_pc_plus4, if_instruction;
wire if_valid;

wire [31:0] id_pc, id_pc_plus4, id_rs1_data, id_rs2_data, id_immediate;
wire [4:0]  id_rs1_addr, id_rs2_addr, id_rd_addr;
wire [2:0]  id_funct3;
wire        id_funct7_bit5, id_alu_src, id_mem_write, id_mem_read, id_mem_to_reg, id_reg_write;
wire        id_branch, id_jal, id_jalr, id_lui, id_auipc, id_valid;
wire        id_is_fpu_ext;
wire [3:0]  id_fpu_op;
wire [4:0]  decode_rs1_addr, decode_rs2_addr;

wire [31:0] ex_pc_plus4, ex_alu_result, ex_rs2_data;
wire [4:0]  ex_rd_addr, ex_rs1_addr, ex_rs2_addr;
wire [2:0]  ex_funct3;
wire        ex_mem_write, ex_mem_read, ex_mem_to_reg, ex_reg_write, ex_valid, ex_stall_out;
wire [7:0]  ex_access_id;
wire [31:0] branch_target;

wire [31:0] mem_pc_plus4, mem_alu_result, mem_read_data, mem_forward_data;
wire [4:0]  mem_rd_addr;
wire [2:0]  mem_funct3;
wire        mem_mem_to_reg, mem_reg_write, mem_valid;

wire        wb_reg_write_en;
wire [4:0]  wb_rd_addr;
wire [31:0] wb_rd_data, wb_forward_data;

wire [31:0] reg_rdata1, reg_rdata2;

// --- Register File with Bypass ---
reg [31:0] regs [0:31];
integer i;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        for (i = 0; i < 32; i = i + 1) regs[i] <= 32'b0;
    end else if (wb_reg_write_en && (wb_rd_addr != 5'd0)) begin
        regs[wb_rd_addr] <= wb_rd_data;
    end
end

assign reg_rdata1 = (decode_rs1_addr == 5'd0) ? 32'd0 :
                    (wb_reg_write_en && (wb_rd_addr == decode_rs1_addr)) ? wb_rd_data :
                    regs[decode_rs1_addr];
assign reg_rdata2 = (decode_rs2_addr == 5'd0) ? 32'd0 :
                    (wb_reg_write_en && (wb_rd_addr == decode_rs2_addr)) ? wb_rd_data :
                    regs[decode_rs2_addr];

// --- Forwarding (Corrected Logic) ---
reg [1:0] f_a, f_b;
always @(*) begin
    f_a = 2'b00; f_b = 2'b00;
    
    // EX -> EX Forwarding (Instruction in MEM stage forwards to Instruction in EX stage)
    if (ex_reg_write && ex_valid && (ex_rd_addr != 0)) begin
        if (ex_rd_addr == id_rs1_addr) f_a = 2'b10;
        if (ex_rd_addr == id_rs2_addr) f_b = 2'b10;
    end
    
    // MEM -> EX Forwarding (Instruction in WB stage forwards to Instruction in EX stage)
    if (mem_reg_write && mem_valid && (mem_rd_addr != 0)) begin
        if (mem_rd_addr == id_rs1_addr && f_a == 2'b00) f_a = 2'b01;
        if (mem_rd_addr == id_rs2_addr && f_b == 2'b00) f_b = 2'b01;
    end
end

// --- Hazard Unit (Improved) ---
assign load_use_hazard = id_mem_read && id_valid && 
                        ((id_rd_addr == decode_rs1_addr) || (id_rd_addr == decode_rs2_addr)) && 
                        (id_rd_addr != 5'd0);

assign bp_mispredict = 1'b0; // TODO: Implement mispredict logic from execution stage 

wire mem_stall_req;
wire perf_active;
assign stall_if  = stall || load_use_hazard || ex_stall_out || mem_stall_req;
assign stall_id  = stall || ex_stall_out || mem_stall_req;
assign stall_ex  = stall || ex_stall_out || mem_stall_req;
assign stall_mem = stall || mem_stall_req;

assign flush_if  = branch_taken || bp_mispredict;
assign flush_id  = branch_taken || load_use_hazard || bp_mispredict;
assign flush_ex  = bp_mispredict;
assign flush_mem = 1'b0;

// --- Instances ---

// Branch Prediction Buffer (BPB)
bpb #(
    .INDEX_BITS(8)
) u_bpb (
    .clk(clk),
    .rst(~reset), // active-high reset required here based on active-low reset
    .read_pc(if_pc),
    .predict_dir(predict_dir),
    .update_pc(ex_pc_plus4 - 4), 
    .update_en(ex_valid && ex_branch_out),
    .update_dir(branch_taken)
);

fetch #(
    .INIT_FILE(IMEM_INIT_FILE)
) u_fetch (
    .clk(clk),.reset(reset),.stall(stall_if),.flush(flush_if),
    .branch_taken(branch_taken),.branch_target(branch_target),
    .pc_out(if_pc),.pc_plus4_out(if_pc_plus4),.instruction_out(if_instruction),
    .valid_out(if_valid),.current_pc(pc_out)
);

decode u_decode (
    .clk(clk),.reset(reset),.stall(stall_id),.flush(flush_id),
    .pc_in(if_pc),.pc_plus4_in(if_pc_plus4),.instruction_in(if_instruction),.valid_in(if_valid),
    .reg_rdata1(reg_rdata1),.reg_rdata2(reg_rdata2),
    .rs1_addr(decode_rs1_addr),.rs2_addr(decode_rs2_addr),
    .pc_out(id_pc),.pc_plus4_out(id_pc_plus4),.rs1_data_out(id_rs1_data),.rs2_data_out(id_rs2_data),
    .immediate_out(id_immediate),.rs1_addr_out(id_rs1_addr),.rs2_addr_out(id_rs2_addr),
    .rd_addr_out(id_rd_addr),.funct3_out(id_funct3),.funct7_bit5_out(id_funct7_bit5),
    .alu_src_out(id_alu_src),.mem_write_out(id_mem_write),.mem_read_out(id_mem_read),
    .mem_to_reg_out(id_mem_to_reg),.reg_write_out(id_reg_write),
    .branch_out(id_branch),.jal_out(id_jal),.jalr_out(id_jalr),
    .lui_out(id_lui),.auipc_out(id_auipc),.is_m_ext_out(id_is_m_ext),
    .is_fpu_ext_out(id_is_fpu_ext), .fpu_op_out(id_fpu_op), .valid_out(id_valid)
);

execute u_execute (
    .clk(clk),.reset(reset),.stall(stall_ex),.flush(flush_ex),
    .pc_in(id_pc),.pc_plus4_in(id_pc_plus4),
    .rs1_data_in(id_rs1_data),.rs2_data_in(id_rs2_data),.immediate_in(id_immediate),
    .rs1_addr_in(id_rs1_addr),.rs2_addr_in(id_rs2_addr),.rd_addr_in(id_rd_addr),
    .funct3_in(id_funct3),.funct7_bit5_in(id_funct7_bit5),
    .alu_src_in(id_alu_src),.mem_write_in(id_mem_write),.mem_read_in(id_mem_read),
    .mem_to_reg_in(id_mem_to_reg),.reg_write_in(id_reg_write),
    .branch_in(id_branch),.jal_in(id_jal),.jalr_in(id_jalr),
    .lui_in(id_lui),.auipc_in(id_auipc),.is_m_ext_in(id_is_m_ext),
    .is_fpu_ext_in(id_is_fpu_ext), .fpu_op_in(id_fpu_op), .valid_in(id_valid),
    .forward_ex_mem_data(mem_forward_data),.forward_mem_wb_data(wb_forward_data),
    .forward_a(f_a),.forward_b(f_b),
    .branch_taken(branch_taken),.branch_target(branch_target),
    .pc_plus4_out(ex_pc_plus4),.alu_result_out(ex_alu_result),.rs2_data_out(ex_rs2_data),
    .rd_addr_out(ex_rd_addr),.funct3_out(ex_funct3),
    .mem_write_out(ex_mem_write),.mem_read_out(ex_mem_read),
    .mem_to_reg_out(ex_mem_to_reg),.reg_write_out(ex_reg_write),.valid_out(ex_valid),
    .access_id_out(ex_access_id),
    .branch_out(ex_branch_out),
    .rs1_addr_out(ex_rs1_addr),.rs2_addr_out(ex_rs2_addr),.stall_out(ex_stall_out)
);

memory #(
    .DMEM_INIT_FILE(DMEM_INIT_FILE)
) u_memory (
    .clk(clk),.reset(reset),.stall(stall_mem),.flush(flush_mem),.sw(sw),
    .pc_plus4_in(ex_pc_plus4),.alu_result_in(ex_alu_result),.rs2_data_in(ex_rs2_data),
    .rd_addr_in(ex_rd_addr),.funct3_in(ex_funct3),
    .mem_write_in(ex_mem_write),.mem_read_in(ex_mem_read),
    .mem_to_reg_in(ex_mem_to_reg),.reg_write_in(ex_reg_write),.valid_in(ex_valid),
    .access_id_in(ex_access_id),
    .pc_plus4_out(mem_pc_plus4),.alu_result_out(mem_alu_result),.mem_read_data_out(mem_read_data),
    .rd_addr_out(mem_rd_addr),.funct3_out(mem_funct3),
    .mem_to_reg_out(mem_mem_to_reg),.reg_write_out(mem_reg_write),.valid_out(mem_valid),
    .mem_stall_req(mem_stall_req), // <-- Mapped Stall output
    .perf_active(perf_active),
    .forward_data(mem_forward_data),
    .led_out(led_out),
    .l1_hit_count(l1_hit_count),
    .l1_miss_count(l1_miss_count),
    .uart_tx_en(uart_tx_en),
    .uart_tx_data(uart_tx_data),
    .uart_tx_busy(uart_tx_busy)
);

writeback u_writeback (
    .clk(clk),.reset(reset),
    .pc_plus4_in(mem_pc_plus4),.alu_result_in(mem_alu_result),.mem_read_data_in(mem_read_data),
    .rd_addr_in(mem_rd_addr),.funct3_in(mem_funct3),
    .mem_to_reg_in(mem_mem_to_reg),.reg_write_in(mem_reg_write),.valid_in(mem_valid),
    .reg_write_en(wb_reg_write_en),.rd_addr(wb_rd_addr),.rd_data(wb_rd_data),
    .forward_data(wb_forward_data)
);

assign exception = 1'b0;

// Free-running cycle counter for live FPGA observability.
always @(posedge clk or negedge reset) begin
    if (!reset) cycle_count <= 32'd0;
    else if (perf_active) cycle_count <= cycle_count + 1'b1;
end

endmodule
