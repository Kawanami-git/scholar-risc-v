// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem2wb_if.sv
\brief      MEM->WB interface definition for scholar risc-v

\author     Kawanami
\date       16/05/2026
\version    1.0

\details
  This interface groups all signals transferred from the Memory (MEM) stage
  to the Write-Back (WB) stage.

  It provides the write-back stage with the information required to:
    - forward the MEM-stage result (load-case)
    - propagate destination register and CSR metadata
    - transmit GPR, CSR, and memory control commands

\remarks
  - The producer modport is intended for the MEM stage.
  - The consumer modport is intended for the WB stage.

\section mem2wb_if_version_history Version history
| Version | Date       | Author   | Description                              |
|:-------:|:----------:|:---------|:-----------------------------------------|
| 1.0     | 16/05/2026 | Kawanami | Initial MEM->WB interface definition.    |
********************************************************************************
*/

interface mem2wb_if #(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
);

  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;

  /// Execute stage result
  logic [         Archi - 1 : 0] exe_out;
  /// Third operand: Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
  logic [         Archi - 1 : 0] op3;
  /// Destination register
  logic [RF_ADDR_WIDTH  - 1 : 0] rd;
  /// CSR file write address
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
  /// GPR (writeback) control signal
  logic [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl;
  /// CSR (writeback) control signal
  logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;
  /// Memory stage control signal
  logic [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl;

  /// Producer
  modport producer(
      output exe_out,
      output op3,
      output rd,
      output csr_waddr,
      output gpr_ctrl,
      output csr_ctrl,
      output mem_ctrl
  );

  /// Consumer
  modport consumer(
      input exe_out,
      input op3,
      input rd,
      input csr_waddr,
      input gpr_ctrl,
      input csr_ctrl,
      input mem_ctrl
  );

endinterface

