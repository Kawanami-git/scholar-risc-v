// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       writeback.sv
\brief      scholar risc-v core write-back stage
\author     Kawanami
\date       21/05/2026
\version    1.5

\details
  This module implements the Writeback (WB) stage of the scholar risc-v core.

  The WB stage is responsible for committing results to the General-Purpose
  Registers (GPR) and Control and Status Registers (CSR).

\remarks
- This implementation complies with [reference or standard].
- TODO: [possible improvements or future features]

\section writeback_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 17/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 03/02/2026 | Kawanami   | Add Mem->WB payload handling and expose useful signal for verilator. |
| 1.2     | 15/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
| 1.3     | 21/04/2026 | Kawanami   | Replace architecture definition with a parameter and use interfaces instead of packages. |
| 1.4     | 01/05/2026 | Kawanami   | Refactor signals name.                    |
| 1.5     | 21/05/2026 | Kawanami   | Replace SIM with SPIKE for more clarity.         |
********************************************************************************
*/

module writeback

  /*
* Import useful packages.
*/
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::GPR_IDLE;
  import core_pkg::CSR_IDLE;
/**/

#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
) (
`ifdef SPIKE
    /// To verilator (used in simulation_vs_spike)
    output wire instr_committed_o,
`endif

    /// System clock
    input  wire                                         clk_i,
    /// System active low reset
    input  wire                                         rstn_i,
    /// Mem stage valid signal (1: valid  0: not valid)
    input  wire                                         mem_valid_i,
    /// MEM->WB payload (operands + control micro-ops)
           mem2wb_if.consumer                           mem2wb_i,
    /// WB->CTRL payload
           wb2ctrl_if.producer                          wb2ctrl_o,
    /// GPR destination register index
    output wire                [ RF_ADDR_WIDTH - 1 : 0] rd_o,
    /// Data to write into the destination GPR
    output wire                [         Archi - 1 : 0] gpr_wdata_o,
    /// CSR address
    output wire                [CSR_ADDR_WIDTH - 1 : 0] csr_waddr_o,
    /// Data to write in the CSR
    output wire                [         Archi - 1 : 0] csr_wdata_o,
    /// Memory read data
    input  wire                [    Archi      - 1 : 0] rdata_i,
    /// GPR data valid flag (1: valid  0: not valid)
    output wire                                         gpr_wen_o,
    /// CSR data valid flag (1: valid  0: not valid)
    output wire                                         csr_wen_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */

  /* registers */
  /// Execute stage result
  logic [         Archi - 1 : 0] exe_out_q;
  /// Third operand: Immediate (BRANCH_OP or CSR_OP) or RS2 value (STORE_OP) or zeroes
  reg   [         Archi - 1 : 0] op3_q;
  /// Destination register
  reg   [RF_ADDR_WIDTH  - 1 : 0] rd_q;
  /// CSR file write address
  reg   [CSR_ADDR_WIDTH - 1 : 0] csr_waddr_q;
  /// Memory stage control signal
  reg   [MEM_CTRL_WIDTH - 1 : 0] mem_ctrl_q;
  /// CSR (writeback) control signal
  reg   [CSR_CTRL_WIDTH - 1 : 0] csr_ctrl_q;
  /// GPR (writeback) control signal
  reg   [GPR_CTRL_WIDTH - 1 : 0] gpr_ctrl_q;
  /********************             ********************/

  /// MEM->WB pipeline register
  /*!
  * Capture when MEM provides a valid uop (`mem_valid_i`).
  * This stage is always ready: both GPR and CSR writes take one cycle.
  *
  * NOP injection:
  *  - If `mem_valid_i` is low, WB clears `rd` and controls,
  *    ensuring no inappropriate GPR/CSR writes occur.
  */
  always_ff @(posedge clk_i) begin : mem2wb
    if (!rstn_i) begin
      exe_out_q   <= '0;
      op3_q       <= '0;
      rd_q        <= '0;
      csr_waddr_q <= '0;
      mem_ctrl_q  <= '0;
      csr_ctrl_q  <= '0;
      gpr_ctrl_q  <= '0;
    end
    else if (mem_valid_i) begin
      exe_out_q   <= mem2wb_i.exe_out;
      op3_q       <= mem2wb_i.op3;
      rd_q        <= mem2wb_i.rd;
      csr_waddr_q <= mem2wb_i.csr_waddr;
      mem_ctrl_q  <= mem2wb_i.mem_ctrl;
      csr_ctrl_q  <= mem2wb_i.csr_ctrl;
      gpr_ctrl_q  <= mem2wb_i.gpr_ctrl;
    end
    else begin
      exe_out_q   <= '0;
      op3_q       <= '0;
      rd_q        <= '0;
      csr_waddr_q <= '0;
      mem_ctrl_q  <= '0;
      csr_ctrl_q  <= '0;
      gpr_ctrl_q  <= '0;
    end
  end

  /// output driven by mem_wb
  assign wb2ctrl_o.rd        = rd_q;
  /// output driven by mem_wb
  assign wb2ctrl_o.csr_waddr = csr_waddr_q;
  /// output driven by mem_wb
  assign wb2ctrl_o.csr_ctrl  = csr_ctrl_q;


`ifdef SPIKE
  reg instr_committed_q;
  reg mem_valid_q;
  /// Instruction commit
  /*!
  * Detect when a new instruction is committed.
  * Used by Verilator for simulation_vs_spike.
  */
  always_ff @(posedge clk_i) begin : instr_commit
    if (!rstn_i) begin
      instr_committed_q <= '0;
      mem_valid_q       <= '0;
    end
    else begin
      mem_valid_q <= mem_valid_i;
      if (mem_valid_q) begin
        instr_committed_q <= 1'b1;
      end
      else begin
        instr_committed_q <= '0;
      end
    end
  end
  /// Output driven by instr_commit
  assign instr_committed_o = instr_committed_q;
`endif

  /// Writeback unit instantiation
  /*!
  * Drives commits into the GPR and/or CSR files from the MEM payload and
  * memory read data when applicable.
  */
  writeback_unit #(
      .Archi(Archi)
  ) writeback_unit (
      .exe_out_i  (exe_out_q),
      .op3_i      (op3_q),
      .rd_i       (rd_q),
      .csr_waddr_i(csr_waddr_q),
      .gpr_ctrl_i (gpr_ctrl_q),
      .csr_ctrl_i (csr_ctrl_q),
      .mem_ctrl_i (mem_ctrl_q),
      .rd_o       (rd_o),
      .gpr_wdata_o(gpr_wdata_o),
      .csr_waddr_o(csr_waddr_o),
      .csr_wdata_o(csr_wdata_o),
      .rdata_i    (rdata_i),
      .gpr_wen_o  (gpr_wen_o),
      .csr_wen_o  (csr_wen_o)
  );

endmodule
