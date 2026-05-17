// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       csr.sv
\brief      scholar risc-v core control/status registers file module
\author     Kawanami
\date       16/05/2026
\version    1.2

\details
  This module implements the scholar risc-v Control and Status Register (CSR) file.

  Implemented counters:
    - `mhpmcounter0` : cycle counter (`mcycle`)
    - `mhpmcounter3` : data-hazard stall cycles (`mhpmevent3_i`)
    - `mhpmcounter4` : taken branches (softresetn) events (`mhpmevent4_i`)
    - `mhpmcounter5` : Exe -> Decode bypass uses (op1/op2) (`mhpmevent5_i`)
    - `mhpmcounter6` : Exe -> Decode bypass uses (op3) (`mhpmevent6_i`)
    - `mhpmcounter7` : Mem -> Decode bypass uses (op1/op2) (`mhpmevent7_i`)
    - `mhpmcounter8` : Mem -> Decode bypass uses (op3) (`mhpmevent8_i`)
    - `mhpmcounter9` : Writeback -> Decode bypass uses (op1/op2) (`mhpmevent9_i`)
    - `mhpmcounter10`: Writeback -> Decode bypass uses (op3) (`mhpmevent10_i`)
    - `mhpmcounter11`: Writeback -> Exe bypass uses (op1/op2) (`mhpmevent11_i`)
    - `mhpmcounter12`: Writeback -> Exe bypass uses (op3) (`mhpmevent12_i`)
    - `mhpmcounter13`: Writeback -> Mem bypass uses (op3) (`mhpmevent13_i`)

  CSR addressing follows the standard mhpmcounter mapping:
    - 0xB00..0xB0D : lower 32 bits (RV32 low / RV64 full)
    - 0xB80..0xB8D : upper 32 bits (RV32 high / RV64 full for compatibility)

  All counters are read-only: writes are ignored.

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section csr_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 07/03/2026 | Kawanami   | Initial version of the module.            |
| 1.1     | 26/03/2026 | Kawanami   | Add simulation driven signals to overwrite CSR value (for spike compatibility).            |
| 1.1     | 16/05/2026 | Kawanami   | Add EnablePerfCounters parameter to enable/disable CSR implementation. |
********************************************************************************
*/

module csr

  /*!
  * Import useful packages.
  */
  import core_pkg::CSR_ADDR_WIDTH;
/**/

