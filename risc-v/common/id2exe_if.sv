// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       id2exe_if.sv
\brief      ID->EXE interface definition for scholar risc-v

\author     Kawanami
\date       16/05/2026
\version    1.0

\details
  This interface groups all signals transferred from the Decode (ID) stage
  to the Execute (EXE) stage.

  It provides the execute stage with the information required to:
    - forward the decoded instruction context
    - carry ALU operands and auxiliary data
    - propagate destination register and CSR metadata
    - transmit EXE, MEM, CSR, GPR, and PC control commands

\remarks
  - The producer modport is intended for the ID stage.
  - The consumer modport is intended for the EXE stage.

\section id2exe_if_version_history Version history
| Version | Date       | Author   | Description                              |
|:-------:|:----------:|:---------|:-----------------------------------------|
| 1.0     | 16/05/2026 | Kawanami | Initial ID->EXE interface definition.    |
********************************************************************************
*/



interface id2exe_if #(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
);

  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::EXE_CTRL_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::PC_CTRL_WIDTH;
  import core_pkg::SEL_CTRL_WIDTH;

  /// Program counter
  logic [         Archi - 1 : 0] pc;
  /// First operand: RS1 value or zeroes
  logic [         Archi - 1 : 0] op1;
  /// Second operand: RS2 value (REG_OP or BRANCH_OP) or immediate
  logic [         Archi - 1 : 0] op2;
  /// Third operand: Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
  logic [         Archi - 1 : 0] op3;
  // Exe stage operand 1 selector
  // logic [SEL_CTRL_WIDTH - 1 : 0] exe_op1_sel;
  // Exe stage operand 2 selector
  // logic [SEL_CTRL_WIDTH - 1 : 0] exe_op2_sel;
  /// Exe stage operand 3 selector
  logic [SEL_CTRL_WIDTH - 1 : 0] exe_op3_sel;
  // Mem stage operand 3 selector
  // logic [SEL_CTRL_WIDTH - 1 : 0] mem_op3_sel;
  /// Destination register
  logic [RF_ADDR_WIDTH  - 1 : 0] rd;
  /// CSR file write address
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
  /// Exe stage control signal
  logic [EXE_CTRL_WIDTH - 1 : 0] exe_ctrl;
  /// Memory stage control signal
  logic [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl;
  /// CSR (writeback) control signal
  logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;
  /// GPR (writeback) control signal
  logic [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl;
  /// PC (controller) control signal
  logic [PC_CTRL_WIDTH  - 1 : 0] pc_ctrl;

  /// Producer
  modport producer(
      output pc,
      output op1,
      output op2,
      output op3,
      // output exe_op1_sel,
      // output exe_op2_sel,
      output exe_op3_sel,
      // output mem_op3_sel,
      output rd,
      output csr_waddr,
      output exe_ctrl,
      output mem_ctrl,
      output csr_ctrl,
      output gpr_ctrl,
      output pc_ctrl
  );

  /// Consumer
  modport consumer(
      input pc,
      input op1,
      input op2,
      input op3,
      // input exe_op1_sel,
      // input exe_op2_sel,
      input exe_op3_sel,
      // input mem_op3_sel,
      input rd,
      input csr_waddr,
      input exe_ctrl,
      input mem_ctrl,
      input csr_ctrl,
      input gpr_ctrl,
      input pc_ctrl
  );

endinterface

