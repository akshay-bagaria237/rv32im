# Detailed Explanation of fpu.v (RISC-V 32-bit Floating Point Unit)

This document provides a deep, comprehensive breakdown of the `fpu.v` module. It is divided into two main sections: The **Fast Path** (Combinational Engine) and the **Slow Path** (Multi-Cycle State Machine).

## 1. Module Definition and Ports
```verilog
module fpu(
    input wire clk, rst, start,
    input wire [3:0] op,
    input wire [31:0] a, b,
    input wire [2:0] rm,
    output reg [31:0] out,
    output reg ready,
    output reg [4:0] fflags
);
```
- **Inputs:** `clk` (clock), `rst` (reset), `start` (triggers the operation), `op` (4-bit opcode defining which instruction to run), `a` and `b` (32-bit floating point operands), `rm` (rounding mode).
- **Outputs:** `out` (32-bit result), `ready` (goes high when the operation is complete), `fflags` (Floating-point exception flags: Invalid, Divide by Zero, Overflow, Underflow, Inexact).

## 2. State Machine Constants & Registers
```verilog
    localparam IDLE           = 3'd0;
    localparam ALIGN_MUL_DIV  = 3'd1;
    localparam ADD            = 3'd2;
    localparam NORM           = 3'd3;
    localparam DIVIDE_LOOP    = 3'd4;
```
These define the 5 states of the FSM used for multi-cycle arithmetic (Add, Sub, Mul, Div).
- Registers like `sign_a`, `exp_a`, `mant_a` store the unpacked pieces of the IEEE-754 numbers (Sign, Exponent, Mantissa).
- `div_P`, `div_A`, `div_count` are specialized registers used exclusively for the division loop.

---

## 3. The "Fast Path" (Combinational Logic)
The fast path resolves operations in 0 clock cycles (combinationally). As soon as `start` is asserted, the answer is already waiting to be latched.

### 3.1 Rounding Logic (`compute_round` function)
This function handles RISC-V `Floor`, `Ceil`, and `Round`.
- **NaN/Inf Handling:** If the exponent is `8'hFF`, the number is Infinity or NaN. It canonicalizes NaNs (making sure the quiet NaN payload matches the RISC-V spec) or passes Infinity through.
- **Numbers < 1.0 (Exp < 127):** If absolute value is less than 1, Flooring a positive number gives 0, flooring a negative gives -1, etc.
- **Fractional Masking:** For normal numbers, it uses `mask_shift = 8'd150 - r_exp`. This calculates how many bits of the 23-bit mantissa actually represent fractional values versus integer values.
- **Rounding up:** Depending on the `op`, it looks at the fractional part (`m_frac`). If the fraction is > 0.5 (for ROUND) or > 0.0 depending on the sign (for CEIL/FLOOR), `round_up` is set to 1. The mantissa is then incremented.

### 3.2 Combinational Min/Max & Compare
```verilog
    wire is_nan_a = (a[30:23] == 8'hFF) && (a[22:0] != 23'd0);
    // ...
    wire a_lt_b = ...
```
Checks for NaNs, Signaling NaNs, and Zeroes (`+0.0` == `-0.0`).
Floating point numbers are cleverly designed so their bit patterns can be compared like sign-magnitude integers. `a_lt_b_mag` compares the lower 31 bits (absolute value). The final `a_lt_b` checks signs, handles negatives (where larger magnitude = smaller value), and zeroes. `fmin_res` and `fmax_res` use these combinational flags to instantly output the smaller/larger value or a Canonical NaN if inputs are invalid.

### 3.3 Float to Int Conversions (`f2i`)
```verilog
    wire signed [9:0] f2i_shift = f2i_exp - 10'd127;
```
Extracts the exponent and subtracts the bias (127) to find the true scale (`f2i_shift`).
- If scale < 0, the number is a fraction, so it converts to Integer `0`.
- If scale <= 23, it shifts the mantissa RIGHT (cutting off decimals).
- If scale > 23, it shifts the mantissa LEFT.
It then applies boundary checks (`over_pos_s`, `over_neg_s`) to cap the output at `0x7FFFFFFF` (Max Int) or `0x80000000` (Min Int) if the float is too huge to fit.

