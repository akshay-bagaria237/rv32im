# RISC-V 32IM Pipelined Processor

A 5-stage pipelined RISC-V processor implementing the **RV32IM** instruction set (Integer + Multiply/Divide), with extensions for floating-point operations, L1/L2 cache hierarchy, and branch prediction. Designed for **Xilinx Nexys A7 FPGA** (Artix-7).

## Features

### Core Pipeline (5 Stages)
| Stage | Module | Description |
|-------|--------|-------------|
| **IF** | `fetch.v` | PC update logic + instruction memory (IMEM) |
| **ID** | `decode.v` | Register file (32×32-bit) with bypass, immediate generator, control unit |
| **EX** | `execute.v` | ALU, forwarding muxes, branch/jump logic |
| **MEM** | `memory.v` | Data memory (DMEM), byte/halfword alignment, load/store |
| **WB** | `writeback.v` | Result mux (ALU / Memory / PC+4), register write-back |

### M-Extension (Multiply & Divide)
- **Multiplier** (`multiplier.v`) — single-cycle `MUL`, `MULH`, `MULHSU`, `MULHU`
- **Divider** (`divider.v`) — multi-cycle `DIV`, `DIVU`, `REM`, `REMU` with pipeline stalling

### Floating-Point Unit
- **FPU** (`fpu.v`) — IEEE 754 single-precision operations: add, subtract, multiply, divide, compare, min/max, convert

### Cache Hierarchy
- **L1 Cache** (`l1_cache.v`) — direct-mapped, low-latency
- **L2 Cache** (`l2_cache.v`) — larger, backs up L1

### Branch Prediction
- **BPB** (`bpb.v`) — 2-bit saturating counter branch prediction buffer

### Hazard Handling
- **Data forwarding** (EX→EX, MEM→EX) to minimize stalls
- **Load-use hazard** detection with automatic pipeline stall
- **Branch flushing** logic

### FPGA Features
- Clock divider (~12 Hz from 100 MHz) for visible execution
- 7-segment display output (program results + cache metrics)
- LED output (PC tracking)
- UART transmit for projectile demo
- Switch-selectable display modes (L1 hits / L1 misses / total accesses / cycle count)

## Repository Structure

```
├── rtl/                        # Synthesizable RTL source code
│   ├── pipeline.v              # Top-level 5-stage pipeline
│   ├── opcode.vh               # Opcode/funct definitions
│   ├── trace_rom.v             # Branch trace ROM (for BPB demo)
│   ├── modules/                # Pipeline stage modules
│   │   ├── fetch.v
│   │   ├── decode.v
│   │   ├── execute.v
│   │   ├── memory.v
│   │   ├── writeback.v
│   │   ├── multiplier.v
│   │   ├── divider.v
│   │   ├── fpu.v
│   │   ├── l1_cache.v
│   │   ├── l2_cache.v
│   │   └── bpb.v
│   └── fpga_tops/              # FPGA top-level wrappers
│       ├── top_fpga.v          # Standard FPGA top
│       └── top_bpb_fpga.v      # BPB demo FPGA top
│
├── testbenches/                # Simulation testbenches
│   ├── tb_pipeline_final.v     # Full pipeline verification
│   ├── tb_pipeline_timing.v    # Timing analysis testbench
│   ├── tb_integration.v        # Integration tests
│   ├── tb_fpu.v                # FPU unit tests
│   ├── tb_cache_subsystem.v    # Cache subsystem tests
│   ├── tb_fpga_cache_demo.v    # FPGA cache demo testbench
│   ├── tb_bpb.v                # Branch predictor testbench
│   ├── test_min_max.v          # FPU min/max test
│   └── hex/                    # Test program hex files
│       ├── imem_final.hex
│       ├── dmem_final.hex
│       └── imem_fpu_mul_div.hex
│
├── demos/                      # FPGA demo programs
│   ├── default/                # Basic demo (LED/7-seg output)
│   ├── mul_div/                # Multiply/divide showcase
│   ├── fpu_demo/               # Floating-point operations demo
│   ├── cache_hit_heavy/        # Cache benchmark (high hit rate)
│   ├── cache_miss_heavy/       # Cache benchmark (high miss rate)
│   ├── cache_mixed_50/         # Cache benchmark (50/50)
│   ├── bpb/                    # Branch prediction demo
│   └── projectile_demo/        # Projectile physics simulation
│       ├── gen_projectile_hex.py
│       ├── projectile_math.c
│       ├── projectile_top.v
│       ├── uart_tx.v
│       ├── visualizer.py       # Real-time trajectory plot
│       ├── projectile_imem.hex
│       └── projectile_dmem.hex
│
├── scripts/                    # Utility & build scripts
│   ├── gen_hex_fixed.py        # Hex file generator
│   ├── gen_cache_demo.py       # Cache demo hex generator
│   ├── gen_bpb_hex.py          # BPB demo hex generator
│   ├── gen_rom.py              # ROM generator
│   ├── switch_demo.ps1         # PowerShell demo switcher
│   └── tcl/                    # Vivado TCL scripts
│       ├── program_fpga.tcl
│       ├── program_fpga_robust.tcl
│       ├── run_bitstream.tcl
│       ├── setup_projectile_demo.tcl
│       └── ...
│
├── docs/                       # Documentation
│   ├── RISCV_Pipeline_Diagrams.txt
│   ├── fpu_builder_guide.md
│   └── fpu_detailed_explanation.md
│
├── fpga_constraints.xdc        # Xilinx FPGA pin constraints (Nexys A7)
└── .gitignore
```

