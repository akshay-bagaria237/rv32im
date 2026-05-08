# FPU Builder's Guide: A Deep Dive Line-by-Line

This document provides a line-by-line, block-by-block explanation of the `fpu.v` module. By reading this, you will understand the exact mechanics of a hybrid fast-path/multi-cycle IEEE-754 Floating Point Unit, empowering you to build one from scratch.

---

## 1. Module Definition and Interface

```verilog
module fpu(
    input wire clk, rst, start,
    input wire [3:0] op,    // 0=fadd, 1=fsub, 2=floor, 3=ceil, 4=round, 5=fmul, 6=fdiv, 7=fmin, 8=fmax, 9=feq, 10=flt, 11=fle
    input wire [31:0] a, b,
    input wire [2:0] rm,    // rounding mode
    output reg [31:0] out,
    output reg ready,
    output reg [4:0] fflags // nv, dz, of, uf, nx
);
```
**Explanation:** 
This defines the module interface. 
- `clk`, `rst`, `start`: Standard control signals. `start` kicks off an operation.
- `op`: A 4-bit opcode tying to RISC-V F-extension instructions.
- `a`, `b`: The 32-bit floating point operands. Standard IEEE-754 single precision: 1 sign bit, 8 exponent bits (bias 127), and 23 fractional mantissa bits (with an implicit leading 1).
- `rm`: Rounding mode (used to dictate ties, though simplified in some blocks here).
- `out`: The 32-bit computed result.
- `ready`: Asserts high when the FPU has finished work. The CPU stalls until this is high.
- `fflags`: Standard RISC-V exception flags.

---

## 2. FSM States and Multi-Cycle Registers

```verilog
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
```
**Explanation:**
To save area and achieve a high clock frequency (Fmax), heavy math operations (add, sub, mul, div) cannot happen in one clock cycle. We use a Finite State Machine (FSM).
- `state`: Tracks where the FPU is in the pipeline.
- `sign_a`, `exp_a`, `mant_a`: Registers to hold the unpacked components of input `a` (and `b`). The mantissas are 25 bits to accommodate the implicit leading '1', an extra bit for overflow carry, and potential sign bits.
- `exp_res` is a signed 10-bit integer. When you subtract exponents (like in division), the result can go negative. We need enough bits to track underflows securely before capping them to 0.
- `div_P`, `div_A`, `div_count`: Used exclusively for the 48-stage restoring division algorithm.

---

## 3. Combinational Helpers

```verilog
    wire [8:0] exp_diff_ab = exp_a - exp_b;
    wire [8:0] exp_diff_ba = exp_b - exp_a;
    reg [4:0] shift_amt;
    reg [24:0] shifted_mant;
```
**Explanation:**
When adding numbers like $1.0 \times 10^2$ and $1.0 \times 10^3$, you must align their decimal points. `exp_diff_ab` calculates how far to shift the mantissa to achieve alignment. 
`shift_amt` and `shifted_mant` are populated later by a priority encoder to shift the answer back into normalized scientific notation.

---

## 4. The Rounding Engine (Combinational Function)

```verilog
    function [31:0] compute_round;
        input [31:0] a;
        input [3:0] op;
        reg r_sign; reg [7:0] r_exp; reg [22:0] r_mant;
        // ... (Internal variables) ...
```
**Explanation:**
Functions in Verilog behave entirely combinationally. They evaluate instantly. This function does `Floor`, `Ceil`, and `Round`. It unpacks `a` into sign, exponent, and mantissa.

```verilog
        if (r_exp == 8'hFF) begin // NaN or Inf
            if (r_mant != 0) compute_round = {r_sign, 8'hFF, 1'b1, 22'b0}; // Quiet NaN
            else compute_round = a; // Infinity
        end
```
**Explanation:**
IEEE-754 rules: An exponent of 255 (`0xFF`) means Infinity (if mantissa is 0) or Not a Number (NaN) if mantissa > 0. RISC-V requires NaNs to be "Canonical" (quiet NaNs with a specific payload), which is why we force the mantissa to `1'b1, 22'b0`.

