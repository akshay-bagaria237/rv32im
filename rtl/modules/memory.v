`timescale 1ns/1ps

module memory
#(
    parameter [31:0] RESET = 32'h0000_0000,
    parameter DMEM_INIT_FILE = "C:/Users/Lenovo/Downloads/riscv-32im/riscv-32im.srcs/sources_1/imports/5-stage-version/dmem_fpga.hex"
)
(
    input               clk,
    input               reset,
    input               stall,
    input               flush,
    input  [7:0]        sw,
    
    input  [31:0]       pc_plus4_in,
    input  [31:0]       alu_result_in,
    input  [31:0]       rs2_data_in,
    input  [4:0]        rd_addr_in,
    input  [2:0]        funct3_in,
    
    input               mem_write_in,
    input               mem_read_in,
    input               mem_to_reg_in,
    input               reg_write_in,
    input               valid_in,
    input  [7:0]        access_id_in,
    
    output reg [31:0]   pc_plus4_out,
    output reg [31:0]   alu_result_out,
    output reg [31:0]   mem_read_data_out,
    output reg [4:0]    rd_addr_out,
    output reg [2:0]    funct3_out,
    
    output reg          mem_to_reg_out,
    output reg          reg_write_out,
    output reg          valid_out,
    output reg          mem_stall_req, 
    output              perf_active,
    
    output [31:0]       forward_data,
    output reg [31:0]   led_out,
    output reg [31:0]   l1_hit_count,
    output reg [31:0]   l1_miss_count,
    
    output wire         uart_tx_en,
    output wire [7:0]   uart_tx_data,
    input wire          uart_tx_busy
);

`include "opcode.vh"

wire [31:0] mem_addr = alu_result_in;
wire [1:0]  byte_offset = mem_addr[1:0];

// Internal Data Memory
(* ram_style = "distributed" *) reg [31:0] dmem [0:1023];

initial begin
    if (DMEM_INIT_FILE != "") begin
        $readmemh(DMEM_INIT_FILE, dmem);
    end
end

