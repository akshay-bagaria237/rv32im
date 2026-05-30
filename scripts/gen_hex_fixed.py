import struct

def encode_r(opcode, funct3, funct7, rd, rs1, rs2):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i(opcode, funct3, rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_u(opcode, rd, imm):
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode

def encode_j(opcode, rd, imm):
    bit20 = (imm >> 20) & 1
    bit10_1 = (imm >> 1) & 0x3FF
    bit11 = (imm >> 11) & 1
    bit19_12 = (imm >> 12) & 0xFF
    encoded_imm = (bit20 << 19) | (bit10_1 << 9) | (bit11 << 8) | bit19_12
    return (encoded_imm << 12) | (rd << 7) | opcode

instructions = []

def add_inst(name, code):
    instructions.append((name, f"{code:08x}"))

# 1. Integer Setup
add_inst("addi x1, x0, 10", encode_i(0x13, 0, 1, 0, 10))
add_inst("addi x2, x0, 3", encode_i(0x13, 0, 2, 0, 3))
add_inst("addi x3, x0, -10", encode_i(0x13, 0, 3, 0, -10))
add_inst("addi x4, x0, -3", encode_i(0x13, 0, 4, 0, -3))

# 2. M-Extension (Multiplication)
add_inst("mul x5, x1, x2", encode_r(0x33, 0, 1, 5, 1, 2))
add_inst("mulh x6, x3, x4", encode_r(0x33, 1, 1, 6, 3, 4))
add_inst("mulhsu x7, x3, x2", encode_r(0x33, 2, 1, 7, 3, 2))
add_inst("mulhu x8, x1, x2", encode_r(0x33, 3, 1, 8, 1, 2))

# 3. M-Extension (Division/Remainder)
add_inst("div x9, x3, x2", encode_r(0x33, 4, 1, 9, 3, 2))
add_inst("divu x10, x1, x2", encode_r(0x33, 5, 1, 10, 1, 2))
add_inst("rem x11, x3, x2", encode_r(0x33, 6, 1, 11, 3, 2))
add_inst("remu x12, x1, x2", encode_r(0x33, 7, 1, 12, 1, 2))

# 4. FP Setup via LUI since regs are shared!
# 2.0 = 0x40000000, 3.0 = 0x40400000, 5.0 = 0x40A00000, 9.0 = 0x41100000
add_inst("lui x13, 0x40000 (2.0f)", encode_u(0x37, 13, 0x40000))
add_inst("lui x14, 0x40400 (3.0f)", encode_u(0x37, 14, 0x40400))
add_inst("lui x15, 0x40A00 (5.0f)", encode_u(0x37, 15, 0x40a00))
add_inst("lui x16, 0x41100 (9.0f)", encode_u(0x37, 16, 0x41100))

# 5. F-Extension Arithmetic
add_inst("fadd.s x17, x13, x14", encode_r(0x53, 0, 0x00, 17, 13, 14))
add_inst("fsub.s x18, x15, x13", encode_r(0x53, 0, 0x04, 18, 15, 13))
add_inst("fmul.s x19, x13, x14", encode_r(0x53, 0, 0x08, 19, 13, 14))
add_inst("fdiv.s x20, x16, x14", encode_r(0x53, 0, 0x0C, 20, 16, 14))
add_inst("fmin.s x21, x13, x14", encode_r(0x53, 0, 0x14, 21, 13, 14))
add_inst("fmax.s x22, x13, x14", encode_r(0x53, 1, 0x14, 22, 13, 14))

# 6. F-Extension Comparisons
add_inst("feq.s x23, x13, x14", encode_r(0x53, 2, 0x50, 23, 13, 14))
add_inst("flt.s x24, x13, x14", encode_r(0x53, 1, 0x50, 24, 13, 14))
add_inst("fle.s x25, x13, x14", encode_r(0x53, 0, 0x50, 25, 13, 14))

# 7. Type conversion natively supported in decode.v map
add_inst("fcvt.w.s x26, x14", encode_r(0x53, 0, 0x60, 26, 14, 0)) # float (rs1) to int (rd)
add_inst("fcvt.wu.s x27, x14", encode_r(0x53, 0, 0x60, 27, 14, 1))

add_inst("fcvt.s.w x28, x1", encode_r(0x53, 0, 0x68, 28, 1, 0))   # int (rs1) to float (rd)
add_inst("fcvt.s.wu x29, x1", encode_r(0x53, 0, 0x68, 29, 1, 1))

# 8. Custom Ops mappings in decode.v (floor, ceil, round)
# rs2 = 0b11111 to avoid collision with fcvt.w.s / fcvt.s.w in simplistic decode.v mask logic
add_inst("custom.floor x30, x14", encode_r(0x53, 0, 0x60, 30, 14, 0x1F)) 
add_inst("custom.ceil x31, x14", encode_r(0x53, 0, 0x64, 31, 14, 0x1F))  
# Note round is also op14, let's just reuse rs1=14.
add_inst("custom.round x5, x14", encode_r(0x53, 0, 0x68, 5, 14, 0x1F))

# 9. Infinite Loop
add_inst("jal x0, 0", encode_j(0x6F, 0, 0))

with open('C:/final_till_fpu/project/project/riscv-32im/riscv-32im.srcs/sources_1/imports/5-stage-version/testBenches/imem_final.hex', 'w') as f:
    f.write("// Instructions accurately matching fpu.v and decode.v specific mappings.\n")
    for name, code in instructions:
        f.write(f"{code} // {name}\n")