```verilog
        else if (r_exp < 8'd127) begin
            // Absolute value < 1.0
            if (op == 4'd2) begin // FLOOR
                compute_round = (r_exp == 0 && r_mant == 0) ? {r_sign, 31'b0} : (r_sign ? 32'hBF800000 : {r_sign, 31'b0});
            end //... (Ceil / Round logic similar)
        end
```
**Explanation:**
If exponent < 127, the value is between -1.0 and 1.0. 
- Flooring a positive fraction gives 0.0 (`{r_sign, 31'b0}`).
- Flooring a negative fraction gives -1.0 (`32'hBF800000`, which is sign=1, exp=127, mant=0).

```verilog
        else begin
            mask_shift = 8'd150 - r_exp; 
            frac_mask = ~(24'hFFFFFF << mask_shift);
            mant_mask = ~frac_mask;
            full_mant = {1'b1, r_mant};
            m_int  = full_mant & mant_mask;
            m_frac = full_mant & frac_mask;
```
**Explanation:**
For normal numbers. `150` comes from `127 (bias) + 23 (fractional bits)`. By subtracting the actual exponent from 150, we figure out exactly which bits inside the mantissa act as integers and which represent decimals.
We create a `frac_mask` to extract the decimals (`m_frac`) and integer bits (`m_int`).

```verilog
            if (m_frac != 0) begin
                // Check if we need to round up
                if (op == 4'd4) begin // ROUND to nearest
                    half = 24'd1 << (mask_shift - 1);
                    if (m_frac > half) round_up = 1'b1;
                    else if (m_frac < half) round_up = 1'b0;
                    else round_up = (m_int >> mask_shift) & 1'b1; // Tie to even
                end
                // ... (Apply round_up by adding to mantissa)
```
**Explanation:**
If there are decimal bits, we decide to round up. In `ROUND`, we calculate exactly `0.5` (`half`). If our fraction is exactly `0.5`, we look at the least significant bit of the integer part. If it's 1 (odd), we round up to make it even. Finally, we add `round_up` back to `m_int` and reconstruct the 32-bit float.

---

## 5. Priority Encoder for Normalization (Always Block)

```verilog
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
```
**Explanation:**
After subtracting numbers (e.g., `1.001 - 1.000 = 0.001`), we lose the leading `1`. Scientific notation demands `1.something` (a normalized mantissa). This `always` block evaluates continuously. It scans the mantissa from left to right. The moment it spots a `1`, it records how far it had to look (`shift_amt = 23 - i`). It then shifts the mantissa left by that amount (`shifted_mant = mant_res << shift_amt`). During the FSM `NORM` state, we will subtract this `shift_amt` from the exponent to keep the value mathematically identical.

---

## 6. Fast Path Combinational Mux

```verilog
    always @(*) begin
        case (op)
            4'd7:  fast_path_res = fmin_res;
            4'd8:  fast_path_res = fmax_res;
            4'd9:  fast_path_res = {31'b0, a_eq_b};
            4'd10: fast_path_res = {31'b0, a_lt_b};
            4'd11: fast_path_res = {31'b0, a_le_b};
            4'd12: fast_path_res = f2i_signed_res;
            4'd13: fast_path_res = f2i_unsigned_res;
            4'd14, 4'd15: fast_path_res = i2f_res;
            default: fast_path_res = round_res;
        endcase
    end
```
**Explanation:**
We generated a bunch of combinational answers simultaneously (Min, Max, EQ, LT, Float-to-Int, Int-to-Float). This multiplexer looks at the `op` code and selects the right answer, wiring it directly to `fast_path_res`.

---

## 7. The Main FSM (Sequential Execution)

```verilog
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE; ready <= 1'b0; out <= 32'b0; fflags <= 5'b0;
        end else begin
            case (state)
```
**Explanation:**
This block triggers strictly on the rising edge of the clock. On reset, clearing all outputs and putting the state in `IDLE`.

### 7.1 State 0: IDLE

