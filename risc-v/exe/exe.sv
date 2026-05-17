// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       exe.sv
\brief      scholar risc-v core execution stage
\author     Kawanami
\date       17/05/2026
\version    1.1

\details
  Execution (Exe) stage of the scholar risc-v pipeline.

  The Exe stage consumes the decoded micro-operation (uop) + operands from ID,
  performs the arithmetic/logic work through the ALU, and forwards:
    - ALU result + writeback/memory control to the MEM stage
    - PC-related information (pc/op3/pc_ctrl + ALU result) to the Pipeline Controller

  This stage is split into:
    - `exe.sv`     : stage wrapper and ID->EXE input register
    - `alu.sv`     : arithmetic / logic / compare operations

  Handshake / back-pressure:
    - `ready_o` is asserted when the next stage (MEM) is ready (`mem_ready_i`).
      This means EXE can accept a new ID->EXE payload only when MEM
      can accept the current one.
    - The ID->EXE payload register is updated only on `decode_valid_i && mem_ready_i`.
    - When MEM is ready but ID does not provide a valid payload, EXE injects a
      bubble (NOP-like uop) by clearing the register. This prevents re-executing
      the previous uop.

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section exe_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 07/03/2026 | Kawanami   | Initial version of the module.            |
| 1.1     | 17/05/2026 | Kawanami   | Replace packages with interfaces.         |
********************************************************************************
*/

module exe

  /*!
* Import useful packages.
*/
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::SEL_CTRL_WIDTH;
  import core_pkg::SEL_MEM;
  import core_pkg::SEL_WB;
  import core_pkg::CSR_IDLE;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::EXE_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::PC_CTRL_WIDTH;
/**/