### 3.4 Int to Float Conversions (`i2f`)
```verilog
    always @(*) begin
        i2f_lz = 31;
        for (j = 31; j >= 0; j = j - 1) begin
            if (i2f_abs[j] && i2f_lz == 31) i2f_lz = 31 - j;
        end
    end
```
A "Priority Encoder" counts Leading Zeros (`i2f_lz`). The number of leading zeros directly determines the new floating-point Exponent (`127 + 31 - LZs`).
The integer is then barrel-shifted left or right to fit into the 23-bit mantissa format. Extra bits shifted out are rounded using "Round to Nearest, Ties to Even" logic.

### 3.5 Fast Path Multiplexer
```verilog
    always @(*) begin
        case (op)
            4'd7:  fast_path_res = fmin_res;
            // ... maps operations 7-15 and 2-4 to combinational logic
```
This multiplexer selects which combinational result (`fmin`, `fmax`, `compare`, `cvt`) goes to `fast_path_res`.

---

## 4. The "Slow Path" (Multi-Cycle FSM)
This section uses the `clk` and takes multiple cycles. Inside `always @(posedge clk)`, we switch through `state`.

### 4.1 State 0: IDLE
Checks if `start` is high. 
- If `op` is a Fast Path operation (e.g., Min, fcvt), it instantly outputs `fast_path_res`, sets `ready <= 1'b1`, and does NOT change state.
- If `op` is Add/Sub/Mul/Div, it unpacks `a` and `b`. The mantissas are expanded (adding the hidden '1' bit for normal numbers `2'b01`). Then transitions to `ALIGN_MUL_DIV`.

### 4.2 State 1: ALIGN_MUL_DIV
- **Multiply (op=5):** Calculates the sign (`sign_a ^ sign_b`). Combinationally multiplies the two 24-bit mantissas into a 48-bit result. It then shifts the result and adds the exponents (`exp_a + exp_b - 127`). Jumps straight to `NORM`.
- **Divide (op=6):** Loads the dividend into a 48-bit register `div_A`. Prepares the counter `div_count` to 48. Jumps to `DIVIDE_LOOP`.
- **Add/Sub (Default):** Identifies the larger exponent. It shifts the smaller number's mantissa to the RIGHT by the difference in exponents (`exp_diff_ab`). This aligns the decimal points. Jumps to `ADD`.

### 4.3 State 2: ADD
Only used for Addition/Subtraction.
- If signs match, it adds the aligned mantissas.
- If signs differ, it subtracts the smaller mantissa from the larger one, and adopts the sign of the larger value. Jumps to `NORM`.

### 4.4 State 3: DIVIDE_LOOP
Implements a 48-cycle **Restoring Division Algorithm**.
- Evaluates if the divisor (`mant_b`) can be subtracted from the current partial remainder (`div_P`).
- If yes, it subtracts it and shifts a `1` into the quotient `div_A`.
- If no, it restores/maintains the value and shifts a `0`.
- After 48 cycles (`div_count == 0`), it extracts the completed quotient mantissa, subtracts the exponents (`exp_a - exp_b + 127`), and jumps to `NORM`.

### 4.5 State 4: NORM (Normalization)
Before outputting `Add/Sub/Mul/Div`, the number must be formatted to standard scientific notation (one bit before the decimal point).
- **Carry Out Overflow:** If addition caused the mantissa to exceed 24 bits (bit 24 is high), shift it right by 1 and increase the exponent. If the exponent hits 255, cap it to Infinity (Overflow).
- **Exact Zero:** If mantissa is 0, output `0x00000000`.
- **Underflow:** If the exponent drops below 0 (negative), this simple processor implements "Flush to Zero" (outputs `0`).
- **Standard Normalization:** If subtraction cancelled out leading bits, it uses the Combinational Priority Encoder `shift_amt` to fast-shift the mantissa left, subtracting `shift_amt` from the exponent.
- Outputs the assembled `{sign, exp, mantissa}`, raises `ready <= 1`, and returns to `IDLE`.
