# gen_rom.py
# Generates a trace for 20x20 nested loop
# Total branches: 421 (400 inner, 21 outer)

trace = []
# Outer loop starts
for i in range(21):
    # Outer check branch (i < 20)
    if i < 20:
        trace.append((0x20, 1)) # Taken
        # Inner loop
        for j in range(20):
            if j < 19:
                trace.append((0x10, 1)) # Inner Taken
            else:
                trace.append((0x10, 0)) # Inner Not Taken (exit)
    else:
        trace.append((0x20, 0)) # Outer Not Taken (exit)

# Truncate to exactly 421 if needed, or just use what we have
print(f"Generated {len(trace)} branches")

with open("demos/bpb/trace_rom.v", "w") as f:
    f.write("`timescale 1ns / 1ps\n\n")
    f.write("module trace_rom (\n")
    f.write("    input [8:0] addr,\n")
    f.write("    output reg [31:0] pc,\n")
    f.write("    output reg outcome\n")
    f.write(");\n\n")
    f.write("    always @(*) begin\n")
    f.write("        case (addr)\n")
    for idx, (pc, out) in enumerate(trace):
        f.write(f"            9'd{idx}: begin pc = 32'h{pc:x}; outcome = 1'b{out}; end\n")
    f.write("            default: begin pc = 32'h0; outcome = 1'b0; end\n")
    f.write("        endcase\n")
    f.write("    end\n")
    f.write("endmodule\n")