```verilog
                IDLE: begin
                    if (start && !ready) begin 
                        if ((op >= 4'd2 && op <= 4'd4) || (op >= 4'd7 && op <= 4'd15)) begin
                            out <= fast_path_res; ready <= 1'b1; state <= IDLE; 
                        end else begin
                            sign_a <= a[31];
                            exp_a  <= {1'b0, a[30:23]};
                            mant_a <= (|a[30:23]) ? {2'b01, a[22:0]} : {2'b00, a[22:0]};
                            
                            sign_b <= (op == 4'd1) ? ~b[31] : b[31];
                            // ...
                            state <= ALIGN_MUL_DIV;
                        end
                    end
                end
```
**Explanation:**
If `start` is active:
1. We check if the operation is "fast". If so, we bypass the FSM entirely! We immediately push `fast_path_res` to `out`, raise `ready`, and stay in `IDLE`. (It takes 0 extra clock cycles).
2. If it's a slow operation (Add/Sub/Mul/Div), we unpack the data into registers. Notice `mant_a <= (|a[30:23]) ? {2'b01, a[22:0]} : {2'b00, a[22:0]};`. If the exponent is not zero (`|a` is a reduction OR), we inject the implicit leading `1`. If it's zero, the number is subnormal (or exactly zero), so we inject `0`.
Transition to `ALIGN_MUL_DIV`.

### 7.2 State 1: ALIGN_MUL_DIV

```verilog
                ALIGN_MUL_DIV: begin
                    if (op == 4'd5) begin // MUL
                        sign_res <= sign_a ^ sign_b;
                        if (({25'b0, mant_a} * {25'b0, mant_b}) & 50'h800000000000) begin
                            mant_res <= ({25'b0, mant_a} * {25'b0, mant_b}) >> 23;
                            exp_res <= {1'b0, exp_a} + {1'b0, exp_b} - 10'd127;
                        end else begin
                            mant_res <= ({25'b0, mant_a} * {25'b0, mant_b}) >> 22;
                            exp_res <= {1'b0, exp_a} + {1'b0, exp_b} - 10'd128;
                        end
                        state <= NORM;
```
**Explanation:**
**For Multiply**:
1. Sign is simply XORing the incoming signs ($pos \times neg = neg$, $neg \times neg = pos$).
2. Mutiply the mantissas. We check bit 47 (`& 50'h800000000000`). If it cascaded to bit 47, we shift away the bottom 23 bits and subtract 127 from the added exponents. Otherwise, we shift away 22 bits and subtract 128. Jump to `NORM`.

```verilog
                    end else if (op == 4'd6) begin // DIV
                        sign_res <= sign_a ^ sign_b;
                        div_A <= {mant_a, 23'b0}; 
                        div_P <= 48'b0;
                        div_count <= 6'd48;
                        state <= DIVIDE_LOOP;
```
**Explanation:**
**For Divider**: Set up the 48-cycle loop. `div_A` gets the dividend padded with zeros. `div_P` gets the partial remainder (starts at 0). `div_count` is 48. Jump to `DIVIDE_LOOP`.

```verilog
                    end else begin // ADD / SUB
                        if (exp_a > exp_b) begin
                            mant_b <= (exp_diff_ab > 24) ? 25'b0 : (mant_b >> exp_diff_ab[4:0]);
                            exp_res <= {1'b0, exp_a};
                        end else if (exp_a < exp_b) begin
                            mant_a <= (exp_diff_ba > 24) ? 25'b0 : (mant_a >> exp_diff_ba[4:0]);
                            exp_res <= {1'b0, exp_b};
                        end else begin
                            exp_res <= {1'b0, exp_a};
                        end
                        state <= ADD;
                    end
                end
```
**Explanation:**
**For Add/Sub**: We must equalize the exponents. The logic finds the larger exponent and assigns it to `exp_res`. Then, it takes the smaller number's mantissa and shifts it right by the absolute difference between the exponents (`exp_diff_ab`). This essentially adds leading zeros, aligning the radix points.

### 7.3 State 2: ADD

```verilog
                ADD: begin
                    if (sign_a == sign_b) begin
                        mant_res <= mant_a + mant_b;
                        sign_res <= sign_a;
                    end else begin
                        if (mant_a > mant_b) begin
                            mant_res <= mant_a - mant_b;
                            sign_res <= sign_a;
                        end else if (mant_a < mant_b) begin
                            mant_res <= mant_b - mant_a;
                            sign_res <= sign_b;
                        //... (zero cancellation handled)
                    end
                    state <= NORM;
                end
```
**Explanation:**
If the signs match, just add the mantissas. If they differ, it's actually subtraction. The hardware compares which mantissa is larger, subtracts the smaller from the larger (so we don't get a negative binary number), and adopts the sign of the larger one. Jumps to `NORM`.

