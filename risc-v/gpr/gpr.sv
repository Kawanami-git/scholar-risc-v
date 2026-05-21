// SPDX-License-Identifier: MIT
/*!
********************************************************************************
\file       gpr.sv
\brief      scholar risc-v core General Purpose Registers file module
\author     Kawanami
\date       21/05/2026
\version    1.4

\details
  This module implements the scholar risc-v register file.
  It contains all general-purpose registers (GPRs).
  It consists of a RAM with two read ports
  (for operand fetch) and one write port (for result storage).

\remarks
  - This implementation complies with [reference or standard].
  - TODO: [possible improvements or future features]

\section gpr_version_history Version history
| Version | Date       | Author     | Description                               |
|:-------:|:----------:|:-----------|:------------------------------------------|
| 1.0     | 19/12/2025 | Kawanami   | Initial version of the module.            |
| 1.1     | 30/01/2026 | Kawanami   | Comments improvment and use local package import instead of global. |
| 1.2     | 19/04/2026 | Kawanami   | Removed GPR overwrite for Spike compatibility, moved the compatibility handling to the CSR path, replaced the architecture definition with a parameter, and removed vendor-backend instantiation. |
| 1.3     | 16/05/2026 | Kawanami   | Update comments. |
| 1.4     | 21/05/2026 | Kawanami   | Replace SIM with SPIKE for more clarity.         |
********************************************************************************
*/

module gpr

  /*
* Import useful packages.
*/
  import core_pkg::RF_ADDR_WIDTH;
  import core_pkg::NB_GPR;
/**/

#(
    /// Architecture to build (either 32-bit or 64-bit)
    parameter int unsigned Archi = 32
) (
`ifdef SPIKE
    /// GPR memory
    output wire [Archi    - 1 : 0] memory_o[NB_GPR],
`endif

    /// System clock
    input  wire                         clk_i,
    /// System active low reset
    input  wire                         rstn_i,
    /// Register Source 1 (rs1)
    input  wire [RF_ADDR_WIDTH - 1 : 0] rs1_i,
    /// Register Source 2 (rs2)
    input  wire [RF_ADDR_WIDTH - 1 : 0] rs2_i,
    /// Write enable flag
    input  wire                         wen_i,
    /// Destination register address
    input  wire [RF_ADDR_WIDTH - 1 : 0] rd_i,
    /// Data written to destination register
    input  wire [     Archi    - 1 : 0] rd_data_i,
    /// Register Source 1 value
    output wire [     Archi    - 1 : 0] rs1_data_o,
    /// Register Source 1 value
    output wire [     Archi    - 1 : 0] rs2_data_o
);

  /******************** DECLARATION ********************/
  /* parameters verification */

  /* local parameters */

  /* functions */

  /* wires */

  /* registers */
  /// General Purpose Registers. x0 = mem[0], x1 = mem[1] ... x31 = mem[31].
  reg [Archi - 1 : 0] mem[NB_GPR];
  /********************             ********************/

  /// General Purpose Registers
  /*!
  * Write operations are performed synchronously,
  * while read operations are handled asynchronously.
  * On reset, the register 0 is initialized with zeroes.
  * Not resetting the other registers does not affect system behavior,
  * and it helps to reduce hardware costs.
  *
  * Memory (mem) is updated only if:
  *   - The address is valid (i.e., greater than 0, to prevent writing to register x0).
  *   - `wen_i` is asserted, indicating that the data input is valid for writing.
  */
  always_ff @(posedge clk_i) begin : gpr_write
    if (!rstn_i) mem[0] <= '0;
    else if (rd_i != '0 && wen_i) mem[rd_i] <= rd_data_i;
  end

  /// Register source 1 value according to Register source address
  assign rs1_data_o = mem[rs1_i];
  /// Register source 2 value according to Register source address
  assign rs2_data_o = mem[rs2_i];

  `ifdef SPIKE
  /// Provide access to the GPR internal memory through `memory_o`
  assign memory_o   = mem;
  `endif

endmodule
