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

wire is_signed = (funct3 == DIV || funct3 == REM);

wire div_by_zero_now = (operand2 == 32'h0);
wire overflow_now    = (is_signed && operand1 == 32'h8000_0000 && operand2 == 32'hFFFF_FFFF);

reg [32:0] temp_rem;

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        state         <= IDLE;
        count         <= 0;
        result        <= 32'h0;
        abs_op2       <= 32'h0;
        quotient_reg  <= 32'h0;
        remainder_reg <= 32'h0;
        neg_quotient  <= 1'b0;
        neg_remainder <= 1'b0;
        saved_operand1 <= 32'h0;
        saved_div_by_zero <= 1'b0;
        saved_overflow    <= 1'b0;
    end
    else begin
        case (state)
            IDLE: begin
                if (start) begin
                    saved_operand1 <= operand1;
                    saved_div_by_zero <= div_by_zero_now;
                    saved_overflow    <= overflow_now;
                    
                    if (div_by_zero_now || overflow_now) begin
                        state <= FINISH;
                    end
                    else begin
                        state         <= DIVIDE;
                        count         <= 6'd32;
                        remainder_reg <= 32'h0;
                        quotient_reg  <= (is_signed && operand1[31]) ? -operand1 : operand1;
                        abs_op2       <= (is_signed && operand2[31]) ? -operand2 : operand2;
                        neg_quotient  <= is_signed && (operand1[31] ^ operand2[31]);
                        neg_remainder <= is_signed && operand1[31];
                    end
                end
            end
            
            DIVIDE: begin
                if (count == 0) begin
                    state <= FINISH;
                end
                else begin
                    temp_rem = {remainder_reg[30:0], quotient_reg[31]};
                    if (temp_rem >= {1'b0, abs_op2}) begin
                        remainder_reg <= temp_rem[31:0] - abs_op2;
                        quotient_reg  <= {quotient_reg[30:0], 1'b1};
                    end
                    else begin
                        remainder_reg <= temp_rem[31:0];
                        quotient_reg  <= {quotient_reg[30:0], 1'b0};
                    end
                    count <= count - 1;
                end
            end
            
            FINISH: begin
                state <= IDLE;
                if (saved_div_by_zero) begin
                    case (funct3)
                        DIV, DIVU: result <= 32'hFFFF_FFFF;
                        REM, REMU: result <= saved_operand1;
                        default:   result <= 32'h0;
                    endcase
        end
    end
endmodule
