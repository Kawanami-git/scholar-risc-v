// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       decode.sv
\brief      scholar risc-v core decode stage
\author     Kawanami
\date       01/05/2026
\version    1.3

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
| Version | Date       | Author   | Description                              |
|:-------:|:----------:|:---------|:-----------------------------------------|
| 1.0     | 15/12/2025 | Kawanami | Initial version of the module.           |
| 1.1     | 28/01/2026 | Kawanami | Clear IF->ID register when ready and no new fetch payload; add CSR write path. |
| 1.2     | 21/04/2026 | Kawanami | Replace architecture definition with a parameter and use interfaces instead of packages. |
| 1.3     | 01/05/2026 | Kawanami | Refactor signals name.                    |
********************************************************************************
*/

module decode

  /*
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
    input  wire                                        clk_i,
    /// System active low reset
    input  wire                                        rstn_i,
    /// Decode stage ready (1: can accept a new IF->ID payload)
    output wire                                        ready_o,
    /// IF stage valid flag
    input  wire                                        fetch_valid_i,
    /// EXE stage ready flag (back-pressure from the next stage)
    input  wire                                        exe_ready_i,
    /// Register file port 0 read address (rs1 index)
    output wire               [RF_ADDR_WIDTH  - 1 : 0] rs1_o,
    /// Register file port 0 read data (rs1 value)
    input  wire               [     Archi     - 1 : 0] rs1_data_i,
    /// Register file rs1 dependency flag (1: data not ready / pending write)
    input  wire                                        rs1_dirty_i,
    /// Register file port 1 read address (rs2 index)
    output wire               [RF_ADDR_WIDTH  - 1 : 0] rs2_o,
    /// Register file port 1 read data (rs2 value)
    input  wire               [     Archi     - 1 : 0] rs2_data_i,
    /// Register file rs2 dependency flag (1: data not ready / pending write)
    input  wire                                        rs2_dirty_i,
    /// CSR file read address
    output wire               [CSR_ADDR_WIDTH - 1 : 0] csr_raddr_o,
    /// CSR file read data
    input  wire               [     Archi     - 1 : 0] csr_rdata_i,
    /// Control & Status Registers dependency flag (1: data not ready / pending write)
    input  wire                                        csr_dirty_i,
    /// Decoded instruction valid flag (1: `id2exe_o` fields are valid)
    output wire                                        valid_o,
    /// IF->ID payload (instruction + PC)
           if2id_if.consumer                           if2id_i,
    /// ID->EXE payload: operands + control micro-ops
           id2exe_if.producer                          id2exe_o
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
  assign ready_o = ready;

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
      .rstn_i     (rstn_i),
      .exe_ready_i(exe_ready_i),
      .ready_o    (ready),
      .pc_i       (pc_q),
      .instr_i    (instr_q),
      .rs1_o      (rs1_o),
      .rs1_data_i (rs1_data_i),
      .rs1_dirty_i(rs1_dirty_i),
      .rs2_o      (rs2_o),
      .rs2_data_i (rs2_data_i),
      .rs2_dirty_i(rs2_dirty_i),
      .csr_raddr_o(csr_raddr_o),
      .csr_rdata_i(csr_rdata_i),
      .csr_dirty_i(csr_dirty_i),
      .csr_waddr_o(id2exe_o.csr_waddr),
      .op1_o      (id2exe_o.op1),
      .op2_o      (id2exe_o.op2),
      .op3_o      (id2exe_o.op3),
      .rd_o       (id2exe_o.rd),
      .pc_o       (id2exe_o.pc),
      .exe_ctrl_o (id2exe_o.exe_ctrl),
      .mem_ctrl_o (id2exe_o.mem_ctrl),
      .csr_ctrl_o (id2exe_o.csr_ctrl),
      .gpr_ctrl_o (id2exe_o.gpr_ctrl),
      .pc_ctrl_o  (id2exe_o.pc_ctrl),
      .valid_o    (valid_o)
  );

endmodule
