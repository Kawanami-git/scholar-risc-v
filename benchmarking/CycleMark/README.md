# CycleMark Benchmarking

This document provides an explanation on **CycleMark** benchmarking and how it is used in this project to measure the **scholar risc-v** core's performance.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>


## What is CycleMark?

**CycleMark** is based on **CoreMark**, a synthetic benchmark designed to evaluate the performance of microcontroller-class processors. It consists of a set of computational tasks (such as list processing, matrix manipulation, and state machine handling) that reflect typical embedded workloads.

However, the **Embedded Microprocessor Benchmark Consortium (EEMBC)** strictly forbids any modification of the CoreMark source code if the result is to be referred to as “CoreMark.” This ensures consistency and comparability between different implementations.

In this project, several changes were necessary to run the benchmark on the **scholar risc-v** core:
- The original clock based timing mechanism (used to compute **CoreMark** scores) is not supported.
- Output functions used to print the result had to be adapted.
- Performance counters were not displayed.

Performance is now measured using the mcycle register (cycle counter), which counts the number of clock cycles required to run the n iterations of the benchmark.

As a result, while **CycleMark** is functionally similar to **CoreMark** and provides a good approximation of performance, it is not an official **CoreMark** score.<br>
Nonetheless, **CycleMark** can still be used to compare relative performance across **CPU** designs.

<br>
<br>

### CycleMark in scholar risc-v

In this project, **CycleMark** is used to assess how well the **scholar risc-v** core performs by measuring the necessary **execution time (cycle accurate)** to execute one iteration of the **CoreMark** algorithm.

The result obtained from the **CycleMark** benchmark is then converted into a **CycleMark/MHz** value. This value is an approximation of the global **CPI** (Cycles Per Instruction) of the core, giving insight into the overall performance efficiency of the processor.

When coupled with the maximum **frequency** provided by implementation tools, the **CycleMark/MHz** result helps estimate the actual performance of the core in real-world conditions, taking into account both the processor's instruction execution efficiency and its operating speed.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## How to Run CycleMark?

To execute the **CycleMark** benchmark, see the [Simulation Environment](../../simulation_env/README.md) documentation and the [mainpage](../../README.md) documentation.<br>
The default **CycleMark** configuration is used.

> ⚠️ The **CycleMark** simulation may take a significant amount of time. Please do not interrupt it until it completes normally or times out.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## CycleMark log

Once **CycleMark** has been executed, the log files are saved in the **work/cyclemark/log** directory.<br>
Below is an example of a **CycleMark** log output:

![CycleMark log](img/CycleMark_log.png)

This log provides useful information about the configuration and execution of the **CycleMark** benchmark.

The most important value is **Total ticks**, which represents the number of clock cycles required to complete the specified number of **Iterations** of the benchmark.

Although **CycleMark** is not an official **CoreMark** result, it still uses the **CoreMark** algorithm at its core, with some necessary modifications to adapt it to this architecture. See [What is CycleMark?](#what-is-cyclemark) for more details.

To estimate normalized performance independently of the target clock frequency, we use the following formula:

`CycleMark/MHz = Iterations / (Total ticks / 1e6)`

For our example, the **CycleMark/MHz** value is:

`1 / (802686 / 1e6) = 1.24`

This expresses how many benchmark iterations can be completed per million clock cycles. The scaling factor **1e6** is used because **MHz** refers to millions of cycles per second.

This metric is useful to compare the **execution efficiency** of different CPU microarchitectures independently of their maximum clock frequency. In that sense, it can be seen as a practical approximation of the core's global efficiency, similar in spirit to an IPC-like indicator.

However, **CycleMark/MHz** alone does not represent the final performance of an implementation. A core can have a good normalized efficiency but a low maximum frequency, or a high maximum frequency but poor efficiency per cycle.

To estimate the final throughput of a synthesized implementation, we combine the normalized score with the maximum frequency reported by the implementation tools:

`CycleMark/s = CycleMark/MHz × Fmax`

where **Fmax** is expressed in **MHz**.

For example, if a core reaches:

`CycleMark/MHz = 1.24`

and the implementation reaches:

`Fmax = 77 MHz`

then the estimated throughput is:

`CycleMark/s = 1.24 × 77 = 95.5`

This means that, at its maximum frequency, the core can execute approximately
**95.5 CycleMark iterations per second**.

Therefore:

- **CycleMark/MHz** measures how efficiently the core uses clock cycles.
- **CycleMark/s** estimates the final throughput once the maximum operating frequency is taken into account.

Both metrics are useful. **CycleMark/MHz** helps compare microarchitectural efficiency, while **CycleMark/s** helps compare the expected performance of complete implementations.

<br>
<br>

---
