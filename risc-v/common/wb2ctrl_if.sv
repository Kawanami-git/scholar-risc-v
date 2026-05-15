// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       wb2ctrl_if.sv
\brief      WB->CTRL interface definition for scholar risc-v

\author     Kawanami
\date       20/04/2026
\version    1.0

\details
  This interface groups all signals transferred from the Write-Back (WB) stage
  to the Controller (CTRL) stage.

  It provides the controller with the information required to:
    - assist data hazard detection logic

\remarks
  - The producer modport is intended for the WB stage.
  - The consumer modport is intended for the CTRL stage.

\section wb2ctrl_if_version_history Version history
| Version | Date       | Author   | Description                              |
|:-------:|:----------:|:---------|:-----------------------------------------|
| 1.0     | 20/04/2026 | Kawanami | Initial WB->CTRL interface definition.   |
********************************************************************************
*/


interface wb2ctrl_if;

  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;

  /// Destination register
  logic [RF_ADDR_WIDTH  - 1 : 0] rd;
  /// CSR file write address
  logic [CSR_ADDR_WIDTH - 1 : 0] csr_waddr;
  /// CSR (writeback) control signal
  logic [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl;

  /// Producer
  modport producer(output rd, output csr_waddr, output csr_ctrl);

  /// Consumer
  modport consumer(input rd, input csr_waddr, input csr_ctrl);

endinterface
