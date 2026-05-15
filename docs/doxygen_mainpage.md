# scholar risc-v Pipeline Code Documentation

This documentation describes the source code of the **scholar risc-v pipeline**
core.

The goal of this page is to provide a code-oriented entry point: where the RTL
files are located, which module to read first, how the pipeline stages are
connected, and where to look when debugging hazards, stalls, flushes, memory
accesses, or writeback behavior.

For the global project overview, supported instructions, results, and learning
context, start from the repository `README.md`.

---

## Source Tree Overview {#source_tree_overview}

```text
scholar-risc-v/
├── Makefile
├── README.md
├── docs/
├── img/
└── risc-v/
    ├── scholar_riscv_core.sv
    ├── common/
    │   ├── core_pkg.sv
    │   ├── if2id_if.sv
    │   ├── if2ctrl_if.sv
    │   ├── id2exe_if.sv
    │   ├── exe2mem_if.sv
    │   ├── exe2ctrl_if.sv
    │   ├── mem2wb_if.sv
    │   ├── mem2ctrl_if.sv
    │   └── wb2ctrl_if.sv
    ├── fetch/
    │   └── fetch.sv
    ├── decode/
    │   ├── decode.sv
    │   └── decode_unit.sv
    ├── exe/
    │   ├── exe.sv
    │   └── alu.sv
    ├── mem/
    │   ├── mem.sv
    │   └── mem_unit.sv
    ├── writeback/
    │   ├── writeback.sv
    │   └── writeback_unit.sv
    ├── ctrl/
    │   ├── ctrl.sv
    │   └── pc.sv
    ├── gpr/
    │   └── gpr.sv
    └── csr/
        └── csr.sv
```

---

## Main Code Areas {#main_code_areas}

