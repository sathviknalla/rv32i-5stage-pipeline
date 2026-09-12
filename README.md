# 🚀 RV32I 5-Stage Pipelined Processor

A highly optimized, Verilog-based 32-bit RISC-V processor targeting the **Xilinx Artix-7 FPGA**. This project implements a strictly compliant 5-stage pipeline with advanced hardware hazard management, comprehensive data forwarding, and custom low-power datapath techniques.

---

## 📌 Project Highlights
* **Verilog-based 32-bit RISC-V processor implementation on FPGA using Xilinx Vivado with pipeline optimization and hardware verification.**
* **Built a 5-stage RV32I processor pipeline in Verilog using Xilinx Vivado, implementing complete data forwarding and hazard handling logic.**
* **Optimized ALU datapath architecture to reduce dynamic power to 28.0 mW by utilizing targeted operand isolation techniques throughout.**
* **Deferred branch logic to MEM stage for strict timing closure, achieving maximum clock frequency of 118.7 MHz with positive margins.**
* **Verified RTL functionality across comprehensive test suites, achieving compact implementation using 1086 LUTs and 605 FPGA registers.**

---

## 🛠️ ISA Compliance & Technical Foundations

This core strictly adheres to the official **RV32I Base Integer Instruction Set** specifications, ensuring full architectural correctness:
* **Register x0 Hardwiring**: Hardware enforces `x0` reads as absolute `0` and ignores all writes to address `0`, preventing software from corrupting the zero register.
* **JALR Bit-Masking**: The LSB of the Jump and Link Register target address is forcefully cleared `(& ~1)` in the ALU to maintain proper instruction alignment per RISC-V specs.
* **Precise Sign-Extension**: Implements exact signed/unsigned arithmetic boundaries (`slt` vs `sltu`), ensuring proper 2's complement arithmetic and signed immediate expansion.
* **5-Stage RISC Architecture**: Instruction Fetch (`IF`), Instruction Decode (`ID`), Execute (`EX`), Memory (`MEM`), and Writeback (`WB`).

---

## ✨ What's New: Custom Architectural Optimizations

While standard textbook pipelines achieve functional correctness, they often suffer from poor frequency scaling and high power draw on FPGAs. We implemented several advanced techniques to shatter those limits:

### 1. Deferred Branch Resolution (Frequency Optimization)
In a standard 5-stage pipeline, evaluating branch conditions (`beq`, `bne`) and computing jump targets inside the Execute (`EX`) stage creates a massive combinational critical path: `Data Forwarding Mux` $\rightarrow$ `ALU Addition` $\rightarrow$ `Branch Evaluation` $\rightarrow$ `PC Target Mux`. 
* **The Fix**: We completely re-architected the pipeline to push `pc_redirect` evaluation into the Memory (`MEM`) stage.
* **The Result**: By eating a 3-cycle flush penalty instead of a 2-cycle penalty on taken branches, we physically separated the ALU logic from the PC multiplexing logic. This sliced the critical path down to just **8.42 ns**, safely pushing the core to **118.7 MHz** on an Artix-7.

### 2. Operand Isolation (Dynamic Power Reduction)
During memory loads (`lw`), stores (`sw`), or pipeline stall bubbles (`NOPs`), the ALU typically continues to evaluate random garbage data coming off the forwarding multiplexers, needlessly flipping billions of transistor gates.
* **The Fix**: We implemented a technique called **Operand Isolation**. The Control Unit now explicitly disables the ALU via an `alu_en` signal. When disabled, the ALU inputs are mathematically clamped to `0`.
* **The Result**: Static gate freezing drastically reduced the switching activity factor of the Carry-Chains, dropping the core's total dynamic power to a remarkably low **28.0 mW**.

### 3. Hazard Immunity & Transparent Bypassing
* **Load-Use Hardware Interlocking**: A dedicated Hazard Unit continuously monitors the `EX` stage for memory reads. If a consumer instruction immediately follows a load, the hardware freezes the `PC` and `IF/ID` registers, inserting exactly one `NOP` bubble to wait for RAM.
* **EX-to-EX & MEM-to-EX Forwarding**: Data dependencies are bypassed mid-flight. Arithmetic results are routed backwards in time to the ALU inputs, completely eliminating stall penalties for mathematical sequences.
* **Write-Before-Read Register File**: The register file acts transparently; data written on the rising clock edge is instantaneously visible to the read ports on that exact same cycle, natively eliminating `WB`-to-`ID` hazards.

---

## 📊 Synthesis & Performance Metrics
The design was synthesized Out-Of-Context (OOC) using **Vivado 2025.2** to accurately measure the raw CPU core footprint, explicitly excluding external block RAM and I/O buffer delays to provide genuine resume metrics.

| Metric | Target / Result |
| :--- | :--- |
| **Target FPGA** | Xilinx Artix-7 (`xc7a100tcsg324-1`) |
| **Maximum Frequency** | 118.7 MHz (8.42 ns Critical Path) |
| **Logic Utilization** | 1086 Slice LUTs |
| **Register Utilization** | 605 Slice Registers |
| **Dynamic Power** | 28.0 mW |

---

## 🚀 How to Run & Simulate
1. Open **Xilinx Vivado** and create a new RTL Project targeting your specific FPGA (e.g., Artix-7).
2. Add `rv32i_core.v` to the **Design Sources**.
3. Add `tb_rv32i_core.v`, `imem.mem`, and `dmem.mem` to the **Simulation Sources**.
4. Add `constraints.xdc` to the **Constraints**.
5. Run **Behavioral Simulation**. The testbench executes a comprehensive suite of hazards, forwarding chains, and branches. It will halt and print `Test Passed` to the TCL console when execution completes successfully.
6. Run **Synthesis** (Ensure `-mode out_of_context` is set if you want to replicate the raw CPU footprint metrics).
