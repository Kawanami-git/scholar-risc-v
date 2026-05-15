// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       writeback_unit.sv
\brief      scholar risc-v core write-back unit
\author     Kawanami
\date       01/05/2026
\version    1.4

\details
  This module implements the write-back unit of the Sscholar risc-v processor core.

 The write-back unit is the final step in instruction execution. It is responsible for:
  - Writing results to the general-purpose register file (GPR), if applicable
  - Updating control and status registers (CSR), if needed

 This unit receives:
  - Results from the Execute (EXE) stage
  - The `op3_i` operand (used for CSR/aux data paths)
  - Control signals (`gpr_ctrl_i`, `csr_ctrl_i`) that determine which updates are applied.


\remarks
- This implementation complies with [reference or standard].
- TODO: [possible improvements or future features]

\section writeback_unit_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 17/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 03/02/2026 | Kawanami   | Add CSR write path.                       |
| 1.2     | 15/02/2026 | Kawanami   | Replace custom interface with OBI standard. |
| 1.3     | 21/04/2026 | Kawanami   | Replace architecture definition with a parameter. |
| 1.4     | 01/05/2026 | Kawanami   | Refactor signals name and fix csr_wen_o signal.   |
********************************************************************************
*/

module writeback_unit

  /*
* Import useful packages.
*/
  import core_pkg::BYTE_LENGTH;
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::GPR_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::MEM_CTRL_WIDTH;
  import core_pkg::CSR_CTRL_WIDTH;
  import core_pkg::CSR_ADDR_WIDTH;
  import core_pkg::CSR_IDLE;
  import core_pkg::CSR_ALU;
  import core_pkg::GPR_IDLE;
  import core_pkg::GPR_MEM;
  import core_pkg::GPR_ALU;
  import core_pkg::GPR_PRGMC;
  import core_pkg::GPR_OP3;
  import core_pkg::MEM_RB;
  import core_pkg::MEM_RBU;
  import core_pkg::MEM_RH;
  import core_pkg::MEM_RHU;
  import core_pkg::MEM_RW;
  import core_pkg::MEM_RWU;
/**/