wire [31:0] dcache_addr = {mem_addr[31:2], 2'b00};

// Declarations moved up to fix warnings
reg         last_counted_valid;
reg  [7:0]  last_counted_access_id;

wire is_mmio_write  = (dcache_addr == 32'h8000_0000) && mem_write_in;
wire is_mmio_read   = (dcache_addr == 32'h8000_0004) && mem_read_in;
wire is_uart_write  = (dcache_addr == 32'h8000_0008) && mem_write_in;
wire is_uart_read   = (dcache_addr == 32'h8000_0008) && mem_read_in;

assign uart_tx_en   = is_uart_write && valid_in;
assign uart_tx_data = rs2_data_in[7:0];

wire dcache_req     = (mem_write_in || mem_read_in) && valid_in && !is_mmio_write && !is_mmio_read && !is_uart_write;
wire new_cache_access = dcache_req && (!last_counted_valid || (access_id_in != last_counted_access_id));

wire l1_hit;
wire [31:0] l1_rdata;
wire [31:0] mem_baseline_read = dmem[dcache_addr[11:2]];

// L1 Data Cache
l1_cache dcache (
    .clk(clk),
    .rst(~reset),
    .addr(dcache_addr),
    .wdata(rs2_data_in),
    .we(mem_write_in && valid_in && !is_mmio_write), 
    .re(mem_read_in && valid_in && !is_mmio_read),
    .rdata(l1_rdata),
    .hit(l1_hit),
    .dirty_evict(), 
    .evict_addr(),
    .evict_data()
);

// Memory Read (Combinatorial)
wire [31:0] cache_or_mem_out = (l1_hit ? l1_rdata : mem_baseline_read);
wire [31:0] raw_read_val = is_mmio_read ? {24'b0, sw} : 
                           is_uart_read ? {31'b0, uart_tx_busy} :
                           (dcache_req && !mem_write_in) ? cache_or_mem_out : 32'h0;
reg [31:0] aligned_read_val;

always @(*) begin
    aligned_read_val = raw_read_val;
    if (mem_read_in) begin
        case (funct3_in)
            LB: begin
                case (byte_offset)
                    2'b00: aligned_read_val = {{24{raw_read_val[7]}},  raw_read_val[7:0]};
                    2'b01: aligned_read_val = {{24{raw_read_val[15]}}, raw_read_val[15:8]};
                    2'b10: aligned_read_val = {{24{raw_read_val[23]}}, raw_read_val[23:16]};
                    2'b11: aligned_read_val = {{24{raw_read_val[31]}}, raw_read_val[31:24]};
                endcase
            end
            LH: begin
                if (byte_offset[1]) aligned_read_val = {{16{raw_read_val[31]}}, raw_read_val[31:16]};
                else aligned_read_val = {{16{raw_read_val[15]}}, raw_read_val[15:0]};
            end
            LW:  aligned_read_val = raw_read_val;
            LBU: begin
                case (byte_offset)
                    2'b00: aligned_read_val = {24'h0, raw_read_val[7:0]};
                    2'b01: aligned_read_val = {24'h0, raw_read_val[15:8]};
                    2'b10: aligned_read_val = {24'h0, raw_read_val[23:16]};
                    2'b11: aligned_read_val = {24'h0, raw_read_val[31:24]};
                endcase
            end
            LHU: begin
                if (byte_offset[1]) aligned_read_val = {16'h0, raw_read_val[31:16]};
                else aligned_read_val = {16'h0, raw_read_val[15:0]};
            end
            default: ;
        endcase
    end
end

assign forward_data = mem_to_reg_in ? aligned_read_val : alu_result_in;
assign perf_active = dcache_req || mem_stall_req;

wire effective_stall = stall;

always @(posedge clk or negedge reset) begin
    if (!reset || flush) begin
        pc_plus4_out        <= 0;
        alu_result_out      <= 0;
        mem_read_data_out   <= 0;
        rd_addr_out         <= 0;
        funct3_out          <= 0;
        mem_to_reg_out      <= 0;
        reg_write_out       <= 0;
        valid_out           <= 0;
        led_out             <= 0;
    end
    else begin
        if (!effective_stall) begin
            pc_plus4_out        <= pc_plus4_in;
            alu_result_out      <= alu_result_in;
            mem_read_data_out   <= aligned_read_val;
            rd_addr_out         <= rd_addr_in;
            funct3_out          <= funct3_in;
            mem_to_reg_out      <= mem_to_reg_in;
            reg_write_out       <= reg_write_in;
            valid_out           <= valid_in;
        end
        // Always capture LED output regardless of pipeline stall
        if (mem_write_in && valid_in && (dcache_addr == 32'h8000_0000)) begin
            led_out <= rs2_data_in;
        end
    end
end

// Artificial slow-down logic for Cache Misses
reg [3:0] penalty_counter;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        penalty_counter <= 0;
        mem_stall_req   <= 0;
        l1_hit_count    <= 0;
        l1_miss_count   <= 0;
        last_counted_valid <= 0;
        last_counted_access_id <= 8'd0;
    end else begin
        // --- HW PROOF METRICS ---
        // Count each unique Data Cache access once using its Access ID
        if (dcache_req && (access_id_in != last_counted_access_id)) begin
            last_counted_access_id <= access_id_in;
            if (l1_hit) begin
                l1_hit_count <= l1_hit_count + 1;
            end else begin
                l1_miss_count <= l1_miss_count + 1;
            end
        end
        // ------------------------
        // ------------------------

        // If there is a read/write, it's not MMIO, and it misses L1: penalize 10 clock cycles
        if (new_cache_access && !l1_hit && penalty_counter == 0 && !mem_stall_req && !is_mmio_write && !is_uart_write) begin
            penalty_counter <= 4'd10;  // 10 cycle penalty to fetch from 'main memory'
            mem_stall_req   <= 1;
        end else if (penalty_counter > 0) begin
            if (penalty_counter == 1) begin
                mem_stall_req <= 0;    // Penalty over, resume pipeline
            end
            penalty_counter <= penalty_counter - 1;
        end else begin
            mem_stall_req <= 0;
        end
    end
end

endmodule
