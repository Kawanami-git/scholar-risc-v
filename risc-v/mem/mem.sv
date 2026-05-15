// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       mem.sv
\brief      scholar risc-v core memory module
\author     Kawanami
\date       21/04/2026
\version    1.3

\details
  This module implements the Memory (MEM) stage of the scholar risc-v core.

  The MEM stage performs data-memory transactions when required by the current
  micro-operation. It enforces data alignment via byte-enable masks for writes
  and performs sign/zero extension on reads as dictated by the control signals.

  Handshake:
  - EXE -> MEM uses (exe_valid_i, ready_o). When ready_o=1, MEM can capture a
    new uop. If ready_o=0, MEM holds its input register to complete the
    outstanding memory transaction.
  - MEM -> WB uses valid_o to indicate the completion of a memory transaction.

\remarks

\section mem_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 17/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 30/01/2026 | Kawanami   | Add CSR write path, non-perfect memory support and new strucure fields forwarding. |
| 1.2     | 15/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
| 1.3     | 21/04/2026 | Kawanami   | Replace architecture definition with a parameter and use interfaces instead of packages. |
********************************************************************************
*/

module mem

  /*
* Import useful packages.
*/
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
/**/

#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
) (
    /// System clock
    input  wire                                     clk_i,
    /// System active low reset
    input  wire                                     rstn_i,
    /// Exe stage valid signal (1: valid  0: not valid)
    input  wire                                     exe_valid_i,
    /// Mem stage ready (1: can accept a new EXE->MEM payload)
    output wire                                     ready_o,
    /// Mem operation complete
    output wire                                     valid_o,
    /// EXE->MEM payload (operands + control micro-ops)
           exe2mem_if.consumer                      exe2mem_i,
    /// MEM->WB payload (operands + control micro-ops)
           mem2wb_if.producer                       mem2wb_o,
    /// MEM->CTRL payload
           mem2ctrl_if.producer                     mem2ctrl_o,
    /// Address transfer request
    output wire                                     req_o,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Grant: Ready to accept address transfert
    input  wire                                     gnt_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// Address for memory access
    output wire                 [   Archi  - 1 : 0] addr_o,
    /// Write enable (1: write - 0: read)
    output wire                                     we_o,
    /// Write data
    output wire                 [    Archi - 1 : 0] wdata_o,
    /// Byte enable
    output wire                 [(Archi/8) - 1 : 0] be_o,
    /// Response transfer valid
    input  wire                                     rvalid_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// Error response
    input  wire                                     err_i
    /* verilator lint_on UNUSEDSIGNAL */
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */
  /// Ready flag
  logic                          ready;

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

  /// EXE->MEM pipeline register
  /*!
  * Capture when EXE provides a valid uop (`exe_valid_i`) and MEM is ready.
  *
  * Backpressure:
  *  - If `ready` is low, MEM holds `exe2mem_q` to ensure the memory
  *    transaction completes without losing the associated control.
  *
  * NOP injection:
  *  - If `ready` is high but `exe_valid_i` is low, MEM clears control
  *    `signals. This propagates a NOP-like uop downstream:
  *      - Disables potential memory side effects in the next stage
  *      - Disables any write to GPR and CSR by setting control to IDLE.
  */
  always_ff @(posedge clk_i) begin : exe2mem
    if (!rstn_i) begin
      exe_out_q   <= '0;
      op3_q       <= '0;
      rd_q        <= '0;
      csr_waddr_q <= '0;
      mem_ctrl_q  <= '0;
      csr_ctrl_q  <= '0;
      gpr_ctrl_q  <= '0;
    end
    else if (exe_valid_i && ready) begin
      exe_out_q   <= exe2mem_i.exe_out;
      op3_q       <= exe2mem_i.op3;
      rd_q        <= exe2mem_i.rd;
      csr_waddr_q <= exe2mem_i.csr_waddr;
      mem_ctrl_q  <= exe2mem_i.mem_ctrl;
      csr_ctrl_q  <= exe2mem_i.csr_ctrl;
      gpr_ctrl_q  <= exe2mem_i.gpr_ctrl;
    end
    else if (ready) begin
      exe_out_q   <= '0;
      op3_q       <= '0;
      rd_q        <= '0;
      csr_waddr_q <= '0;
      mem_ctrl_q  <= '0;
      csr_ctrl_q  <= '0;
      gpr_ctrl_q  <= '0;
    end
  end

  /// Forward EXE output to writeback
  assign mem2wb_o.exe_out     = exe_out_q;
  /// Forward op3 to writeback
  assign mem2wb_o.op3         = op3_q;
  /// Forward rd to writeback
  assign mem2wb_o.rd          = rd_q;
  /// Forward CSR waddr to writeback
  assign mem2wb_o.csr_waddr   = csr_waddr_q;
  /// Forward GPR control signal to writeback
  assign mem2wb_o.gpr_ctrl    = gpr_ctrl_q;
  /// Forward CSR control signal to writeback
  assign mem2wb_o.csr_ctrl    = csr_ctrl_q;
  /// Forward MEM control signal to writeback (sign-extention)
  assign mem2wb_o.mem_ctrl    = mem_ctrl_q;
  /// Forward instruction rd to Controller
  assign mem2ctrl_o.rd        = rd_q;
  /// Forward instruction csr write address to Controller
  assign mem2ctrl_o.csr_waddr = csr_waddr_q;
  /// Forward instruction csr control to Controller
  assign mem2ctrl_o.csr_ctrl  = csr_ctrl_q;
  /// Output driven by mem unit.
  assign ready_o              = ready;

  /// Memory unit instantiation
  /*!
  * Drives write/read transactions to the external data memory.
  * `valid_o` qualifies the MEM->WB transfer.
  */
  mem_unit #(
      .Archi(Archi)
  ) mem_unit (
      .clk_i      (clk_i),
      .rstn_i     (rstn_i),
      .exe_valid_i(exe_valid_i),
      .ready_o    (ready),
      .valid_o    (valid_o),
      .op3_i      (op3_q),
      .exe_out_i  (exe_out_q),
      .mem_ctrl_i (mem_ctrl_q),
      .wdata_o    (wdata_o),
      .rvalid_i   (rvalid_i),
      .addr_o     (addr_o),
      .req_o      (req_o),
      .gnt_i      (gnt_i),
      .we_o       (we_o),
      .be_o       (be_o),
      .err_i      (err_i)
  );

endmodule
