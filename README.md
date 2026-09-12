# 🚀 RV32I 5-Stage Pipelined Processor

A highly optimized, Verilog-based 32-bit RISC-V processor targeting the **Xilinx Artix-7 FPGA**. This project implements a classic 5-stage pipeline with robust hardware hazard management, comprehensive data forwarding, and targeted power optimizations.

---

## 📌 Project Highlights
* **Verilog-based 32-bit RISC-V processor implementation on FPGA using Xilinx Vivado with pipeline optimization and hardware verification.**
* **Built a 5-stage RV32I processor pipeline in Verilog using Xilinx Vivado, implementing complete data forwarding and hazard handling logic.**
* **Optimized ALU datapath architecture to reduce dynamic power to 28.0 mW by utilizing targeted operand isolation techniques throughout.**
* **Deferred branch logic to MEM stage for strict timing closure, achieving maximum clock frequency of 118.7 MHz with positive margins.**
* **Verified RTL functionality across comprehensive test suites, achieving compact implementation using 1086 LUTs and 605 FPGA registers.**

---

## 🏗️ Architecture Overview

The core is designed following the **RV32I Base Integer Instruction Set** and implements a textbook 5-stage pipeline:
1. **Instruction Fetch (IF)**: Program Counter logic and Instruction Memory access.
2. **Instruction Decode (ID)**: Instruction parsing, Register File read, and Immediate generation.
3. **Execute (EX)**: Arithmetic Logic Unit (ALU) operations and target calculations.
4. **Memory (MEM)**: Data Memory access and branch resolution.
5. **Writeback (WB)**: Committing results back to the Register File.

### 🔥 Advanced Hardware Features
* **Full Data Forwarding (Bypassing)**: Seamlessly routes data from the `MEM` or `WB` stages back to the `EX` stage, resolving Read-After-Write (RAW) data hazards instantly without halting execution.
* **Load-Use Hazard Detection**: Hardware automatically intercepts load-use dependencies (an instruction immediately attempting to use `lw` data), injecting precisely one stall bubble.
* **Aggressive Timing Optimization**: Branch resolution (`beq`, `bne`, etc.) and `jalr` target logic were intentionally deferred to the `MEM` stage. This slices the critical path in half, enabling high-frequency FPGA timing closure.
* **Low-Power Datapath**: Employs **Operand Isolation** at the ALU inputs. When the ALU is idle (e.g., during memory operations or stalls), the inputs are frozen to `0`, preventing millions of unnecessary logic toggles and slashing dynamic power consumption.
* **Transparent Register File**: Supports write-before-read bypassing internally, eliminating WB-to-ID register collisions.

---

## 📊 Synthesis & Performance Metrics
The design was synthesized Out-Of-Context (OOC) using **Vivado 2025.2** to accurately measure the raw CPU core footprint, excluding external block RAM and I/O buffer delays.

| Metric | Target / Result |
| :--- | :--- |
| **Target FPGA** | Xilinx Artix-7 (`xc7a100tcsg324-1`) |
| **Maximum Frequency** | 118.7 MHz (8.42 ns Critical Path) |
| **Logic Utilization** | 1086 Slice LUTs |
| **Register Utilization** | 605 Slice Registers |
| **Dynamic Power** | 28.0 mW |

---

## 🛠️ Repository Structure
```text
├── rv32i_core.v        # Main RTL containing the 5-stage pipeline and hazard units
├── tb_rv32i_core.v     # Testbench containing simulation checks and memory instantiation
├── imem.mem            # Hex payload for Instruction Memory (Assembly Test Suite)
├── dmem.mem            # Hex payload for Data Memory
├── constraints.xdc     # Timing constraints for Vivado Synthesis (118.7 MHz)
└── README.md           # Project documentation
```

---

## 🚀 How to Run & Simulate
1. Open **Xilinx Vivado** and create a new RTL Project targeting your specific FPGA (e.g., Artix-7).
2. Add `rv32i_core.v` to the **Design Sources**.
3. Add `tb_rv32i_core.v`, `imem.mem`, and `dmem.mem` to the **Simulation Sources**.
4. Add `constraints.xdc` to the **Constraints**.
5. Run **Behavioral Simulation**. The testbench executes a comprehensive suite of hazards, forwarding chains, and branches. It will halt and print `Test Passed` to the TCL console when execution completes successfully.
6. Run **Synthesis** (Ensure `-mode out_of_context` is set if you want to replicate the raw CPU footprint metrics).
