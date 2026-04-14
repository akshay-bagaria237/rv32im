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