### 7.4 State 3: DIVIDE_LOOP

```verilog
                DIVIDE_LOOP: begin
                    if (div_count == 0) begin
                        if (div_A[23]) begin 
                            mant_res <= {1'b0, div_A[23:0]};
                            exp_res <= {1'b0, exp_a} - {1'b0, exp_b} + 10'd127;
                        end else begin
                            mant_res <= {1'b0, div_A[22:0], 1'b0};
                            exp_res <= {1'b0, exp_a} - {1'b0, exp_b} + 10'd126;
                        end
                        state <= NORM;
                    end else begin
                        if ({div_P[46:0], div_A[47]} >= {24'b0, mant_b}) begin
                            div_P <= {div_P[46:0], div_A[47]} - {24'b0, mant_b};
                            div_A <= {div_A[46:0], 1'b1};
                        end else begin
                            div_P <= {div_P[46:0], div_A[47]};
                            div_A <= {div_A[46:0], 1'b0};
                        end
                        div_count <= div_count - 1;
                    end
                end
```
**Explanation:**
This is classic Restoring Division, iterated cycle by cycle to avoid killing clock speed.
Every cycle, we shift `div_A` into `div_P`. We attempt to subtract the divisor `mant_b` from `div_P`.
- If `div_P >= mant_b`: We successfully subtract. We shift a `1` into the lowest bit of `div_A` (our quotient accumulator).
- Else: We do not subtract. We shift a `0` into `div_A`.
After 48 cycles, `div_A` holds the quotient mantissa. We fix the exponent via `exp_a - exp_b + 127` and shift the final mantissa correctly based on where the highest `1` fell.

### 7.5 State 4: NORM (Normalization and Output)

```verilog
                NORM: begin
                    if (mant_res[24]) begin 
                        // Overflowed during addition (Carry Out)
                        if (exp_res >= 10'd254) out <= {sign_res, 8'hFF, 23'd0}; // Overflow to Inf
                        else out <= {sign_res, exp_res[7:0] + 8'd1, mant_res[23:1]};
                        
                        ready <= 1'b1; state <= IDLE;
```
**Explanation:**
Did adding two numbers create a carry bit? (e.g. $1.5 + 1.5 = 3.0$ -> $1.1_2 + 1.1_2 = 11.0_2$). `mant_res[24]` captures this. We immediately shift the mantissa right by `1` (`mant_res[23:1]`) and add `1` to the exponent to fix it. If the exponent hits 255, we output Infinity.

```verilog
                    end else if (exp_res <= 10'd0 || exp_res[9]) begin 
                        out <= {sign_res, 31'b0}; // Underflow to zero
                        ready <= 1'b1; state <= IDLE;
```
**Explanation:**
If the exponent went below zero (trackable because `exp_res` is a signed 10-bit integer, so `exp_res[9]` is the sign bit), we underflowed. Instead of creating subnormals (which are slow and painful), this core simplifies things by "Flushing to Zero" and outputting `0.0`.

```verilog
                    end else begin
                        // Normal execution using priority encoder
                        if ((exp_res - {5'b0, shift_amt}) >= 255) begin
                            out <= {sign_res, 8'hFF, 23'd0};
                        end else begin
                            out <= {sign_res, exp_res[7:0] - {3'b0, shift_amt}, shifted_mant[22:0]};
                        end
                        ready <= 1'b1; state <= IDLE;
                    end
```
**Explanation:**
Standard normalization: Here is where that Priority Encoder comes to the rescue. It shifted `shifted_mant` left until there was a leading `1`, and gave us `shift_amt`. We subtract `shift_amt` from the exponent to mathematically balance the left-shift. We pack `{sign, exp, mantissa}` into `out`, assert `ready`, and go back to `IDLE` to wait for the next instruction!
