// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       scholar_riscv_core.sv
\brief      scholar risc-v Core Module
\author     Kawanami
\date       17/05/2026
\version    1.2

\details
  This module is the top-level module of the scholar risc-v core.
  The scholar risc-v core is an education-oriented 32-bit or 64-bit
  RISC-V implementation.

  ISA:
    - RV32I base integer instruction set
      + 32-bit cycle counter (Zicntr subset).
    - RV64I base integer instruction set
      + 64-bit cycle counter (Zicntr subset).

  Limitations:
  - No operating system support:
      - `ECALL` is treated as a NOP (no operation).
  - No debug support:
      - `EBREAK` is treated as a NOP.
  - No support for multicore or memory consistency operations:
      - `FENCE` and `FENCE.I` are treated as NOPs.

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section scholar_riscv_core_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 07/03/2026 | Kawanami   | Initial version of the module.            |
| 1.1     | 26/03/2026 | Kawanami   | Replace simulation-driven GPR signals with CSR signals (spike compatibility).            |
| 1.2     | 17/05/2026 | Kawanami   | Replace packages with interfaces, use a parameter for architecture and use a parameter to enable/disable Performance counters.        |
********************************************************************************
*/

module scholar_riscv_core

  /*!
* Import useful packages.
*/
  import core_pkg::INSTR_WIDTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::NB_GPR;
  import core_pkg::SEL_EXE;
  import core_pkg::SEL_MEM;
  import core_pkg::SEL_WB;
