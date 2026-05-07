import os

def encode_r(opcode, funct3, funct7, rd, rs1, rs2):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i(opcode, funct3, rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_s(opcode, funct3, rs1, rs2, imm):
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0 = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def encode_b(opcode, funct3, rs1, rs2, imm):
    bit12 = (imm >> 12) & 1
    bit11 = (imm >> 11) & 1
    bit10_5 = (imm >> 5) & 0x3F
    bit4_1 = (imm >> 1) & 0xF
    return (bit12 << 31) | (bit10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (bit4_1 << 8) | (bit11 << 7) | opcode

def encode_j(opcode, rd, imm):
    bit20 = (imm >> 20) & 1
    bit10_1 = (imm >> 1) & 0x3FF
    bit11 = (imm >> 11) & 1
    bit19_12 = (imm >> 12) & 0xFF
    encoded_imm = (bit20 << 19) | (bit10_1 << 9) | (bit11 << 8) | bit19_12
    return (encoded_imm << 12) | (rd << 7) | opcode

instructions = []
labels = {}

def add_inst(name, code):
    instructions.append((name, code))

def add_label(name):
    labels[name] = len(instructions)

def resolve_b(opcode, funct3, rs1, rs2, target_label):
    def linker(pc, inst_idx):
        target_idx = labels[target_label]
        offset = (target_idx - inst_idx) * 4
        return encode_b(opcode, funct3, rs1, rs2, offset)
    return linker

def resolve_j(opcode, rd, target_label):
    def linker(pc, inst_idx):
        target_idx = labels[target_label]
        offset = (target_idx - inst_idx) * 4
        return encode_j(opcode, rd, offset)
    return linker

# Registers:
# x10: i, x11: j, x12: sum, x13: tmp_prod, x14: limit (20), x15: dmem_base
add_inst("addi x12, x0, 0", encode_i(0x13, 0, 12, 0, 0))    # sum = 0
add_inst("addi x14, x0, 20", encode_i(0x13, 0, 14, 0, 20))   # limit = 20
add_inst("addi x10, x0, 0", encode_i(0x13, 0, 10, 0, 0))    # i = 0

add_label("OUTER_LOOP")
add_inst("bge x10, x14, END", resolve_b(0x63, 5, 10, 14, "END")) # if i >= 20 goto END
add_inst("addi x11, x0, 0", encode_i(0x13, 0, 11, 0, 0))    # j = 0

add_label("INNER_LOOP")
add_inst("bge x11, x14, OUTER_INC", resolve_b(0x63, 5, 11, 14, "OUTER_INC")) # if j >= 20 goto OUTER_INC

# sum += i * j (MUL instruction: opcode 0x33, funct3 0x0, funct7 0x01)
add_inst("mul x13, x10, x11", encode_r(0x33, 0, 0x01, 13, 10, 11))
add_inst("add x12, x12, x13", encode_r(0x33, 0, 0x00, 12, 12, 13))

add_inst("addi x11, x11, 1", encode_i(0x13, 0, 11, 11, 1))   # j++
add_inst("jal x0, INNER_LOOP", resolve_j(0x6F, 0, "INNER_LOOP"))

add_label("OUTER_INC")
add_inst("addi x10, x10, 1", encode_i(0x13, 0, 10, 10, 1))   # i++
add_inst("jal x0, OUTER_LOOP", resolve_j(0x6F, 0, "OUTER_LOOP"))

add_label("END")
# Write sum to DMEM[0x400] for verification
add_inst("addi x15, x0, 1024", encode_i(0x13, 0, 15, 0, 1024)) # x15 = 0x400
add_inst("sw x12, 0(x15)", encode_s(0x23, 2, 15, 12, 0))

# Infinite loop to signal completion
add_label("FINISH")
add_inst("jal x0, FINISH", resolve_j(0x6F, 0, "FINISH"))

# Generate Hex file
output_path = "imem_fpga.hex"
with open(output_path, "w") as f:
    for i, (name, code) in enumerate(instructions):
        val = code(0, i) if callable(code) else code
        f.write(f"{val:08x}\n")
    # Fill rest with NOPs (addi x0, x0, 0 -> 0x00000013)
    for _ in range(1024 - len(instructions)):
        f.write("00000013\n")

print(f"Generated {output_path} with {len(instructions)} instructions.")
