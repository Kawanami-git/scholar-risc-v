// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       ctrl2id_if.sv
\brief      CTRL->ID interface definition for scholar risc-v

\author     Kawanami
\date       16/05/2026
\version    1.0

\details
  This interface groups all signals transferred from the Controller (CTRL)
  to the Instruction Decode (ID) stage.

  It provides the Decode stage with the information required to:
    - detect whether source operands are waiting for in-flight results,
    - select the proper operand source for Decode-stage bypassing,
    - select the proper operand source for Execute-stage bypassing.

\remarks
  - The producer modport is intended for the CTRL stage.
  - The consumer modport is intended for the ID stage.

\section ctrl2id_if_version_history Version history
| Version | Date       | Author   | Description                              |
|:-------:|:----------:|:---------|:-----------------------------------------|
| 1.0     | 16/05/2026 | Kawanami | Initial CTRL->ID interface definition.   |
********************************************************************************
*/

interface ctrl2id_if;

  import core_pkg::SEL_CTRL_WIDTH;

  /// Source register 1 dirty flag.
  logic rs1_dirty;

  /// Source register 2 dirty flag.
  logic rs2_dirty;

  /// CSR dirty flag.
  logic csr_dirty;

  /// Decode-stage operand 1 selector.
  logic [SEL_CTRL_WIDTH - 1 : 0] decode_op1_sel;

  /// Decode-stage operand 2 selector.
  logic [SEL_CTRL_WIDTH - 1 : 0] decode_op2_sel;

  /// Decode-stage operand 3 selector.
  logic [SEL_CTRL_WIDTH - 1 : 0] decode_op3_sel;

  /// Execute-stage operand 3 selector.
  logic [SEL_CTRL_WIDTH - 1 : 0] exe_op3_sel;

  /// Producer
  modport producer(
      output rs1_dirty,
      output rs2_dirty,
      output csr_dirty,
      output decode_op1_sel,
      output decode_op2_sel,
      output decode_op3_sel,
      output exe_op3_sel
  );

  /// Consumer
  modport consumer(
      input rs1_dirty,
      input rs2_dirty,
      input csr_dirty,
      input decode_op1_sel,
      input decode_op2_sel,
      input decode_op3_sel,
      input exe_op3_sel
  );

endinterface
