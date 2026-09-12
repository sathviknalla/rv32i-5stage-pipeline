# RV32I 5-Stage Pipelined Processor

Verilog-based 32-bit RISC-V processor implementation on FPGA using Xilinx Vivado with pipeline optimization and hardware verification.

* Built a 5-stage RV32I processor pipeline in Verilog using Xilinx Vivado, implementing complete data forwarding and hazard handling logic.
* Optimized ALU datapath architecture to reduce dynamic power to 28.0 mW by utilizing targeted operand isolation techniques throughout.
* Deferred branch logic to MEM stage for strict timing closure, achieving maximum clock frequency of 118.7 MHz with positive margins.
* Verified RTL functionality across comprehensive test suites, achieving compact implementation using 1086 LUTs and 605 FPGA registers.

## Architecture Highlights
* **ISA**: Fully implements the RV32I Base Integer Instruction Set (Arithmetic, Logic, Load/Store, Branch, JAL, JALR, LUI, AUIPC).
* **Hazard Management**: Implements full hardware bypassing (EX-to-EX, MEM-to-EX) to resolve data hazards without stalling.
* **Load-Use Stalls**: Hardware detection of Load-Use hazards, automatically injecting a 1-cycle stall bubble when a consumer directly follows a `lw`.
* **Control Flow**: Resolves branches in the MEM stage to significantly shorten the critical path, issuing 3-cycle pipeline flushes upon taken branches.
* **Internal Register Bypassing**: The Register File supports transparent Write-Before-Read bypassing, eliminating WB-to-ID hazards natively.

## Implementation Details
The core logic was designed to decouple the massive Instruction/Data Memory footprints from the CPU's internal architecture metrics.
* **Target Device**: Xilinx Artix-7 (`xc7a100tcsg324-1`)
* **Synthesis Tool**: Vivado 2025.2
* **Max Frequency**: 118.7 MHz (8.42 ns Critical Path)
* **Resource Utilization**: 1086 Slice LUTs, 605 Slice Registers

## Running the Code
1. Open Vivado and create a new project targeting your FPGA (e.g., Artix-7).
2. Add `rv32i_core.v` as the design source.
3. Add `tb_rv32i_core.v`, `imem.mem`, and `dmem.mem` as simulation sources.
4. Add `constraints.xdc` as the timing constraint file.
5. Run Behavioral Simulation. The testbench asserts completion when `0x1` is written to address `0xFFC`.
6. Run Synthesis in `out_of_context` mode to measure the CPU core's physical footprint cleanly.