#(
  /// Architecture to build (either 32-bit or 64-bit)
  parameter int unsigned                 Archi              = 32,
  /// Enable performance Counters
  parameter bit          EnablePerfCounters = 1'b1
) (
`ifdef SIM
    /// Simulation CSR overwrite enable
    input wire                          en_i,
    /// Simulation CSR overwrite data
    input wire [Archi          - 1 : 0] data_i,
`endif

    /// System clock
    input  wire                          clk_i,
    /// System active low reset
    input  wire                          rstn_i,
    /* verilator lint_off UNUSEDSIGNAL */
    /// CSR write address
    input  wire [CSR_ADDR_WIDTH - 1 : 0] waddr_i,
    /// CSR write enable
    input  wire                          wen_i,
    /// Data to write in the CSR
    input  wire [Archi     - 1 : 0] wdata_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /// CSR read address
    input  wire [CSR_ADDR_WIDTH - 1 : 0] raddr_i,
    /// CSR read value
    output wire [Archi     - 1 : 0] rdata_o,
    /// Data hazard stall (rs1 or rs2 dirty)
    input  wire                          mhpmevent3_i,
    /// Branch event (softresetn)
    input  wire                          mhpmevent4_i,
    /// Exe -> Decode bypass (op1 or op2)
    input  wire                          mhpmevent5_i,
    /// Exe -> Decode bypass (op3)
    input  wire                          mhpmevent6_i,
    /// Mem -> Decode bypass (op1 or op2)
    input  wire                          mhpmevent7_i,
    /// Mem -> Decode bypass (op3)
    input  wire                          mhpmevent8_i,
    /// Writeback -> Decode bypass (op1 or op2)
    input  wire                          mhpmevent9_i,
    /// Writeback -> Decode bypass (op3)
    input  wire                          mhpmevent10_i,
    /// Writeback -> Exe bypass (op1 or op2)
    input  wire                          mhpmevent11_i,
    /// Writeback -> Exe bypass (op3)
    input  wire                          mhpmevent12_i,
    /// Writeback -> Mem bypass (op3)
    input  wire                          mhpmevent13_i
);

  generate
    if (EnablePerfCounters) begin : gen_with_perf_counters

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER0_ADDR_HI = 'hb80;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER0_ADDR = 'hb00;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER3_ADDR_HI = 'hb83;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER3_ADDR = 'hb03;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER4_ADDR_HI = 'hb84;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER4_ADDR = 'hb04;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER5_ADDR_HI = 'hb85;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER5_ADDR = 'hb05;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER6_ADDR_HI = 'hb86;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER6_ADDR = 'hb06;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER7_ADDR_HI = 'hb87;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER7_ADDR = 'hb07;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER8_ADDR_HI = 'hb88;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER8_ADDR = 'hb08;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER9_ADDR_HI = 'hb89;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER9_ADDR = 'hb09;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER10_ADDR_HI = 'hb8a;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER10_ADDR = 'hb0a;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER11_ADDR_HI = 'hb8b;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER11_ADDR = 'hb0b;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER12_ADDR_HI = 'hb8c;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER12_ADDR = 'hb0c;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER13_ADDR_HI = 'hb8d;
  localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER13_ADDR = 'hb0d;

  /* functions */

  /* wires */
  /// Read data
  logic [Archi - 1 : 0] rdata;


  /* registers */
  /// mhpmcounter0 register (mcycle)
  reg   [            63 : 0] mhpmcounter0_q;
  /// mhpmcounter3 register (stall)
  reg   [            63 : 0] mhpmcounter3_q;
  /// mhpmcounter4 register (taken branches)
  reg   [            63 : 0] mhpmcounter4_q;
  /// mhpmcounter5 register (Exe -> Decode bypass - op1/op2)
  reg   [            63 : 0] mhpmcounter5_q;
  /// mhpmcounter6 register (Exe -> Decode bypass - op3)
  reg   [            63 : 0] mhpmcounter6_q;
  /// mhpmcounter7 register (Mem -> Decode bypass - op1/op2)
  reg   [            63 : 0] mhpmcounter7_q;
  /// mhpmcounter8 register (Mem -> Decode bypass - op3)
  reg   [            63 : 0] mhpmcounter8_q;
  /// mhpmcounter9 register (Writeback -> Decode bypass - op1/op2)
  reg   [            63 : 0] mhpmcounter9_q;
  /// mhpmcounter10 register (Writeback -> Decode bypass - op3)
  reg   [            63 : 0] mhpmcounter10_q;
  /// mhpmcounter11 register (Writeback -> Exe bypass - op1/op2)
  reg   [            63 : 0] mhpmcounter11_q;
  /// mhpmcounter12 register (Writeback -> Exe bypass - op3)
  reg   [            63 : 0] mhpmcounter12_q;
  /// mhpmcounter13 register (Writeback -> Mem bypass - op3)
  reg   [            63 : 0] mhpmcounter13_q;
  /********************             ********************/

  /// mhpmcounters write logic
  /*!
  * This block drives the mhpmcounter0 and mhpmcounter3-13,
  * registers.
  *
  * All of these registers are read-only and cannot be
  * overwritten using CSR instructions.
  *
  * These registers can be used for basic performance monitoring
  * or instruction timing analysis.
  *
  * Each `mhpmevent*_i` input is expected to be a one-cycle pulse.
  */
  always_ff @(posedge clk_i) begin : mhpmcounters_write
    if (!rstn_i) begin
      mhpmcounter0_q  <= '0;
      mhpmcounter3_q  <= '0;
      mhpmcounter4_q  <= '0;
      mhpmcounter5_q  <= '0;
      mhpmcounter6_q  <= '0;
      mhpmcounter7_q  <= '0;
      mhpmcounter8_q  <= '0;
      mhpmcounter9_q  <= '0;
      mhpmcounter10_q <= '0;
      mhpmcounter11_q <= '0;
      mhpmcounter12_q <= '0;
      mhpmcounter13_q <= '0;
    end
    else begin
      mhpmcounter0_q <= mhpmcounter0_q + 1;
      if (mhpmevent3_i) mhpmcounter3_q <= mhpmcounter3_q + 1;
      if (mhpmevent4_i) mhpmcounter4_q <= mhpmcounter4_q + 3;
      if (mhpmevent5_i) mhpmcounter5_q <= mhpmcounter5_q + 1;
      if (mhpmevent6_i) mhpmcounter6_q <= mhpmcounter6_q + 1;
      if (mhpmevent7_i) mhpmcounter7_q <= mhpmcounter7_q + 1;
      if (mhpmevent8_i) mhpmcounter8_q <= mhpmcounter8_q + 1;
      if (mhpmevent9_i) mhpmcounter9_q <= mhpmcounter9_q + 1;
      if (mhpmevent10_i) mhpmcounter10_q <= mhpmcounter10_q + 1;
      if (mhpmevent11_i) mhpmcounter11_q <= mhpmcounter11_q + 1;
      if (mhpmevent12_i) mhpmcounter12_q <= mhpmcounter12_q + 1;
      if (mhpmevent13_i) mhpmcounter13_q <= mhpmcounter13_q + 1;
    end
  end


  /// CSR read logic
  /*!
  * This block drives rdata according to raddr_i.
  * On RV32, the low and high halves are exposed through the standard CSR addresses.
  * On RV64, both low and high addresses return the full 64-bit counter value for compatibility.
  */
    if (Archi == 64) begin : gen_csrs_read_64
      always_comb begin : csrs_read
        case (raddr_i)
          MHPMCOUNTER0_ADDR_HI, MHPMCOUNTER0_ADDR:   rdata = mhpmcounter0_q[Archi-1:0];
          MHPMCOUNTER3_ADDR_HI, MHPMCOUNTER3_ADDR:   rdata = mhpmcounter3_q[Archi-1:0];
          MHPMCOUNTER4_ADDR_HI, MHPMCOUNTER4_ADDR:   rdata = mhpmcounter4_q[Archi-1:0];
          MHPMCOUNTER5_ADDR_HI, MHPMCOUNTER5_ADDR:   rdata = mhpmcounter5_q[Archi-1:0];
          MHPMCOUNTER6_ADDR_HI, MHPMCOUNTER6_ADDR:   rdata = mhpmcounter6_q[Archi-1:0];
          MHPMCOUNTER7_ADDR_HI, MHPMCOUNTER7_ADDR:   rdata = mhpmcounter7_q[Archi-1:0];
          MHPMCOUNTER8_ADDR_HI, MHPMCOUNTER8_ADDR:   rdata = mhpmcounter8_q[Archi-1:0];
          MHPMCOUNTER9_ADDR_HI, MHPMCOUNTER9_ADDR:   rdata = mhpmcounter9_q[Archi-1:0];
          MHPMCOUNTER10_ADDR_HI, MHPMCOUNTER10_ADDR: rdata = mhpmcounter10_q[Archi-1:0];
          MHPMCOUNTER11_ADDR_HI, MHPMCOUNTER11_ADDR: rdata = mhpmcounter11_q[Archi-1:0];
          MHPMCOUNTER12_ADDR_HI, MHPMCOUNTER12_ADDR: rdata = mhpmcounter12_q[Archi-1:0];
          MHPMCOUNTER13_ADDR_HI, MHPMCOUNTER13_ADDR: rdata = mhpmcounter13_q[Archi-1:0];
          default:                                   rdata = '0;
        endcase
      end
    end
    else begin : gen_csrs_read_32
      always_comb begin : csrs_read
        case (raddr_i)
          MHPMCOUNTER0_ADDR_HI:  rdata = mhpmcounter0_q[63:32];
          MHPMCOUNTER0_ADDR:     rdata = mhpmcounter0_q[31:0];
          MHPMCOUNTER3_ADDR_HI:  rdata = mhpmcounter3_q[63:32];
          MHPMCOUNTER3_ADDR:     rdata = mhpmcounter3_q[31:0];
          MHPMCOUNTER4_ADDR_HI:  rdata = mhpmcounter4_q[63:32];
          MHPMCOUNTER4_ADDR:     rdata = mhpmcounter4_q[31:0];
          MHPMCOUNTER5_ADDR_HI:  rdata = mhpmcounter5_q[63:32];
          MHPMCOUNTER5_ADDR:     rdata = mhpmcounter5_q[31:0];
          MHPMCOUNTER6_ADDR_HI:  rdata = mhpmcounter6_q[63:32];
          MHPMCOUNTER6_ADDR:     rdata = mhpmcounter6_q[31:0];
          MHPMCOUNTER7_ADDR_HI:  rdata = mhpmcounter7_q[63:32];
          MHPMCOUNTER7_ADDR:     rdata = mhpmcounter7_q[31:0];
          MHPMCOUNTER8_ADDR_HI:  rdata = mhpmcounter8_q[63:32];
          MHPMCOUNTER8_ADDR:     rdata = mhpmcounter8_q[31:0];
          MHPMCOUNTER9_ADDR_HI:  rdata = mhpmcounter9_q[63:32];
          MHPMCOUNTER9_ADDR:     rdata = mhpmcounter9_q[31:0];
          MHPMCOUNTER10_ADDR_HI: rdata = mhpmcounter10_q[63:32];
          MHPMCOUNTER10_ADDR:    rdata = mhpmcounter10_q[31:0];
          MHPMCOUNTER11_ADDR_HI: rdata = mhpmcounter11_q[63:32];
          MHPMCOUNTER11_ADDR:    rdata = mhpmcounter11_q[31:0];
          MHPMCOUNTER12_ADDR_HI: rdata = mhpmcounter12_q[63:32];
          MHPMCOUNTER12_ADDR:    rdata = mhpmcounter12_q[31:0];
          MHPMCOUNTER13_ADDR_HI: rdata = mhpmcounter13_q[63:32];
          MHPMCOUNTER13_ADDR:    rdata = mhpmcounter13_q[31:0];
          default:               rdata = '0;
        endcase
      end
    end

  `ifdef SIM
        /// Output driven by csrs_read
        assign rdata_o = en_i ? data_i : rdata;
  `else
        /// Output driven by csrs_read
        assign rdata_o = rdata;
  `endif




    end
    else begin : gen_without_perf_counters

      /******************** DECLARATION ********************/
      /* parameters verification */

      /* local parameters */
      /// mcycle upper 32-bit CSR address (RV32 only)
      localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER0_ADDR_HI = 'hb80;
      /// mcycle lower CSR address
      localparam logic [CSR_ADDR_WIDTH - 1 : 0] MHPMCOUNTER0_ADDR = 'hb00;

      /* functions */

      /* wires */
      /// Read data
      logic [Archi - 1 : 0] rdata;


      /* registers */
      /// mhpmcounter0 register (mcycle)
      reg   [       63 : 0] mhpmcounter0_q;
      /********************             ********************/



      /// mhpmcounters write logic
      /*!
      * This block drives the mhpmcounter0, mhpmcounter3,
      * and mhpmcounter4 registers.
      *
      * The mhpmcounter0 counts the number of clock cycles since reset.
      * The mhpmcounter3 counts the number of stalled cycles.
      * The mhpmcounter4 count the number of taken branches.
      *
      * All of these registers are read-only and cannot be
      * overwritten using CSR instructions.
      *
      * These registers can be used for basic performance monitoring
      * or instruction timing analysis.
      */
      always_ff @(posedge clk_i) begin : mhpmcounters_write
        if (!rstn_i) begin
          mhpmcounter0_q <= '0;
        end
        else begin
          mhpmcounter0_q <= mhpmcounter0_q + 1;
        end
      end

      /// CSR read logic
      /*!
      * This block drives rdata according to raddr_i.
      * On RV32, the low and high halves are exposed through the standard CSR addresses.
      * On RV64, both low and high addresses return the full 64-bit counter value for compatibility.
      */
      if (Archi == 64) begin : gen_csrs_read_64
        always_comb begin : csrs_read
          case (raddr_i)
            MHPMCOUNTER0_ADDR_HI, MHPMCOUNTER0_ADDR: rdata = mhpmcounter0_q[Archi-1:0];
            default:                                 rdata = '0;
          endcase
        end
      end
      else begin : gen_csrs_read_32
        always_comb begin : csrs_read
          case (raddr_i)
            MHPMCOUNTER0_ADDR_HI: rdata = mhpmcounter0_q[63:32];
            MHPMCOUNTER0_ADDR:    rdata = mhpmcounter0_q[31:0];
            default:              rdata = '0;
          endcase
        end
      end

`ifdef SIM
      /// Output driven by csrs_read
      assign rdata_o = en_i ? data_i : rdata;
`else
      /// Output driven by csrs_read
      assign rdata_o = rdata;
`endif

    end

    endgenerate

endmodule

