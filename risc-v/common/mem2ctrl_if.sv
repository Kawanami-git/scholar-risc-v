// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem2ctrl_if.sv
\brief      MEM->CTRL interface definition for scholar risc-v

\author     Kawanami
\date       16/05/2026
\version    1.0

\details
  This interface groups all signals transferred from the Memory (MEM) stage
  to the Controller (CTRL) stage.

  It provides the controller with the information required to:
    - assist data hazard detection logic

\remarks
  - The producer modport is intended for the MEM stage.
  - The consumer modport is intended for the CTRL stage.

\section mem2ctrl_if_version_history Version history
| Version | Date       | Author   | Description                               |
|:-------:|:----------:|:---------|:------------------------------------------|
| 1.0     | 16/05/2026 | Kawanami | Initial MEM->CTRL interface definition.   |
********************************************************************************
*/

interface mem2ctrl_if;

  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;

  /// Instruction is load flag
  logic is_load;
  /// Destination register
  logic [RF_ADDR_WIDTH  - 1 : 0] rd;
  /// CSR file write address
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
  /// CSR (writeback) control signal
  logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;

  /// Producer
  modport producer(output is_load, output rd, output csr_waddr, output csr_ctrl);

  /// Consumer
  modport consumer(input is_load, input rd, input csr_waddr, input csr_ctrl);

endinterface
