`timescale 1ns/1ps

module execute
#(
    parameter [31:0] RESET = 32'h0000_0000
)
(
    input               clk,
    input               reset,
    input               stall,
    input               flush,
    
    input  [31:0]       pc_in,
    input  [31:0]       pc_plus4_in,
    input  [31:0]       rs1_data_in,
    input  [31:0]       rs2_data_in,
    input  [31:0]       immediate_in,
    input  [4:0]        rs1_addr_in,
    input  [4:0]        rs2_addr_in,
    input  [4:0]        rd_addr_in,
    input  [2:0]        funct3_in,
    input               funct7_bit5_in,
    
    input               alu_src_in,
    input               mem_write_in,
    input               mem_read_in,
    input               mem_to_reg_in,
    input               reg_write_in,
    input               branch_in,
    input               jal_in,
    input               jalr_in,
    input               lui_in,
    input               auipc_in,
    input               is_m_ext_in,
    input               is_fpu_ext_in,
    input  [3:0]        fpu_op_in,
    input               valid_in,
    
    input  [31:0]       forward_ex_mem_data,
    input  [31:0]       forward_mem_wb_data,
    input  [1:0]        forward_a,
    input  [1:0]        forward_b,
    
    output              branch_taken,
    output [31:0]       branch_target,
    
    output reg [31:0]   pc_plus4_out,
    output reg [31:0]   alu_result_out,
    output reg [31:0]   rs2_data_out,
    output reg [4:0]    rd_addr_out,
    output reg [2:0]    funct3_out,
    output reg          mem_write_out,
    output reg          mem_read_out,
    output reg          mem_to_reg_out,
    output reg          reg_write_out,
    output reg          valid_out,
    output reg [7:0]    access_id_out,
    
    output              branch_out,

    output [4:0]        rs1_addr_out,
    output [4:0]        rs2_addr_out,
    output              stall_out
);

`include "opcode.vh"

assign branch_out = branch_in;

reg [31:0] alu_operand1, alu_operand2_reg;
wire [31:0] alu_operand2;

always @(*) begin
    case (forward_a)
        2'b01:   alu_operand1 = forward_mem_wb_data;
        2'b10:   alu_operand1 = forward_ex_mem_data;
        default: alu_operand1 = rs1_data_in;
    endcase
    case (forward_b)
        2'b01:   alu_operand2_reg = forward_mem_wb_data;
        2'b10:   alu_operand2_reg = forward_ex_mem_data;
        default: alu_operand2_reg = rs2_data_in;
    endcase
end

assign alu_operand2 = alu_src_in ? immediate_in : alu_operand2_reg;
assign rs1_addr_out = rs1_addr_in;
assign rs2_addr_out = rs2_addr_in;

wire [31:0] mul_result, div_result, fpu_result;
wire        div_busy, fpu_ready;
reg         div_started, fpu_started;
reg  [7:0]  access_seq;
wire div_kick_start = is_m_ext_in && funct3_in[2] && !div_started && valid_in && !flush;
wire fpu_kick_start = is_fpu_ext_in && !fpu_started && valid_in && !flush;

// Invert reset for modules that expect active-high reset
wire rst_high = ~reset;


always @(posedge clk or negedge reset) begin
    if (!reset || flush) begin 
        div_started <= 0;
        fpu_started <= 0;
    end else begin
        if (div_kick_start) div_started <= 1;
        else if (div_started && !div_busy) div_started <= 0;
        
        if (fpu_kick_start) fpu_started <= 1;
        else if (fpu_started && fpu_ready) fpu_started <= 0;
    end
end

assign stall_out = (is_m_ext_in && funct3_in[2] && div_busy && valid_in) ||
                   (is_fpu_ext_in && !fpu_ready && valid_in);

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        access_seq <= 8'd0;
    end else if (!flush && !stall_out && !stall) begin
        access_seq <= access_seq + 1'b1;
    end
end

reg [31:0] alu_result_val;
wire [32:0] sub_res_s = {alu_operand1[31], alu_operand1} - {alu_operand2[31], alu_operand2};
wire [32:0] sub_res_u = {1'b0, alu_operand1} - {1'b0, alu_operand2};
wire is_sub = funct7_bit5_in && !alu_src_in;

always @(*) begin
    alu_result_val = 0;
    if (lui_in) alu_result_val = immediate_in;
    else if (auipc_in) alu_result_val = pc_in + immediate_in;
    else if (jal_in || jalr_in) alu_result_val = pc_plus4_in;
    else if (mem_write_in || mem_read_in) alu_result_val = alu_operand1 + alu_operand2; // Address calculation
    else begin
        case (funct3_in)
            ADD: alu_result_val = is_sub ? (alu_operand1 - alu_operand2) : (alu_operand1 + alu_operand2);
            SLL: alu_result_val = alu_operand1 << alu_operand2[4:0];
            SLT: alu_result_val = {31'b0, sub_res_s[32]};
            SLTU:alu_result_val = {31'b0, sub_res_u[32]};
            XOR: alu_result_val = alu_operand1 ^ alu_operand2;
            SR:  begin
                if (funct7_bit5_in) alu_result_val = $signed(alu_operand1) >>> alu_operand2[4:0];
                else alu_result_val = alu_operand1 >> alu_operand2[4:0];
            end
            OR:  alu_result_val = alu_operand1 | alu_operand2;
            AND: alu_result_val = alu_operand1 & alu_operand2;
            default: ;
        endcase
    end
end

reg [31:0] final_result;
always @(*) begin
    if (is_fpu_ext_in && valid_in) final_result = fpu_result;
    else if (is_m_ext_in && valid_in) final_result = funct3_in[2] ? div_result : mul_result;
    else final_result = alu_result_val;
end

reg branch_cond;
always @(*) begin
    branch_cond = 0;
    if (branch_in) begin
        case (funct3_in)
            BEQ:  branch_cond = (sub_res_s[31:0] == 0);
            BNE:  branch_cond = (sub_res_s[31:0] != 0);
            BLT:  branch_cond = sub_res_s[32];
            BGE:  branch_cond = !sub_res_s[32];
            BLTU: branch_cond = sub_res_u[32];
            BGEU: branch_cond = !sub_res_u[32];
            default: ;
        endcase
    end
end

assign branch_taken = valid_in && ((branch_in && branch_cond) || jal_in || jalr_in);
assign branch_target = jalr_in ? (alu_operand1 + immediate_in) & 32'hFFFFFFFE : pc_in + immediate_in;

always @(posedge clk or negedge reset) begin
    if (!reset || flush) begin
        pc_plus4_out <= 0; alu_result_out <= 0; rs2_data_out <= 0; rd_addr_out <= 0;
        funct3_out <= 0; mem_write_out <= 0; mem_read_out <= 0; mem_to_reg_out <= 0;
        reg_write_out <= 0; valid_out <= 0; access_id_out <= 8'd0;
    end else if (stall_out) begin
        valid_out <= 0;
        mem_write_out <= 0;
        reg_write_out <= 0;
    end else if (!stall) begin
        pc_plus4_out <= pc_plus4_in; alu_result_out <= final_result; rs2_data_out <= alu_operand2_reg;
        rd_addr_out <= rd_addr_in; funct3_out <= funct3_in; mem_write_out <= mem_write_in;
        mem_read_out <= mem_read_in; mem_to_reg_out <= mem_to_reg_in; reg_write_out <= reg_write_in;
        valid_out <= valid_in; access_id_out <= access_seq;
    end
end
endmodule
