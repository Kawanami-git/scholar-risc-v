// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       decode.sv
\brief      scholar risc-v core decode stage
\author     Kawanami
\date       17/05/2026
\version    1.1

\details
  Instruction Decode (ID) stage of the scholar risc-v core pipeline.

  The decode stage receives the fetched instruction and PC from the IF stage and
  produces operands and micro-operation control fields for the downstream stages.

  This stage is split into two parts:
    - decode.sv (this file): stage wrapper and IF->ID pipeline register
    - decode_unit: instruction decoding, operand selection, and hazard/ready gating

  The IF->ID payload is captured only when:
    - fetch provides a valid instruction (fetch_valid_i)
    - the decode stage is ready to accept it (ready_o)

  When decode is ready but no new instruction is provided, the IF->ID register is
  cleared to prevent re-issuing a previously consumed instruction in pipelines
  where stages may progress independently (e.g., under non-perfect memory back-pressure).

\remarks
  - ready_o reflects the ability of the decode unit to accept a new instruction,
    including back-pressure from EXE and operand availability (dirty flags).
  - The CSR read path participates in hazard gating through csr_dirty_i.

\section decode_version_history Version history
| Version | Date       | Author   | Description                    |
|:-------:|:----------:|:---------|:-------------------------------|
| 1.0     | 07/03/2026 | Kawanami | Initial version of the module. |
| 1.1     | 17/05/2026 | Kawanami | Replace packages with interfaces. |
*******************************************************************
*/
/* verilator lint_off UNUSEDSIGNAL */
module decode

  /*!
* Import useful packages.
*/
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::INSTR_WIDTH;
/**/

#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
) (
    /// System clock
    input  wire                                         clk_i,
    /// System active low reset
    input  wire                                         rstn_i,
    /// Decode stage ready (1: can accept a new IF->ID payload)
    output wire                                         ready_o,
    /// IF stage valid flag
    input  wire                                         fetch_valid_i,
    /// EXE stage ready flag (back-pressure from the next stage)
    input  wire                                         exe_ready_i,
    /// Register file port 0 read address (rs1 index)
    output wire                [RF_ADDR_WIDTH  - 1 : 0] rs1_o,
    /// Register file port 0 read data (rs1 value)
    input  wire                [     Archi     - 1 : 0] rs1_data_i,
    /// Register file port 1 read address (rs2 index)
    output wire                [RF_ADDR_WIDTH  - 1 : 0] rs2_o,
    /// Register file port 1 read data (rs2 value)
    input  wire                [     Archi     - 1 : 0] rs2_data_i,
    /// CSR file read address
    output wire                [CSR_ADDR_WIDTH - 1 : 0] csr_raddr_o,
    /// CSR file read data
    input  wire                [     Archi     - 1 : 0] csr_data_i,
    /// CTRL->ID payload (dirty flags + bypass control)
           ctrl2id_if.consumer                          ctrl2id_i,
    /// Exe to Decode payload (bypass)
           exe2id_if.consumer                           exe2id_i,
    /// Mem to decode payload (bypass)
           mem2id_if.consumer                           mem2id_i,
    /// Writeback to payload (bypass)
           wb2id_if.consumer                            wb2id_i,
    /// Decoded instruction valid flag (1: `id2exe_o` fields are valid)
    output wire                                         valid_o,
    /// IF->ID payload (instruction + PC)
           if2id_if.consumer                            if2id_i,
    /// ID->EXE payload: operands + control micro-ops
           id2exe_if.producer                           id2exe_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// Ready flag
  wire                        ready;
  /* registers */
  /// Instruction to decode program counter
  logic [      Archi - 1 : 0] pc_q;
  /// Fetched instruction
  logic [INSTR_WIDTH - 1 : 0] instr_q;
  /********************             ********************/

  /// IF->ID pipeline register
  /*!
  * Captures the instruction and PC from the fetch stage when:
  *  - the incoming payload is valid (`fetch_valid_i`)
  *  - decode is ready to accept it (`ready`)
  *
  * When ready but no new instruction is provided, the IF->ID register is
  * cleared to prevent re-issuing a previously consumed instruction in pipelines
  */
  always_ff @(posedge clk_i) begin : if2id
    if (!rstn_i) begin
      pc_q    <= '0;
      instr_q <= '0;
    end
    else if (fetch_valid_i && ready) begin
      pc_q    <= if2id_i.pc;
      instr_q <= if2id_i.instr;
    end
    else if (ready) begin
      pc_q    <= '0;
      instr_q <= '0;
    end
  end

  /// Output driven by the decode unit
  assign ready_o              = ready;

  // Forward exe_op1_sel to Exe
  // assign id2exe_o.exe_op1_sel = ctrl2id_i.exe_op1_sel;

  // Forward exe_op2_sel to Exe
  // assign id2exe_o.exe_op2_sel = ctrl2id_i.exe_op2_sel;

  /// Forward exe_op3_sel to Exe
  assign id2exe_o.exe_op3_sel = ctrl2id_i.exe_op3_sel;

  // Forward mem_op3_sel to Exe
  // assign id2exe_o.mem_op3_sel = ctrl2id_i.mem_op3_sel;

  /// Decode unit instantiation
  /*!
  * `decode_unit` consumes the registered instruction/PC and:
  *  - requests register file rs1 & rs2 data or CSR data
  *  - selects/forwards operands (op1/op2/op3)
  *  - generates control fields for EXE/MEM/WB/PC
  *  - asserts `valid_o` when the decoded payload is valid
  *  - provides `ready_o` back-pressure toward fetch
  */
  decode_unit #(
      .Archi(Archi)
  ) decode_unit (
      .rstn_i      (rstn_i),
      .exe_ready_i (exe_ready_i),
      .ready_o     (ready),
      .pc_i        (pc_q),
      .instr_i     (instr_q),
      .rs1_o       (rs1_o),
      .rs1_data_i  (rs1_data_i),
      .rs1_dirty_i (ctrl2id_i.rs1_dirty),
      .rs2_o       (rs2_o),
      .rs2_data_i  (rs2_data_i),
      .rs2_dirty_i (ctrl2id_i.rs2_dirty),
      .csr_raddr_o (csr_raddr_o),
      .csr_data_i  (csr_data_i),
      .csr_dirty_i (ctrl2id_i.csr_dirty),
      .exe_bypass_i(exe2id_i.bypass),
      .mem_bypass_i(mem2id_i.bypass),
      .wb_bypass_i (wb2id_i.bypass),
      .op1_sel_i   (ctrl2id_i.decode_op1_sel),
      .op2_sel_i   (ctrl2id_i.decode_op2_sel),
      .op3_sel_i   (ctrl2id_i.decode_op3_sel),
      .csr_waddr_o (id2exe_o.csr_waddr),
      .op1_o       (id2exe_o.op1),
      .op2_o       (id2exe_o.op2),
      .op3_o       (id2exe_o.op3),
      .rd_o        (id2exe_o.rd),
      .pc_o        (id2exe_o.pc),
      .exe_ctrl_o  (id2exe_o.exe_ctrl),
      .mem_ctrl_o  (id2exe_o.mem_ctrl),
      .csr_ctrl_o  (id2exe_o.csr_ctrl),
      .gpr_ctrl_o  (id2exe_o.gpr_ctrl),
      .pc_ctrl_o   (id2exe_o.pc_ctrl),
      .valid_o     (valid_o)
  );

endmodule
