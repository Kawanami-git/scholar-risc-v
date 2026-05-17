// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe2id_if.sv
\brief      EXE->ID interface definition for scholar risc-v

\author     Kawanami
\date       16/05/2026
\version    1.0

\details
  This interface groups all signals transferred from the Execution (EXE) stage
  to the Instruction Decode (ID) stage.

  It provides the Decode stage with bypass data used to resolve data hazards
  when an operand can be forwarded from the current instruction in the Execute
  stage instead of waiting for the value to be written back.

  It bundles:
    - bypass : ALU output or operand/result forwarded from the Execute stage.

\remarks
  - The producer modport is intended for the EXE stage.
  - The consumer modport is intended for the ID stage.
  - Field widths follow settings defined in core_pkg.

\section exe2id_if_version_history Version history
| Version | Date       | Author   | Description                               |
|:-------:|:----------:|:---------|:------------------------------------------|
| 1.0     | 16/05/2026 | Kawanami | Initial EXE->ID bypass interface definition. |
********************************************************************************
*/

interface exe2id_if #(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
);

  /// Bypass data forwarded from the Execute stage to the Decode stage.
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