#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
) (
    /// System clock
    input  wire                 clk_i,
    /// System active low reset
    input  wire                 rstn_i,
    /// ID stage valid flag
    input  wire                 decode_valid_i,
    /// Mem stage ready flag (back-pressure from the next stage)
    input  wire                 mem_ready_i,
    /// Exe stage ready (1: can accept a new ID->EXE payload)
    output wire                 ready_o,
    /// Exe result valid flag (1: ALU result and forwarded fields are valid)
    output wire                 valid_o,
    /// Decode to Exe payload (operands + control micro-ops)
           id2exe_if.consumer   id2exe_i,
    /// Writeback to Exe bypass
           wb2exe_if.consumer   wb2exe_i,
    /// Exe to Decode bypass
           exe2id_if.producer   exe2id_o,
    /// Exe to Mem payload (operands + control micro-ops)
           exe2mem_if.producer  exe2mem_o,
    /// Exe to PC payload (operands + control micro-ops)
           exe2ctrl_if.producer exe2ctrl_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// ALU output value
  wire [         Archi - 1 : 0] alu_out;
  /// ALU valid flag
  wire                          valid;
  /// First operand
  wire [         Archi - 1 : 0] op1;
  /// Second operand
  wire [         Archi - 1 : 0] op2;
  /* registers */
  /// Instruction program counter
  reg  [         Archi - 1 : 0] pc_q;
  /// First operand: RS1 value or zeroes
  reg  [         Archi - 1 : 0] op1_q;
  /// Second operand: RS2 value (REG_OP or BRANCH_OP) or immediate
  reg  [         Archi - 1 : 0] op2_q;
  /// Third operand: Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
  reg  [         Archi - 1 : 0] op3_q;
  /// Destination register
  reg  [RF_ADDR_WIDTH  - 1 : 0] rd_q;
  /// CSR file write address
  reg  [CSR_ADDR_WIDTH - 1 : 0] csr_waddr_q;
  /// Exe stage control signal
  reg  [EXE_CTRL_WIDTH - 1 : 0] exe_ctrl_q;
  /// Memory stage control signal
  reg  [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl_q;
  /// CSR (writeback) control signal
  reg  [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl_q;
  /// GPR (writeback) control signal
  reg  [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl_q;
  /// PC (controller) control signal
  reg  [PC_CTRL_WIDTH  - 1 : 0] pc_ctrl_q;
  ///
  reg  [SEL_CTRL_WIDTH - 1 : 0] exe_op3_sel_q;
  //
  // reg [SEL_CTRL_WIDTH - 1 : 0] mem_op3_sel_q;
  //
  // reg [SEL_CTRL_WIDTH - 1 : 0] exe_op1_sel_q;
  //
  // reg [SEL_CTRL_WIDTH - 1 : 0] exe_op2_sel_q;
  /********************             ********************/

  /// ID->EXE pipeline register
  /*!
  * Capture when:
  *  - ID provides a valid uop (`decode_valid_i`)
  *  - MEM is ready to accept the current EXE output (`mem_ready_i`)
  *
  * Stall behavior:
  *  - If `mem_ready_i` is low, EXE holds its internal registers (no overwrite).
  *
  * NOP injection:
  *  - If `mem_ready_i` is high but `decode_valid_i` is low, EXE clears its internal registers
  *    to propagate a NOP-like uop downstream. This prevents reusing the previous
  *    uop data when no new instruction is available.
  */
  always_ff @(posedge clk_i) begin : id2exe
    if (!rstn_i) begin
      pc_q          <= '0;
      op1_q         <= '0;
      op2_q         <= '0;
      op3_q         <= '0;
      rd_q          <= '0;
      csr_waddr_q   <= '0;
      exe_ctrl_q    <= '0;
      mem_ctrl_q    <= '0;
      csr_ctrl_q    <= '0;
      gpr_ctrl_q    <= '0;
      pc_ctrl_q     <= '0;
      exe_op3_sel_q <= '0;
      // mem_op3_sel_q <= '0;
      // exe_op1_sel_q <= '0;
      // exe_op2_sel_q <= '0;
    end
    else if (decode_valid_i && mem_ready_i) begin
      pc_q          <= id2exe_i.pc;
      op1_q         <= id2exe_i.op1;
      op2_q         <= id2exe_i.op2;
      op3_q         <= id2exe_i.op3;
      rd_q          <= id2exe_i.rd;
      csr_waddr_q   <= id2exe_i.csr_waddr;
      exe_ctrl_q    <= id2exe_i.exe_ctrl;
      mem_ctrl_q    <= id2exe_i.mem_ctrl;
      csr_ctrl_q    <= id2exe_i.csr_ctrl;
      gpr_ctrl_q    <= id2exe_i.gpr_ctrl;
      pc_ctrl_q     <= id2exe_i.pc_ctrl;
      exe_op3_sel_q <= id2exe_i.exe_op3_sel;
      //mem_op3_sel_q <= id2exe_i.mem_op3_sel;
      //exe_op1_sel_q <= id2exe_i.exe_op1_sel;
      //exe_op2_sel_q <= id2exe_i.exe_op2_sel;
    end
    else if (mem_ready_i) begin
      pc_q          <= '0;
      op1_q         <= '0;
      op2_q         <= '0;
      op3_q         <= '0;
      rd_q          <= '0;
      csr_waddr_q   <= '0;
      exe_ctrl_q    <= '0;
      mem_ctrl_q    <= '0;
      csr_ctrl_q    <= '0;
      gpr_ctrl_q    <= '0;
      pc_ctrl_q     <= '0;
      exe_op3_sel_q <= '0;
      // mem_op3_sel_q <= '0;
      // exe_op1_sel_q <= '0;
      // exe_op2_sel_q <= '0;
    end
  end

  /// EXE is ready if Mem consume current micro-ops
  assign ready_o              = mem_ready_i;
  /// Forward op3 to Mem
  assign exe2mem_o.op3        = exe_op3_sel_q == SEL_WB ? wb2exe_i.bypass : op3_q;
  /// Provide ALU out to Mem
  assign exe2mem_o.exe_out    = alu_out;
  /// Forward rd to Mem
  assign exe2mem_o.rd         = rd_q;
  /// Forward CSR waddr to Mem
  assign exe2mem_o.csr_waddr  = csr_waddr_q;
  /// Forward Mem control signal to Mem
  assign exe2mem_o.mem_ctrl   = mem_ctrl_q;
  /// Forward GPR control signal to Mem
  assign exe2mem_o.gpr_ctrl   = gpr_ctrl_q;
  /// Forward CSR control signal to Mem
  assign exe2mem_o.csr_ctrl   = csr_ctrl_q;
  // Forward mem_op3_sel to Mem
  // assign exe2mem_o.mem_op3_sel = mem_op3_sel_q;
  /// Forward op3 to PC
  assign exe2ctrl_o.op3       = op3_q;
  /// Forward instruction pc to Controller
  assign exe2ctrl_o.pc        = pc_q;
  /// Forward ALU out to Controller
  assign exe2ctrl_o.exe_out   = alu_out;
  /// Forward PC control signal to Controller
  assign exe2ctrl_o.pc_ctrl   = pc_ctrl_q;
  /// Forward instruction rd to Controller
  assign exe2ctrl_o.rd        = rd_q;
  /// Forward instruction csr write address to Controller
  assign exe2ctrl_o.csr_waddr = csr_waddr_q;
  /// Forward instruction csr control to Controller
  assign exe2ctrl_o.csr_ctrl  = csr_ctrl_q;
  /// Generate is_load flag for controller bypass
  assign exe2ctrl_o.is_load   = |mem_ctrl_q[MEM_CTRL_WIDTH-2:0];
  /// Output driven by ALU
  assign valid_o              = valid;
  /// Generate bypass for Decode
  assign exe2id_o.bypass      = csr_ctrl_q == CSR_IDLE ? alu_out : op3_q;
  /// ALU first operand
  assign op1                  = op1_q;
  // assign op1                   = exe_op1_sel_q == SEL_WB ? wb2exe_i.bypass : op1_q;
  /// ALU second operand
  assign op2                  = op2_q;
  // assign op2                   = exe_op2_sel_q == SEL_WB ? wb2exe_i.bypass : op2_q;

  /// ALU instantiation
  /*!
  * ALU computes the operation selected by `exe_ctrl_q` using op1/op2.
  *
  * Note:
  * - If `exe_ctrl_q` is cleared (bubble), its value becomes 0.
  *   Ensure ALU interprets ctrl=0 as a NOP operation and deasserts `valid_o`.
  */
  alu #(
      .Archi(Archi)
  ) alu (
      .rstn_i (rstn_i),
      .valid_o(valid),
      .op1_i  (op1),
      .op2_i  (op2),
      .ctrl_i (exe_ctrl_q),
      .out_o  (alu_out)
  );




endmodule
