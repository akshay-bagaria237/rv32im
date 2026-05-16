OP_JAL   = 0b1101111
OP_LOAD  = 0b0000011
OP_STORE = 0b0100011
OP_IMM   = 0b0010011
OP_LUI   = 0b0110111


def e_i(opcode, funct3, rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def e_s(opcode, funct3, rs1, rs2, imm):
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1F) << 7) | opcode


def e_u(opcode, rd, imm):
    return (imm << 12) | (rd << 7) | opcode


def e_j(opcode, rd, imm):
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | opcode


# Deterministic FPGA demo:
# 10 data-cache accesses total
# 4 compulsory misses followed by 6 hits
instructions = [
    e_u(OP_LUI, 2, 0x80000),  # x2 = 0x8000_0000 (MMIO base)
    e_u(OP_LUI, 3, 0x00000),  # x3 = 0x0000_0000 (data memory base)

    # Access 4 unique words to create 4 misses.
    e_i(OP_LOAD, 2, 10, 3, 0),   # lw x10, 0(x3)
    e_i(OP_LOAD, 2, 11, 3, 4),   # lw x11, 4(x3)
    e_i(OP_LOAD, 2, 12, 3, 8),   # lw x12, 8(x3)
    e_i(OP_LOAD, 2, 13, 3, 12),  # lw x13, 12(x3)

    # Revisit cached words for 6 hits.
    e_i(OP_LOAD, 2, 14, 3, 0),   # lw x14, 0(x3)
    e_i(OP_LOAD, 2, 15, 3, 4),   # lw x15, 4(x3)
    e_i(OP_LOAD, 2, 16, 3, 8),   # lw x16, 8(x3)
    e_i(OP_LOAD, 2, 17, 3, 12),  # lw x17, 12(x3)
    e_i(OP_LOAD, 2, 18, 3, 0),   # lw x18, 0(x3)
    e_i(OP_LOAD, 2, 19, 3, 4),   # lw x19, 4(x3)

    # Light the lowest 10 LEDs to mark completion.
    e_i(OP_IMM, 0, 4, 0, 1023),  # addi x4, x0, 1023
    e_s(OP_STORE, 2, 2, 4, 0),   # sw x4, 0(x2)

    # Hold the result forever.
    e_j(OP_JAL, 0, 0),           # jal x0, 0
]


with open("riscv-32im.srcs/sources_1/imports/5-stage-version/imem_fpga.hex", "w") as f:
    for instr in instructions:
        f.write(f"{instr:08x}\n")


print("Generated deterministic FPGA demo: 10 accesses = 4 misses + 6 hits.")