#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
) (
    /// Exe stage output
    input  wire [         Archi - 1 : 0] exe_out_i,
    /// Third operand (e.g., CSR/aux path source)
    input  wire [         Archi - 1 : 0] op3_i,
    /// Destination register index
    input  wire [ RF_ADDR_WIDTH - 1 : 0] rd_i,
    /// CSR write address
    input  wire [CSR_ADDR_WIDTH - 1 : 0] csr_waddr_i,
    /// GPR control signal
    input  wire [    GPR_CTRL_WIDTH-1:0] gpr_ctrl_i,
    /// CSR control signal
    input  wire [    CSR_CTRL_WIDTH-1:0] csr_ctrl_i,
    /// MEM control signal (read width/signedness for LOADs)
    input  wire [    MEM_CTRL_WIDTH-1:0] mem_ctrl_i,
    /// Destination register index (forwarded)
    output wire [ RF_ADDR_WIDTH - 1 : 0] rd_o,
    /// Data to write into the destination GPR
    output wire [         Archi - 1 : 0] gpr_wdata_o,
    /// CSR address
    output wire [CSR_ADDR_WIDTH - 1 : 0] csr_waddr_o,
    /// CSR write data
    output wire [         Archi - 1 : 0] csr_wdata_o,
    /// Memory read data
    input  wire [    Archi      - 1 : 0] rdata_i,
    /// GPR data valid flag (1: valid  0: not valid)
    output wire                          gpr_wen_o,
    /// CSR data valid flag (1: valid  0: not valid)
    output wire                          csr_wen_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */
  /// Address granularity in bytes (e.g., 4 bytes for 32-bit, 8 for 64-bit)
  localparam int unsigned ADDR_OFFSET = Archi / BYTE_LENGTH;
  /// Number of bits needed to encode byte offset within a word
  localparam int unsigned ADDR_OFFSET_WIDTH = $clog2(ADDR_OFFSET);

  /* functions */

  /* wires */
  /// Data to write into GPR (register file)
  logic [   Archi      - 1 : 0] gpr_wdata;
  /// Byte offset within the aligned read word (for LOADs)
  logic [ADDR_OFFSET_WIDTH-1:0] m_addr_offset;
  /* registers */


  /********************             ********************/

  /// Save memory address offset (LOAD op only)
  assign m_addr_offset = exe_out_i[ADDR_OFFSET_WIDTH-1 : 0];

  /// When CSR is written, it is always the same CSR than the read one
  assign csr_waddr_o   = csr_waddr_i;

  /// Data to update CSR comes from Exe
  assign csr_wdata_o   = exe_out_i;

  /// Only two possibilities: Write the CSR or not
  assign csr_wen_o     = csr_ctrl_i == CSR_ALU ? 1 : 0;

  /// General-Purpose Registers writeback
  /*!
  * Computes the final value written back to the GPR file (`gpr_wdata`)
  * based on the selected source (`gpr_ctrl_i`):
  *   - GPR_ALU    : ALU/EXE result (`exe_out_i`)
  *   - GPR_PRGMC  : Program-counter-relative path (e.g., JAL/JALR) => `op3_i + 4`
  *   - GPR_OP3    : Directly from `op3_i`
  *   - GPR_MEM    : From memory (`rdata_i`) possibly narrowed and sign/zero-extended
  *
  * When `gpr_ctrl_i == GPR_MEM`, `mem_ctrl_i` selects the width/signedness:
  *   - MEM_RB  / MEM_RBU : byte (signed / zero-extended)
  *   - MEM_RH  / MEM_RHU : half-word (signed / zero-extended)
  *   - MEM_RW  / MEM_RWU : word (signed / zero-extended; RV64 only)
  *   - default           : full width (word on RV32, double word on RV64)
  */
  generate

    if (Archi == 32) begin : gen_gpr_wb_32

      logic [15 : 0] mem_rdata;

      always_comb begin : gpr_wb
        mem_rdata = 'b0;

        if (gpr_ctrl_i == GPR_ALU) begin
          gpr_wdata = exe_out_i;
        end
        else if (gpr_ctrl_i == GPR_PRGMC) begin
          gpr_wdata = op3_i + 4;
        end
        else if (gpr_ctrl_i == GPR_OP3) begin
          gpr_wdata = op3_i;
        end
        else if (gpr_ctrl_i == GPR_MEM) begin
          case (mem_ctrl_i)

            MEM_RB, MEM_RBU: begin
              mem_rdata = {8'b00000000, rdata_i[(m_addr_offset*8)+:8]};

              if (mem_ctrl_i == MEM_RBU) gpr_wdata = {{Archi - 8{1'b0}}, mem_rdata[7:0]};
              else
                gpr_wdata = mem_rdata[7] == 1 ?
                    {{Archi - 8{1'b1}}, mem_rdata[7:0]} : {{Archi - 8{1'b0}}, mem_rdata[7:0]};
            end

            MEM_RH, MEM_RHU: begin
              mem_rdata = rdata_i[(m_addr_offset*8)+:16];
              if (mem_ctrl_i == MEM_RHU) gpr_wdata = {{Archi - 16{1'b0}}, mem_rdata[15:0]};
              else
                gpr_wdata = mem_rdata[15] == 1 ?
                    {{Archi - 16{1'b1}}, mem_rdata[15:0]} : {{Archi - 16{1'b0}}, mem_rdata[15:0]};
            end

            default: begin
              gpr_wdata = rdata_i;
            end
          endcase

        end
        else begin
          mem_rdata = '0;
          gpr_wdata = '0;
        end
      end

    end
    else begin : gen_gpr_wb_64

      logic [31 : 0] mem_rdata;

      always_comb begin : gpr_wb
        mem_rdata = 'b0;

        if (gpr_ctrl_i == GPR_ALU) begin
          gpr_wdata = exe_out_i;
        end
        else if (gpr_ctrl_i == GPR_PRGMC) begin
          gpr_wdata = op3_i + 4;
        end
        else if (gpr_ctrl_i == GPR_OP3) begin
          gpr_wdata = op3_i;
        end
        else if (gpr_ctrl_i == GPR_MEM) begin
          case (mem_ctrl_i)

            MEM_RB, MEM_RBU: begin
              mem_rdata = {24'h000000, rdata_i[(m_addr_offset*8)+:8]};

              if (mem_ctrl_i == MEM_RBU) gpr_wdata = {{Archi - 8{1'b0}}, mem_rdata[7:0]};
              else
                gpr_wdata = mem_rdata[7] == 1 ?
                    {{Archi - 8{1'b1}}, mem_rdata[7:0]} : {{Archi - 8{1'b0}}, mem_rdata[7:0]};
            end

            MEM_RH, MEM_RHU: begin
              mem_rdata = {16'h0000, rdata_i[(m_addr_offset*8)+:16]};

              if (mem_ctrl_i == MEM_RHU) gpr_wdata = {{Archi - 16{1'b0}}, mem_rdata[15:0]};
              else
                gpr_wdata = mem_rdata[15] == 1 ?
                    {{Archi - 16{1'b1}}, mem_rdata[15:0]} : {{Archi - 16{1'b0}}, mem_rdata[15:0]};
            end

            MEM_RW, MEM_RWU: begin
              mem_rdata = rdata_i[(m_addr_offset*8)+:32];

              if (mem_ctrl_i == MEM_RWU) gpr_wdata = {{Archi - 32{1'b0}}, mem_rdata[31:0]};
              else
                gpr_wdata = mem_rdata[31] == 1 ?
                    {{Archi - 32{1'b1}}, mem_rdata[31:0]} : {{Archi - 32{1'b0}}, mem_rdata[31:0]};
            end

            default: begin
              gpr_wdata = rdata_i;
            end
          endcase

        end
        else begin
          mem_rdata = '0;
          gpr_wdata = '0;
        end
      end

    end

  endgenerate


  /// Destination register address in the register file
  assign rd_o        = rd_i;
  /// Output driven by rd_gen
  assign gpr_wdata_o = gpr_wdata;
  /// Only two possibilities: Write the GPR or not
  assign gpr_wen_o   = gpr_ctrl_i != GPR_IDLE ? 1 : 0;



endmodule