/**/
#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned                 Archi              = 32,
    /// Core boot/start address
    parameter logic        [Archi - 1 : 0] StartAddress       = '0,
    /// Enable performance Counters
    parameter bit                          EnablePerfCounters = 1'b1
) (
`ifdef SIM
    /// Simulation CSR overwrite enable
    input  wire                          csr_en_i,
    /// Simulation CSR overwrite data
    input  wire [Archi          - 1 : 0] csr_data_i,
    /// Decode to CSR raddr
    output wire [                11 : 0] csr_raddr_o,
    /// GPR memory (SIM only)
    output wire [      Archi    - 1 : 0] gpr_memory_o     [NB_GPR],
    /// Pipeline flush flag
    output wire                          pipeline_flush_o,
    /// Writeback instruction commited flag
    output wire                          instr_committed_o,
`endif
    /* Global signals */
    /// System clock
    input  wire                          clk_i,
    /// System active low reset
    input  wire                          rstn_i,
    /* Instruction memory wires */
    /// Address transfer request
    output wire                          imem_req_o,
    /// Grant: Ready to accept address transfert
    input  wire                          imem_gnt_i,
    /// Address for memory access
    output wire [        Archi  - 1 : 0] imem_addr_o,
    /// Response transfer valid
    input  wire                          imem_rvalid_i,
    /// Read data
    input  wire [   INSTR_WIDTH - 1 : 0] imem_rdata_i,
    /// Error response
    input  wire                          imem_err_i,
    /* Data memory signals */
    /// Address transfer request
    output wire                          dmem_req_o,
    /// Grant: Ready to accept address transfert
    input  wire                          dmem_gnt_i,
    /// Address for memory access
    output wire [        Archi  - 1 : 0] dmem_addr_o,
    /// Write enable (1: write - 0: read)
    output wire                          dmem_we_o,
    /// Write data
    output wire [         Archi - 1 : 0] dmem_wdata_o,
    /// Byte enable
    output wire [     (Archi/8) - 1 : 0] dmem_be_o,
    /// Response transfer valid
    input  wire                          dmem_rvalid_i,
    /// Read data
    input  wire [         Archi - 1 : 0] dmem_rdata_i,
    /// Error response
    input  wire                          dmem_err_i
);

  /******************** DECLARATION ********************/
  /* parameters verification */
  if (Archi != 32 && Archi != 64) begin : gen_architecture_check
    $fatal("FATAL ERROR: Only 32-bit and 64-bit architectures are supported.");
  end

  /* local parameters */

  /* functions */

  /* wires */

  /* Control / PC */
  /// Active-low softreset (branch handling)
  wire                          softresetn;
  /// Program counter
  wire [Archi          - 1 : 0] pc;
  /// Hardware performance event 3
  wire                          mhpmevent3;
  /// Hardware performance event 4
  wire                          mhpmevent4;
  /// Hardware performance event 5
  wire                          mhpmevent5;
  /// Hardware performance event 6
  wire                          mhpmevent6;
  /// Hardware performance event 7
  wire                          mhpmevent7;
  /// Hardware performance event 8
  wire                          mhpmevent8;
  /// Hardware performance event 9
  wire                          mhpmevent9;
  /// Hardware performance event 10
  wire                          mhpmevent10;
  /// Hardware performance event 11
  wire                          mhpmevent11;
  /// Hardware performance event 12
  wire                          mhpmevent12;
  /// Hardware performance event 13
  wire                          mhpmevent13;
  /* General purpose register file */
  /// General purpose register file RS1 value
  wire [Archi          - 1 : 0] rs1_data;
  /// General purpose register file RS2 value
  wire [Archi          - 1 : 0] rs2_data;
  /* CSR file */
  /// CSR read value
  wire [Archi          - 1 : 0] csr_data;
  /* Fetch */
  /// Fetch to decode stage control/data payload
  if2id_if #(.Archi(Archi))     if2id ();
  /// Fetch to control payload
  if2ctrl_if                    if2ctrl ();
  /// Fetch valid flag
  wire                          fetch_valid;
  /* Decode */
  /// Decode ready flag
  wire                          decode_ready;
  /// Decode valid flag
  wire                          decode_valid;
  /// General purpose register file port 0 read address
  wire [RF_ADDR_WIDTH  - 1 : 0] rs1;
  /// General purpose register file port 1 read address
  wire [RF_ADDR_WIDTH  - 1 : 0] rs2;
  /// CTRL->ID payload (dirty flags + bypass control)
  ctrl2id_if #()                ctrl2id ();
  /// Decode to exe control/data payload
  id2exe_if #(.Archi(Archi))    id2exe ();
  /// Control/status register file read address
  wire [CSR_ADDR_WIDTH - 1 : 0] csr_raddr;
  /* Exe */
  /// Exe ready flag
  wire                          exe_ready;
  /// Exe valid flag
  wire                          exe_valid;
  /// Exe to mem payload
  exe2mem_if #(.Archi(Archi))   exe2mem ();
  /// Exe to Control payload
  exe2ctrl_if #(.Archi(Archi))  exe2ctrl ();
  /// Exe To Decode bypass
  exe2id_if #(.Archi(Archi))    exe2id ();
  /* mem */
  /// Mem ready flag
  wire                          mem_ready;
  /// Mem valid flag
  wire                          mem_valid;
  /// Mem to writeback control/data payload
  mem2wb_if #(.Archi(Archi))    mem2wb ();
  /// Mem to Control payload
  mem2ctrl_if                   mem2ctrl ();
  /// Mem To Decode bypass
  mem2id_if #(.Archi(Archi))    mem2id ();
  /* write-back */
  /// Writeback GPR wdata valid flag
  wire                          gpr_wdata_valid;
  /// Writeback CSR wdata valid flag
  wire                          csr_wdata_valid;
  /// General purpose register file write port address
  wire [ RF_ADDR_WIDTH-1:0]     rd;
  /// General purpose register file write port data
  wire [         Archi-1:0]     gpr_wdata;
  /// CSR write port address
  wire [CSR_ADDR_WIDTH-1:0]     csr_waddr;
  /// CSR file write port data
  wire [         Archi-1:0]     csr_wdata;
  /// Writeback to Control payload
  wb2ctrl_if                    wb2ctrl ();
  /// Writeback to Decode bypass
  wb2id_if #(.Archi(Archi))     wb2id ();
  /// Writeback to Exe bypass
  wb2exe_if #(.Archi(Archi))    wb2exe ();
  // Writeback to Mem bypass
  //wb2mem_if #(.Archi(Archi))  wb2mem ();


  /* registers */
  /// softresetn register
  reg                           softresetn_q;
  /********************             ********************/

  generate
    if (EnablePerfCounters) begin : gen_perf_events

      /// Stall cycle event
      assign mhpmevent3 = (ctrl2id.rs1_dirty || ctrl2id.rs2_dirty) && softresetn;

      /// Taken branch / frontend flush event
      assign mhpmevent4 = !softresetn;

      /// Exe -> Decode bypass on op1 or op2
      assign mhpmevent5 = ((ctrl2id.decode_op1_sel == SEL_EXE) || (ctrl2id.decode_op2_sel == SEL_EXE
                           )) && softresetn && softresetn_q && decode_valid && exe_ready;

      /// Exe -> Decode bypass on op3
      assign mhpmevent6 = (ctrl2id.decode_op3_sel == SEL_EXE) && softresetn && softresetn_q &&
          decode_valid && exe_ready;

      /// Mem -> Decode bypass on op1 or op2
      assign mhpmevent7 = ((ctrl2id.decode_op1_sel == SEL_MEM) || (ctrl2id.decode_op2_sel == SEL_MEM
                           )) && softresetn && softresetn_q && decode_valid && exe_ready;

      /// Mem -> Decode bypass on op3
      assign mhpmevent8 = (ctrl2id.decode_op3_sel == SEL_MEM) && softresetn && softresetn_q &&
          decode_valid && exe_ready;

      /// Writeback -> Decode bypass on op1 or op2.
      assign mhpmevent9 = ((ctrl2id.decode_op1_sel == SEL_WB) || (ctrl2id.decode_op2_sel == SEL_WB))
          && softresetn && softresetn_q && decode_valid && exe_ready;

      /// Writeback -> Decode bypass on op3
      assign mhpmevent10 = (ctrl2id.decode_op3_sel == SEL_WB) && softresetn && softresetn_q &&
          decode_valid && exe_ready;

      /// Writeback -> Exe bypass on op1 or op2
      assign mhpmevent11 = 1'b0;
      // assign mhpmevent11 = (ctrl2id.exe_op1_sel == SEL_WB || ctrl2id.exe_op2_sel == SEL_WB) &&
      //                      softresetn && softresetn_q && decode_valid && exe_ready;

      /// Writeback -> Exe bypass on op3
      assign mhpmevent12 = (ctrl2id.exe_op3_sel == SEL_WB) && softresetn && softresetn_q &&
          decode_valid && exe_ready;

      /// Writeback -> Mem bypass on op3
      assign mhpmevent13 = 1'b0;
      // wire mhpmevent13 = (ctrl2id.mem_op3_sel == SEL_WB) && softresetn && softresetn_q &&
      //                    decode_valid && exe_ready;

    end
    else begin : gen_no_perf_events

      /// Disable mhpmevent3
      assign mhpmevent3  = 1'b0;
      /// Disable mhpmevent4
      assign mhpmevent4  = 1'b0;
      /// Disable mhpmevent5
      assign mhpmevent5  = 1'b0;
      /// Disable mhpmevent6
      assign mhpmevent6  = 1'b0;
      /// Disable mhpmevent7
      assign mhpmevent7  = 1'b0;
      /// Disable mhpmevent8
      assign mhpmevent8  = 1'b0;
      /// Disable mhpmevent9
      assign mhpmevent9  = 1'b0;
      /// Disable mhpmevent10
      assign mhpmevent10 = 1'b0;
      /// Disable mhpmevent11
      assign mhpmevent11 = 1'b0;
      /// Disable mhpmevent12
      assign mhpmevent12 = 1'b0;
      /// Disable mhpmevent13
      assign mhpmevent13 = 1'b0;

    end
  endgenerate

  gpr #(
      .Archi(Archi)
  ) gpr (
`ifdef SIM
      .memory_o  (gpr_memory_o),
`endif
      .clk_i     (clk_i),
      .rstn_i    (rstn_i),
      .rs1_i     (rs1),
      .rs2_i     (rs2),
      .wb_valid_i(gpr_wdata_valid),
      .rd_i      (rd),
      .rd_data_i (gpr_wdata),
      .rs1_data_o(rs1_data),
      .rs2_data_o(rs2_data)
  );


  csr #(
      .Archi             (Archi),
      .EnablePerfCounters(EnablePerfCounters)
  ) csr (
`ifdef SIM
      .en_i         (csr_en_i),
      .data_i       (csr_data_i),
`endif
      .mhpmevent3_i (mhpmevent3),
      .mhpmevent4_i (mhpmevent4),
      .mhpmevent5_i (mhpmevent5),
      .mhpmevent6_i (mhpmevent6),
      .mhpmevent7_i (mhpmevent7),
      .mhpmevent8_i (mhpmevent8),
      .mhpmevent9_i (mhpmevent9),
      .mhpmevent10_i(mhpmevent10),
      .mhpmevent11_i(mhpmevent11),
      .mhpmevent12_i(mhpmevent12),
      .mhpmevent13_i(mhpmevent13),
      .clk_i        (clk_i),
      .rstn_i       (rstn_i),
      .waddr_i      (csr_waddr),
      .wdata_i      (csr_wdata),
      .wen_i        (csr_wdata_valid),
      .raddr_i      (csr_raddr),
      .rdata_o      (csr_data)
  );

  ctrl #(
      .Archi       (Archi),
      .StartAddress(StartAddress)
  ) ctrl (
      .clk_i         (clk_i),
      .rstn_i        (rstn_i),
      .imem_rvalid_i (imem_rvalid_i),
      .if2ctrl_i     (if2ctrl),
      .fetch_valid_i (fetch_valid),
      .ctrl2id_o     (ctrl2id),
      .exe2ctrl_i    (exe2ctrl),
      .mem2ctrl_i    (mem2ctrl),
      .wb2ctrl_i     (wb2ctrl),
      .decode_ready_i(decode_ready),
      .mem_ready_i   (mem_ready),
      .softresetn_o  (softresetn),
      .pc_o          (pc)
  );