## Pipeline Architecture

```
  ┌───────┐    ┌────────┐    ┌─────────┐    ┌────────┐    ┌──────────┐
  │  IF   │───▶│   ID   │───▶│   EX    │───▶│  MEM   │───▶│    WB    │
  │ Fetch │    │ Decode │    │ Execute │    │ Memory │    │Writeback │
  └───────┘    └────────┘    └─────────┘    └────────┘    └──────────┘
      ▲            │              │              │              │
      │            ▼              │              │              │
      │      ┌───────────┐       │              │              │
      │      │  Hazard   │       │              │              │
      │      │   Unit    │       │              │              │
      │      └───────────┘       │              │              │
      │            │              ▼              ▼              │
      │      ┌────────────────────────────────────────┐        │
      │      │          Forwarding Logic              │        │
      │      └────────────────────────────────────────┘        │
      │                          │                              │
      └───────────────[Branch Logic]───────────────────────────┘
```

## Target Hardware

- **FPGA Board**: Digilent Nexys A7 (Xilinx Artix-7 XC7A100T)
- **Tool**: Xilinx Vivado 2024.x+

## Getting Started

### Prerequisites
- Xilinx Vivado (for synthesis, simulation, and FPGA programming)
- Python 3.x (for hex generation and visualization scripts)

### Quick Start

1. **Open in Vivado**: Create a new project and add all files from `rtl/` as sources, `testbenches/` as simulation sources, and `fpga_constraints.xdc` as constraints.

2. **Run a simulation**:
   ```
   # In Vivado, set the desired testbench as the top simulation module
   # e.g., tb_pipeline_final with hex files from testbenches/hex/
   ```

3. **Synthesize & program FPGA**:
   ```bash
   vivado -mode batch -source scripts/tcl/run_bitstream.tcl
   vivado -mode batch -source scripts/tcl/program_fpga.tcl
   ```

4. **Switch demo programs**: Use `scripts/switch_demo.ps1` to swap between different demo hex files.

### Running the Projectile Demo

See the full demo guide in `demos/projectile_demo/`:

```bash
cd demos/projectile_demo
python gen_projectile_hex.py          # Generate hex files
vivado -mode batch -source ../../scripts/tcl/setup_projectile_demo.tcl
python visualizer.py                  # Real-time trajectory visualization
```

## Documentation

- [Pipeline Block Diagrams](docs/RISCV_Pipeline_Diagrams.txt) — ASCII art diagrams of pipeline stages, execute module internals, and memory module
- [FPU Builder Guide](docs/fpu_builder_guide.md) — How the floating-point unit was designed and integrated
- [FPU Detailed Explanation](docs/fpu_detailed_explanation.md) — IEEE 754 implementation details
