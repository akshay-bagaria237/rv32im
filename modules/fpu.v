`timescale 1ns/1ps
module fpu(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [3:0] op,    // 0=fadd, 1=fsub, 2=floor, 3=ceil, 4=round, 5=fmul, 6=fdiv, 7=fmin, 8=fmax, 9=feq, 10=flt, 11=fle
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [2:0] rm,    // rounding mode
    output reg [31:0] out,
    output reg ready,
    output reg [4:0] fflags // nv, dz, of, uf, nx
);

    // -------------------------------------------------------------------------
    // Simple Multi-Cycle FPU (Best for Cycle Time & Easy to Read)
    // -------------------------------------------------------------------------
    
    localparam IDLE           = 3'd0;
    localparam ALIGN_MUL_DIV  = 3'd1;
    localparam ADD            = 3'd2;
    localparam NORM           = 3'd3;
    localparam DIVIDE_LOOP    = 3'd4;

    reg [2:0] state;
    reg sign_a, sign_b, sign_res;
    reg [8:0] exp_a, exp_b;
    reg signed [9:0] exp_res; // Extra bits for overflow/underflow checks
    reg [24:0] mant_a, mant_b, mant_res;
    
    reg [47:0] div_P; // For multi-cycle division
    reg [47:0] div_A;
    reg [5:0] div_count;
    
    // Combinational helpers for single-cycle operations
    wire [8:0] exp_diff_ab = exp_a - exp_b;
    wire [8:0] exp_diff_ba = exp_b - exp_a;
    reg [4:0] shift_amt;
    reg [24:0] shifted_mant;

    // Rounding specific combinational logic
    function [31:0] compute_round;
        input [31:0] a;
        input [3:0] op;
        reg r_sign;
        reg [7:0] r_exp;
        reg [22:0] r_mant;
        reg [4:0] mask_shift;
        reg [23:0] frac_mask;
        reg [23:0] mant_mask;
        reg [23:0] full_mant;
        reg [23:0] m_int;
        reg [23:0] m_frac;
        reg round_up;
        reg [23:0] half;
        reg [24:0] m_added;
        begin
            r_sign = a[31];
            r_exp = a[30:23];
            r_mant = a[22:0];
            compute_round = a; // default to identity
            
            if (r_exp == 8'hFF) begin // NaN or Inf
                if (r_mant != 0) begin
                    compute_round = {r_sign, 8'hFF, 1'b1, 22'b0}; // Canonicalize Quiet NaN payload
                end else begin
                    compute_round = a; // +/- Infinity stays unmodified
                end
            end else if (r_exp < 8'd127) begin
                // Absolute value < 1.0
                if (op == 4'd2) begin // FLOOR
                    if (r_exp == 0 && r_mant == 0) begin
                        compute_round = {r_sign, 31'b0}; // +/- 0.0
                    end else begin
                        compute_round = r_sign ? 32'hBF800000 : {r_sign, 31'b0}; // -1.0 or +/-0.0
                    end
                end else if (op == 4'd3) begin // CEIL
                    if (r_exp == 0 && r_mant == 0) begin
                        compute_round = {r_sign, 31'b0}; // +/- 0.0
                    end else begin
                        compute_round = r_sign ? {r_sign, 31'b0} : 32'h3F800000; // +/-0.0 or 1.0
                    end
                end else if (op == 4'd4) begin // ROUND
                    if (r_exp == 8'd126 && r_mant != 0) begin
                        // > 0.5 -> 1.0
                        compute_round = {r_sign, 8'd127, 23'd0}; // +/- 1.0
                    end else if (r_exp == 8'd126 && r_mant == 0) begin
                        // == 0.5 -> 0.0 (tie to even, 0 is even)
                        compute_round = {r_sign, 31'b0};
                    end else begin
                        // < 0.5 -> 0.0
                        compute_round = {r_sign, 31'b0};
                    end
                end
            end else if (r_exp >= 8'd150) begin
                // Fractional bits are already outside the 23-bit mantissa
                compute_round = a;
            end else begin
                // Normal range with fractional bits inside mantissa (127 <= r_exp < 150)
                mask_shift = 8'd150 - r_exp; 
                frac_mask = ~(24'hFFFFFF << mask_shift);
                mant_mask = ~frac_mask;
                full_mant = {1'b1, r_mant};
                m_int  = full_mant & mant_mask;
                m_frac = full_mant & frac_mask;
                
                if (m_frac != 0) begin
                    round_up = 1'b0;
                    if (op == 4'd2) begin // FLOOR
                        if (r_sign) round_up = 1'b1;
                    end else if (op == 4'd3) begin // CEIL
                        if (!r_sign) round_up = 1'b1;
                    end else if (op == 4'd4) begin // ROUND
                        half = 24'd1 << (mask_shift - 1);
                        if (m_frac > half) round_up = 1'b1;
                        else if (m_frac < half) round_up = 1'b0;
                        else round_up = (m_int >> mask_shift) & 1'b1;
                    end
                    
                    if (round_up) begin
                        m_added = m_int + (25'd1 << mask_shift);
                        if (m_added[24]) begin
                            compute_round = {r_sign, r_exp + 1'b1, m_added[23:1]};
                        end else begin
                            compute_round = {r_sign, r_exp, m_added[22:0]};
                        end
                    end else begin
                        compute_round = {r_sign, r_exp, m_int[22:0]};
                    end
                end else begin
                    compute_round = a;
                end
            end
        end
    endfunction
    
    wire [31:0] round_res = compute_round(a, op);

    // Priority encoder to find leading 1 in 1 clock cycle for NORM
    integer i;
    always @(*) begin
        shift_amt = 24;
        for (i = 23; i >= 0; i = i - 1) begin
            if (mant_res[i] && shift_amt == 24) begin
                shift_amt = 23 - i;
            end
        end
        shifted_mant = mant_res << shift_amt;
    end
    
    // -------------------------------------------------------------------------
    // Combinational min/max/compare logic
    // -------------------------------------------------------------------------
    wire is_nan_a = (a[30:23] == 8'hFF) && (a[22:0] != 23'd0);
    wire is_nan_b = (b[30:23] == 8'hFF) && (b[22:0] != 23'd0);
    wire is_snan_a = is_nan_a && (a[22] == 1'b0);
    wire is_snan_b = is_nan_b && (b[22] == 1'b0);
    
    wire is_zero_a = (a[30:0] == 31'd0);
    wire is_zero_b = (b[30:0] == 31'd0);

    wire a_lt_b_mag = (a[30:0] < b[30:0]);
    wire a_eq_b_mag = (a[30:0] == b[30:0]);

    wire a_eq_b = (is_nan_a || is_nan_b) ? 1'b0 : 
                  (is_zero_a && is_zero_b) ? 1'b1 :
                  (a == b);

    wire a_lt_b = (is_nan_a || is_nan_b) ? 1'b0 :
                  (is_zero_a && is_zero_b) ? 1'b0 :
                  (a[31] != b[31]) ? (a[31] == 1'b1) :
                  (a[31] == 1'b0) ? a_lt_b_mag : (!a_lt_b_mag && !a_eq_b_mag);

    wire a_le_b = a_lt_b || a_eq_b;

    wire min_max_ret_canonical = (is_nan_a && is_nan_b) || is_snan_a || is_snan_b;

    wire [31:0] fmin_res = min_max_ret_canonical ? 32'h7FC00000 : 
                           (is_nan_a) ? b :
                           (is_nan_b) ? a :
                           (is_zero_a && is_zero_b) ? ((a[31] == 1'b1) ? a : b) : 
                           (a_lt_b) ? a : b;

    wire [31:0] fmax_res = min_max_ret_canonical ? 32'h7FC00000 : 
                           (is_nan_a) ? b :
                           (is_nan_b) ? a :
                           (is_zero_a && is_zero_b) ? ((a[31] == 1'b0) ? a : b) : 
                           (a_lt_b) ? b : a;

    // -------------------------------------------------------------------------
    // Combinational float-to-int and int-to-float logic
    // -------------------------------------------------------------------------

    // Float-to-Int (fcvt.w.s = op12, fcvt.wu.s = op13)
    wire [8:0] f2i_exp = {1'b0, a[30:23]};
    wire f2i_sign = a[31];
    wire [31:0] f2i_mant = {8'b0, 1'b1, a[22:0]}; // implicit 1 at bit 23
    wire signed [9:0] f2i_shift = f2i_exp - 10'd127;
    
    // Default zero when shift is negative (less than 1.0)
    wire [31:0] f2i_abs = (f2i_shift < 0) ? 32'b0 :
                          (f2i_shift <= 23) ? (f2i_mant >> (23 - f2i_shift)) : 
                          (f2i_shift <= 31) ? (f2i_mant << (f2i_shift - 23)) : 32'hFFFFFFFF;
                          
    wire over_pos_s = !f2i_sign && (f2i_shift >= 31);
endmodule
