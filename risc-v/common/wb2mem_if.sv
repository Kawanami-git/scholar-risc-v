// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       wb2mem_if.sv
\brief      WB->MEM interface definition for scholar risc-v

\author     Kawanami
\date       16/05/2026
\version    1.0

\details
  This interface groups all signals transferred from the Writeback (WB) stage
  to the Memory (MEM) stage.

  It provides the Memory stage with bypass data used to resolve data hazards
  when an operand can be forwarded from the current instruction in the Writeback
  stage instead of waiting for the value to be read from the register file.

  It bundles:
    - bypass : ALU output, operand/result, or loaded data forwarded from the
               Writeback stage.

\remarks
  - The producer modport is intended for the WB stage.
  - The consumer modport is intended for the MEM stage.
  - Field widths follow settings defined in core_pkg.

\section wb2mem_if_version_history Version history
| Version | Date       | Author   | Description                                |
|:-------:|:----------:|:---------|:-------------------------------------------|
| 1.0     | 16/05/2026 | Kawanami | Initial WB->MEM bypass interface definition. |
********************************************************************************
*/

interface wb2mem_if #(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
);

  /// Bypass data forwarded from the Writeback stage to the Memory stage.
  logic [Archi - 1 : 0] bypass;

  /// Producer
  modport producer(
      output bypass
  );

  /// Consumer
  modport consumer(
      input bypass
  );

endinterface
