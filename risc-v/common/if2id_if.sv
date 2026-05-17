// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       if2id_if.sv
\brief      IF->ID interface definition for scholar risc-v

\author     Kawanami
\date       16/05/2026
\version    1.0

\details
  This interface groups all signals transferred from the Instruction Fetch (IF)
  stage to the Instruction Decode (ID) stage.

  It provides the decode stage with the information required to:
    - forward the fetched instruction and its PC to the decode pipeline stage

\remarks
  - The producer modport is intended for the IF stage.
  - The consumer modport is intended for the ID stage.

\section if2id_if_version_history Version history
| Version | Date       | Author   | Description                           |
|:-------:|:----------:|:---------|:--------------------------------------|
| 1.0     | 16/05/2026 | Kawanami | Initial IF->ID interface definition.  |
********************************************************************************
*/



interface if2id_if #(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
);

  import core_pkg::INSTR_WIDTH;

  /// Program counter
  logic [      Archi - 1 : 0] pc;
  /// Fetched instruction
  logic [INSTR_WIDTH - 1 : 0] instr;

  /// Producer
  modport producer(output pc, output instr);

  /// Consumer
  modport consumer(input pc, input instr);

endinterface

