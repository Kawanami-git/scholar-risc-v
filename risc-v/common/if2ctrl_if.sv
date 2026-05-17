// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       if2ctrl_if.sv
\brief      IF->CTRL interface definition for scholar risc-v

\author     Kawanami
\date       16/05/2026
\version    1.0

\details
  This interface groups all signals transferred from the Instruction Fetch (IF)
  stage to the Controller (CTRL) stage.

  It provides the controller with the information required to:
    - detect and manage data hazards

\remarks
  - The producer modport is intended for the IF stage.
  - The consumer modport is intended for the CTRL stage.

\section if2ctrl_if_version_history Version history
| Version | Date       | Author   | Description                              |
|:-------:|:----------:|:---------|:-----------------------------------------|
| 1.0     | 16/05/2026 | Kawanami | Initial IF->CTRL interface definition.   |
********************************************************************************
*/

interface if2ctrl_if;

  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;

  /// Instruction is store flag
  logic is_store;
  /// Register file port 0 read address (rs1 index)
  logic [RF_ADDR_WIDTH  - 1 : 0] rs1;
  /// Register file port 1 read address (rs2 index)
  logic [RF_ADDR_WIDTH  - 1 : 0] rs2;
  /// CSR file read address
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_raddr;

  /// Producer
  modport producer(output is_store, output rs1, output rs2, output csr_raddr);

  /// Consumer
  modport consumer(input is_store, input rs1, input rs2, input csr_raddr);

endinterface
