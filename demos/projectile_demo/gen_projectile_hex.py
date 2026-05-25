import struct
import os

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

instructions = []
labels = {}

def add_inst(name, code):
    instructions.append((name, code))

def add_label(name):
    labels[name] = len(instructions)

def resolve_j(opcode, rd, target_label):
    def linker(pc, inst_idx):
        target_idx = labels[target_label]
        offset = (target_idx - inst_idx) * 4
        return encode_j(opcode, rd, offset)
    return linker

def resolve_b(opcode, funct3, rs1, rs2, target_label):
    def linker(pc, inst_idx):
        target_idx = labels[target_label]
        offset = (target_idx - inst_idx) * 4
        return encode_b(opcode, funct3, rs1, rs2, offset)
    return linker

def add_uart_send(rs_idx):
    # Send data from rs_idx directly to UART data register (0x80000008)
    add_inst(f"sw x{rs_idx}, 8(x3)", encode_s(0x23, 2, 3, rs_idx, 8))
    # Safe delay for 115200 baud at 6.25MHz (approx 1000 cycles)
    add_inst("addi x1, x0, 1000", encode_i(0x13, 0, 1, 0, 1000))
    add_label(f"uart_delay_{len(instructions)}")
    add_inst("addi x1, x1, -1", encode_i(0x13, 0, 1, 1, -1))
    add_inst("bne x1, x0, -4", encode_b(0x63, 1, 1, 0, -4))

# x3 = MMIO base 0x80000000
add_inst("lui x3, 0x80000", encode_u(0x37, 3, 0x80000))

# Load Constants (f11=g, f12=zero, f13=scale)
add_inst("lw x11, 0x100(x0)", encode_i(0x03, 2, 11, 0, 0x100)) # g (0.5)
add_inst("lw x12, 0x104(x0)", encode_i(0x03, 2, 12, 0, 0x104)) # zero (0.0)
add_inst("lw x13, 0x108(x0)", encode_i(0x03, 2, 13, 0, 0x108)) # scale (1.0)
add_inst("addi x26, x0, 1", encode_i(0x13, 0, 26, 0, 1))

add_label("STARTUP_WAIT")
add_inst("lui x30, 500", encode_u(0x37, 30, 500)) 
add_label("START_DELAY_LOOP")
add_inst("addi x30, x30, -1", encode_i(0x13, 0, 30, 30, -1))
add_inst("bne x30, x0, -4", encode_b(0x63, 1, 30, 0, -4))

add_label("OUTER_LOOP")
add_inst("lw x4, 4(x3)", encode_i(0x03, 2, 4, 3, 4)) 

# Extract vy=sw[7:4] (x5), vx=sw[3:0] (x6)
add_inst("srli x5, x4, 4", encode_i(0x13, 5, 5, 4, 4))
add_inst("andi x5, x5, 0xF", encode_i(0x13, 7, 5, 5, 0xF))
add_inst("addi x5, x5, 10", encode_i(0x13, 0, 5, 5, 10)) # Min Power = 10
add_inst("andi x6, x4, 0xF", encode_i(0x13, 7, 6, 4, 0xF))
add_inst("addi x6, x6, 10", encode_i(0x13, 0, 6, 6, 10)) # Min Speed = 10

# Convert to Float (x14=vx, x15=vy)
add_inst("fcvt.s.w x15, x5", encode_r(0x53, 0, 104, 15, 5, 0))
add_inst("fmul.s x15, x15, x13", encode_r(0x53, 0, 8, 15, 15, 13)) 
add_inst("fcvt.s.w x14, x6", encode_r(0x53, 0, 104, 14, 6, 0))
add_inst("fmul.s x14, x14, x13", encode_r(0x53, 0, 8, 14, 14, 13)) 

add_inst("fcvt.s.w x16, x0", encode_r(0x53, 0, 104, 16, 0, 0)) 
add_inst("fcvt.s.w x17, x0", encode_r(0x53, 0, 104, 17, 0, 0)) 

add_label("PHYSICS_LOOP")
add_inst("fcvt.w.s x27, x16", encode_r(0x53, 0, 96, 27, 16, 0)) 
add_inst("fcvt.w.s x28, x17", encode_r(0x53, 0, 96, 28, 17, 0)) 

add_inst("addi x1, x0, 170", encode_i(0x13, 0, 1, 0, 170)) 
add_uart_send(1) 
add_uart_send(27) 
add_inst("sw x27, 0(x3)", encode_s(0x23, 2, 3, 27, 0)) 
add_uart_send(28) 
add_inst("addi x1, x0, 85", encode_i(0x13, 0, 1, 0, 85))  
add_uart_send(1) 

add_inst("fadd.s x17, x17, x15", encode_r(0x53, 0, 0, 17, 17, 15)) 
add_inst("fsub.s x15, x15, x11", encode_r(0x53, 0, 4, 15, 15, 11)) 
add_inst("fadd.s x16, x16, x14", encode_r(0x53, 0, 0, 16, 16, 14)) 

add_inst("flt.s x1, x17, x12", encode_r(0x53, 1, 80, 1, 17, 12))
add_inst("beq x1, x26, BREAK", resolve_b(0x63, 0, 1, 26, "BREAK"))

# Shorter Delay for responsiveness
add_inst("lui x30, 20", encode_u(0x37, 30, 20)) 
add_label("DELAY_FAST")
add_inst("addi x30, x30, -1", encode_i(0x13, 0, 30, 30, -1))
add_inst("bne x30, x0, -4", encode_b(0x63, 1, 30, 0, -4))
add_inst("jal x0, PHYSICS_LOOP", resolve_j(0x6F, 0, "PHYSICS_LOOP"))

add_label("BREAK")
add_inst("lui x30, 2000", encode_u(0x37, 30, 2000)) 
add_label("IMPACT_WAIT")
add_inst("addi x30, x30, -1", encode_i(0x13, 0, 30, 30, -1))
add_inst("bne x30, x0, -4", encode_b(0x63, 1, 30, 0, -4))
add_inst("jal x0, OUTER_LOOP", resolve_j(0x6F, 0, "OUTER_LOOP"))


# Files
hex_path = "C:\Users\parya\OneDrive\Desktop\lab5\final_till_22_4_26\riscv-32im\projectile_demo\projectile_imem.hex"
with open(hex_path, "w") as f:
    for i, (name, code) in enumerate(instructions):
        val = code(0, i) if callable(code) else code
        f.write(f"{val:08x} // {name}\n")
    for _ in range(1024 - len(instructions)): f.write("00000013 // nop\n")

dmem_path = "C:\Users\parya\OneDrive\Desktop\lab5\final_till_22_4_26\riscv-32im\projectile_demo\projectile_dmem.hex"
with open(dmem_path, "w") as f:
    for _ in range(64): f.write("00000000\n")
    f.write(f"{struct.unpack('<I', struct.pack('<f', 0.5))[0]:08x}\n") # 0x100 g (0.5)
    f.write(f"{struct.unpack('<I', struct.pack('<f', 0.0))[0]:08x}\n") # 0x104 zero
    f.write(f"{struct.unpack('<I', struct.pack('<f', 1.0))[0]:08x}\n") # 0x108 scale (1.0)
    for _ in range(1024 - 67): f.write("00000000\n")
