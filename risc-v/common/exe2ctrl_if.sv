// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe2ctrl_if.sv
\brief      EXE->CTRL interface definition for scholar risc-v

\author     Kawanami
\date       20/04/2026
\version    1.0

\details
  This interface groups all signals transferred from the Execute (EXE) stage
  to the Controller (CTRL).

  It provides the controller with the information required to:
    - update the program counter
    - assist data hazard detection logic
    - detect and manage control hazards

\remarks
  - The producer modport is intended for the EXE stage.
  - The consumer modport is intended for the CTRL stage.

\section exe2ctrl_if_version_history Version history
| Version | Date       | Author   | Description                               |
|:-------:|:----------:|:---------|:------------------------------------------|
| 1.0     | 20/04/2026 | Kawanami | Initial EXE->CTRL interface definition.   |
********************************************************************************
*/

interface exe2ctrl_if #(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
);

  import core_pkg::PC_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;

  /// Program counter
  logic [         Archi - 1 : 0] pc;
  /// Destination register
  logic [ RF_ADDR_WIDTH - 1 : 0] rd;
  /// CSR file write address
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
  /// Execute stage result
  logic [         Archi - 1 : 0] exe_out;
  /// Third operand: Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
  logic [         Archi - 1 : 0] op3;
  /// PC (controller) control signal
  logic [ PC_CTRL_WIDTH - 1 : 0] pc_ctrl;
  /// CSR (writeback) control signal
  logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;

  /// Producer
  modport producer(
      output pc,
      output rd,
      output csr_waddr,
      output exe_out,
      output op3,
      output pc_ctrl,
      output csr_ctrl
  );

  /// Consumer
  modport consumer(
      input pc,
      input rd,
      input csr_waddr,
      input exe_out,
      input op3,
      input pc_ctrl,
      input csr_ctrl
  );

endinterface
