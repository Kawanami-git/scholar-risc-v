// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       wb2exe_if.sv
\brief      WB->EXE interface definition for scholar risc-v

\author     Kawanami
\date       16/05/2026
\version    1.0

\details
  This interface groups all signals transferred from the Writeback (WB) stage
  to the Execute (EXE) stage.

  It provides the Execute stage with bypass data used to resolve data hazards
  when an operand can be forwarded from the current instruction in the Writeback
  stage instead of waiting for the value to be read from the register file.

  It bundles:
    - bypass : ALU output, operand/result, or loaded data forwarded from the
               Writeback stage.

\remarks
  - The producer modport is intended for the WB stage.
  - The consumer modport is intended for the EXE stage.
  - Field widths follow settings defined in core_pkg.

\section wb2exe_if_version_history Version history
| Version | Date       | Author   | Description                               |
|:-------:|:----------:|:---------|:------------------------------------------|
| 1.0     | 16/05/2026 | Kawanami | Initial WB->EXE bypass interface definition. |
********************************************************************************
*/

interface wb2exe_if #(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
);

  /// Bypass data forwarded from the Writeback stage to the Execute stage.
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