`ifdef SIM
  assign csr_raddr_o      = csr_raddr;
  assign pipeline_flush_o = !softresetn || !softresetn_q;
`endif

  /// softresetn registration
  /*
  * This block saves the softresetn value.
  * This value is then used to trigger a flush of the
  * Decode stage.
  *
  * Using this register and not the `softresetn`
  * signal breaks the critical path
  * due to data hazard handling.
  *
  * From a behavioral point of view, this has no consequences
  * and the front-end of the pipeline (fetch/decode/exe) is
  * correctly flushed.
  */
  always_ff @(posedge clk_i) begin : softresetn_reg
    if (!rstn_i) begin
      softresetn_q <= '0;
    end
    else begin
      softresetn_q <= softresetn;
    end
  end

  /*!
  * When a jump occurs:
  * - First cycle: fetch is flushed
  * - Second cycle: decode is flushed (= not ready).
  *
  * As fetch requests a new instruction only if decode is ready,
  * there is a two cycles penality.
  * To avoid the second cycle penality, fetch verifies if decode is
  * ready or under reset:
  * - If ready, no issues.
  * - If under reset, it will be ready at the next cycle
  *   when the instruction will be available because `softresetn`
  *   is a one cyle pulse.
  */
  fetch #(
      .Archi(Archi)
  ) fetch (
      .clk_i         (clk_i),
      .rstn_i        (rstn_i && softresetn),
      .pc_i          (pc),
      .decode_ready_i(decode_ready || !softresetn_q),
      .valid_o       (fetch_valid),
      .if2id_o       (if2id),
      .if2ctrl_o     (if2ctrl),
      .req_o         (imem_req_o),
      .gnt_i         (imem_gnt_i),
      .addr_o        (imem_addr_o),
      .rvalid_i      (imem_rvalid_i),
      .rdata_i       (imem_rdata_i),
      .err_i         (imem_err_i)
  );

  decode #(
      .Archi(Archi)
  ) decode (
      .clk_i        (clk_i),
      .rstn_i       (rstn_i && softresetn_q),
      .fetch_valid_i(fetch_valid),
      .exe_ready_i  (exe_ready),
      .ready_o      (decode_ready),
      .valid_o      (decode_valid),
      .rs1_o        (rs1),
      .rs1_data_i   (rs1_data),
      .rs2_o        (rs2),
      .rs2_data_i   (rs2_data),
      .exe2id_i     (exe2id),
      .mem2id_i     (mem2id),
      .wb2id_i      (wb2id),
      .csr_raddr_o  (csr_raddr),
      .csr_data_i   (csr_data),
      .ctrl2id_i    (ctrl2id),
      .if2id_i      (if2id),
      .id2exe_o     (id2exe)
  );

  exe #(
      .Archi(Archi)
  ) exe (
      .clk_i         (clk_i),
      .rstn_i        (rstn_i && softresetn),
      .decode_valid_i(decode_valid),
      .mem_ready_i   (mem_ready),
      .ready_o       (exe_ready),
      .valid_o       (exe_valid),
      .id2exe_i      (id2exe),
      .wb2exe_i      (wb2exe),
      .exe2mem_o     (exe2mem),
      .exe2ctrl_o    (exe2ctrl),
      .exe2id_o      (exe2id)
  );

  mem #(
      .Archi(Archi)
  ) mem (
      .clk_i      (clk_i),
      .rstn_i     (rstn_i),
      .exe_valid_i(exe_valid),
      .ready_o    (mem_ready),
      .valid_o    (mem_valid),
      .exe2mem_i  (exe2mem),
      // .wb2mem_i   (wb2mem),
      .mem2wb_o   (mem2wb),
      .mem2ctrl_o (mem2ctrl),
      .mem2id_o   (mem2id),
      .req_o      (dmem_req_o),
      .gnt_i      (dmem_gnt_i),
      .addr_o     (dmem_addr_o),
      .we_o       (dmem_we_o),
      .wdata_o    (dmem_wdata_o),
      .be_o       (dmem_be_o),
      .rvalid_i   (dmem_rvalid_i),
      .err_i      (dmem_err_i)
  );

  writeback #(
      .Archi(Archi)
  ) writeback (
`ifdef SIM
      .instr_committed_o(instr_committed_o),
`endif
      .clk_i            (clk_i),
      .rstn_i           (rstn_i),
      .mem_valid_i      (mem_valid),
      .mem2wb_i         (mem2wb),
      .wb2ctrl_o        (wb2ctrl),
      .wb2id_o          (wb2id),
      .wb2exe_o         (wb2exe),
      // .wb2mem_o         (wb2mem),
      .rd_o             (rd),
      .gpr_wdata_o      (gpr_wdata),
      .csr_waddr_o      (csr_waddr),
      .csr_wdata_o      (csr_wdata),
      .rdata_i          (dmem_rdata_i),
      .gpr_wdata_valid_o(gpr_wdata_valid),
      .csr_wdata_valid_o(csr_wdata_valid)
  );

endmodule