| Area | Purpose |
|:-----|:--------|
| [`risc-v/scholar_riscv_core.sv`](#top_level_core) | Top-level core integration. |
| [`risc-v/common/`](#common_files) | Shared package and pipeline interfaces. |
| [`risc-v/fetch/`](#fetch_stage) | Instruction fetch stage. |
| [`risc-v/decode/`](#decode_stage) | Decode stage, immediate generation, hazard checks, and control generation. |
| [`risc-v/exe/`](#execute_stage) | Execute stage and ALU. |
| [`risc-v/mem/`](#memory_stage) | Memory stage and data memory interface handling. |
| [`risc-v/writeback/`](#writeback_stage) | Writeback stage and architectural state update. |
| [`risc-v/ctrl/`](#control_logic) | Program counter update, stalls, flushes, and pipeline control. |
| [`risc-v/gpr/`](#gpr_file) | General-purpose register file. |
| [`risc-v/csr/`](#csr_file) | Control and status register file. |

---

## Pipeline Overview {#pipeline_overview}

This branch implements a simple in-order RISC-V pipeline.

The pipeline is organized around five main stages:

```text
Fetch -> Decode -> Execute -> Memory -> Writeback
```

Each stage exchanges data with the next stage through dedicated SystemVerilog
interfaces stored in `risc-v/common/`.

The control logic supervises the front-end and the pipeline by handling:

- program counter updates,
- taken branches and jumps,
- pipeline flushes,
- decode stalls caused by data hazards,
- stage readiness and valid propagation.

This implementation favors readability and educational clarity over aggressive
microarchitectural optimization.

---

## Top-Level Core {#top_level_core}

Path:

```text
risc-v/scholar_riscv_core.sv
```

Main module:

```text
scholar_riscv_core
```

This is the main RTL entry point of the pipeline core.

It instantiates and connects the major blocks:

- `fetch`
- `decode`
- `exe`
- `mem`
- `writeback`
- `ctrl`
- `pc`
- `gpr`
- `csr`

It also exposes the external instruction and data memory interfaces used by the
simulation and harness environment.

Start here when you want to understand the complete pipeline integration and how
stage interfaces, register file access, CSR access, memory access, and control
logic are connected.

---

## Common Files {#common_files}

Path:

```text
risc-v/common/
```

This directory contains the shared package and the interfaces used between
pipeline stages and control logic.

### Core Package

Main file:

```text
core_pkg.sv
```

The package centralizes core-wide constants and control encodings.

Typical contents include:

- RISC-V instruction field widths,
- register file constants,
- ALU and execution control encodings,
- memory access control encodings,
- program-counter control encodings,
- GPR writeback control encodings,
- CSR control encodings.

Start here when you need to understand the symbolic values exchanged between
`decode_unit`, `alu`, `mem_unit`, `writeback_unit`, and `ctrl`.

### Pipeline Interfaces

Main files:

```text
if2id_if.sv
if2ctrl_if.sv
id2exe_if.sv
exe2mem_if.sv
exe2ctrl_if.sv
mem2wb_if.sv
mem2ctrl_if.sv
wb2ctrl_if.sv
```

These interfaces group the signals exchanged between stages.

They make pipeline dataflow explicit and reduce long flat port lists between
stage wrappers.

---

## Fetch Stage {#fetch_stage}

Path:

```text
risc-v/fetch/fetch.sv
```

Main module:

```text
fetch
```

The fetch stage requests the instruction located at the current program counter
from the instruction memory interface.

Its main responsibilities are:

- issue instruction memory requests,
- drive the instruction memory address,
- receive instruction memory responses,
- provide the fetched instruction and its PC to Decode,
- provide early instruction fields to the controller when needed,
- hold or advance according to downstream readiness.

Start here when debugging instruction fetch, instruction memory handshakes, or
front-end valid propagation.

---

## Decode Stage {#decode_stage}

Path:

```text
risc-v/decode/
```

Main modules:

```text
decode
decode_unit
```

The decode stage interprets the fetched instruction and generates the control
signals required by the rest of the pipeline.

### `decode.sv`

The `decode` module is the stage wrapper.

It is responsible for:

- receiving IF->ID pipeline data,
- handling stage valid/ready behavior,
- reading source register operands from the GPR file,
- checking dirty/source-register dependencies,
- passing decoded data and control signals to Execute.

### `decode_unit.sv`

The `decode_unit` module contains the instruction decoding logic.

Its main responsibilities are:

- extract instruction fields,
- decode opcodes, `funct3`, and `funct7`,
- generate immediate values,
- select source and destination registers,
- generate execution control signals,
- generate memory control signals,
- generate CSR control signals,
- generate writeback control signals.

Start here when adding, modifying, or debugging instruction support.

---

## Execute Stage {#execute_stage}

Path:

```text
risc-v/exe/
```

Main modules:

```text
exe
alu
```

The execute stage performs arithmetic, logical, branch, and address computations.

### `exe.sv`

The `exe` module is the stage wrapper.

It is responsible for:

- receiving ID->EXE pipeline data,
- holding stage data when the Memory stage is not ready,
- forwarding execution results to the Memory stage,
- forwarding branch/jump information to the controller.

### `alu.sv`

The `alu` module performs the computation selected by Decode.

Typical operations include:

- integer arithmetic,
- logical operations,
- shifts,
- comparisons,
- branch condition evaluation,
- jump and branch target-related computation,
- effective address computation for memory operations.

Start here when debugging ALU behavior, branch decisions, arithmetic results, or
effective address generation.

---

## Memory Stage {#memory_stage}

Path:

```text
risc-v/mem/
```

Main modules:

```text
mem
mem_unit
```

The Memory stage handles data memory accesses and forwards results toward
Writeback.

### `mem.sv`

The `mem` module is the stage wrapper.

It is responsible for:

- receiving EXE->MEM pipeline data,
- holding stage data while memory transactions complete,
- exposing valid/ready behavior to adjacent stages,
- forwarding MEM->WB pipeline data.

### `mem_unit.sv`

The `mem_unit` module handles the data memory interface.

Its main responsibilities are:

- generate data memory requests,
- drive memory addresses,
- generate byte enables,
- drive store data,
- receive load data,
- wait for memory responses,
- report memory-stage completion.

Start here when debugging loads, stores, memory stalls, byte enables, or memory
interface handshakes.

---

## Writeback Stage {#writeback_stage}

Path:

```text
risc-v/writeback/
```

Main modules:

```text
writeback
writeback_unit
```

The Writeback stage updates the architectural state of the core.

### `writeback.sv`

The `writeback` module is the stage wrapper.

It is responsible for:

- receiving MEM->WB pipeline data,
- selecting GPR and CSR write enables,
- exposing writeback destination information to the controller,
- generating instruction commit information for simulation and benchmarking.

### `writeback_unit.sv`

The `writeback_unit` module selects the final value written back to the
architectural state.

Its main responsibilities are:

- select ALU result, memory load data, CSR data, or PC-related values,
- generate GPR writeback data,
- generate CSR writeback data,
- drive write enables according to decoded control signals.

Start here when debugging wrong register values, wrong CSR writes, or instruction
commit behavior.

---

## Control Logic {#control_logic}

Path:

```text
risc-v/ctrl/
```

Main modules:

```text
ctrl
pc
```

The control logic handles pipeline-level decisions.

### `ctrl.sv`

The `ctrl` module supervises pipeline hazards and control-flow changes.

Its main responsibilities are:

- detect data hazards from source and destination register information,
- request Decode stalls when operands are not ready,
- receive branch/jump information from Execute,
- receive in-flight destination information from later stages,
- generate pipeline flush requests,
- control front-end restart after control-flow redirection.

Start here when debugging stalls, hazards, taken branches, jumps, or pipeline
flush behavior.

### `pc.sv`

The `pc` module updates the program counter.

Its main responsibilities are:

- hold the current PC,
- select the next PC according to controller decisions,
- select sequential, branch, jump, or reset addresses,
- provide the PC used by Fetch.

Start here when debugging wrong fetch addresses or wrong control-flow redirection.

---

## General-Purpose Register File {#gpr_file}

Path:

```text
risc-v/gpr/gpr.sv
```

Main module:

```text
gpr
```

The GPR block contains the integer register file.

Its main responsibilities are:

- provide source-register read data,
- receive destination-register writeback data,
- keep register `x0` hardwired to zero,
- expose simulation-only register state when `SIM` is enabled.

Start here when debugging operand values or register writeback behavior.

---

## CSR File {#csr_file}

Path:

```text
risc-v/csr/csr.sv
```

Main module:

```text
csr
```

The CSR block implements the control and status registers currently supported by
the pipeline core.

It provides CSR read/write behavior and optional performance counters through
the `EnablePerfCounters` parameter.

Typical uses include:

- cycle counting,
- custom performance counter reads,
- simulation/debug CSR access,
- firmware-visible CSR reads and writes.

Start here when debugging CSR reads, CSR writes, cycle counter behavior, or
performance counter configuration.

---

## External Interfaces {#external_interfaces}

The top-level core exposes two memory-facing interfaces:

- instruction memory interface,
- data memory interface.

Both interfaces use the Open Bus Interface (OBI):

- request,
- grant,
- address,
- read-valid,
- read-data,
- write-enable,
- write-data,
- byte-enable,
- error.

The instruction interface is read-oriented, while the data interface supports
loads and stores.

---

## Simulation-Only Signals {#simulation_only_signals}

When `SIM` is defined, the core exposes additional debug and observation signals.

These signals are useful for:

- inspecting the GPR file,
- observing CSR state,
- checking pipeline flushes,
- checking instruction commit events,
- driving testbench-specific CSR overrides.

These signals are not part of the synthesis-oriented functional interface.

---

## Documentation Notes {#documentation_notes}

This Doxygen documentation is intended for source code navigation.

For general project usage, educational explanations, supported instruction lists,
figures, and performance results, refer to the repository `README.md`.
