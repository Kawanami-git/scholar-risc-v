// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe2mem_if.sv
\brief      EXE->MEM interface definition for scholar risc-v

\author     Kawanami
\date       20/04/2026
\version    1.0

\details
  This interface groups all signals transferred from the Execute (EXE) stage
  to the Memory (MEM) stage.

  It provides the memory stage with the information required to:
    - forward the EXE result
    - carry store data or auxiliary operand information
    - propagate destination register and CSR metadata
    - transmit memory, GPR, and CSR control commands

\remarks
  - The producer modport is intended for the EXE stage.
  - The consumer modport is intended for the MEM stage.

\section exe2mem_if_version_history Version history
| Version | Date       | Author   | Description                               |
|:-------:|:----------:|:---------|:------------------------------------------|
| 1.0     | 20/04/2026 | Kawanami | Initial EXE->MEM interface definition.    |
********************************************************************************
*/



interface exe2mem_if #(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
);

  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;

  /// Execute stage result
  logic [         Archi - 1 : 0] exe_out;
  /// Third operand: Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
  logic [         Archi - 1 : 0] op3;
  /// Destination register
  logic [RF_ADDR_WIDTH  - 1 : 0] rd;
  /// CSR file write address
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
  /// Memory stage control signal
  logic [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl;
  /// GPR (writeback) control signal
  logic [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl;
  /// CSR (writeback) control signal
  logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;

  /// Producer
  modport producer(
      output exe_out,
      output op3,
      output rd,
      output csr_waddr,
      output mem_ctrl,
      output gpr_ctrl,
      output csr_ctrl
  );

  /// Consumer
  modport consumer(
      input exe_out,
      input op3,
      input rd,
      input csr_waddr,
      input mem_ctrl,
      input gpr_ctrl,
      input csr_ctrl
  );

endinterface
