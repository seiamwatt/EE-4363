# EE 4363 / CSci 4203 — Lecture 02: How to Quantify "Better"?

---

## 1. The Hardware–Software Stack

A computer system is organized in layers:

> **Hardware** (transistors, wires) → **Microarchitecture** (fetch, decode, latch pipeline stages) → **Architecture/ISA** (instruction-set contract) → **Software** (compilers, OS, applications)

Performance depends on decisions at every layer.

---

## 2. Dennard Scaling (1974)

Each technology generation (~2–3 years), transistors shrink by a factor *κ*:

| Parameter | Scaling Factor |
|---|---|
| V_dd, V_th, C, I | 1/*κ* |
| Area per transistor | 1/*κ*² |
| Transistor delay (C·V/I) | 1/*κ* |
| Power per transistor (V·I) | 1/*κ*² |
| Power density | 1 (constant) |

Two choices with smaller transistors:

- **Keep functionality constant** (same *N* switches): Area and power both shrink by 1/*κ*². Same work, less area, less power.
- **Keep area constant** (fit *κ*² more switches): Total power = *κ*² × 1/*κ*² = unchanged. More functionality at the same power budget.

This historically let each generation be both faster and more efficient, enabling problems like the Human Genome Project.

---

## 3. Post-Dennard / Practical Scaling

Dennard scaling has broken down: V_th scaling stopped (leakage exploded), voltage scaling is stagnating. We can still pack more transistors, but turning extra density into performance now requires actively reducing power.

The **Jevons Paradox** (Khazzoom–Brookes postulate) warns that efficiency improvements often increase total power consumption by making computing cheaper and more widespread.

---

## 4. Classes of Computers

| Class | Key Traits |
|---|---|
| **Desktop** | General-purpose, performance-critical |
| **Server** | Networked, reliability + capacity + performance |
| **Embedded** | Often special-purpose, tight power/performance constraints |

---

## 5. Basic Machine Organization

The computer has a **Processor** (Control + Datapath), **Memory**, and **I/O**. A compiler and interface translate high-level programs into machine instructions. The processor is both a "set of switches" (hardware view) and a "set of instructions" (ISA view).

---

## 6. Software's Role in Performance

Each software layer affects performance:

- The **algorithm** determines operation count
- The **compiler/assembler** determines instruction count and mix
- The **OS** manages resources

The compilation flow goes:

> High-level C → Compiler → Assembly (e.g., MIPS) → Assembler → Binary machine code

---

## 7. Two Key Performance Metrics

- **Response time (latency):** Time from start to completion of a task.
- **Throughput (bandwidth):** Number of operations completed per unit time.

A faster single processor improves response time. More processors improve throughput, but response time improvement depends on how parallelizable the work is.

---

## 8. Measuring Performance

- **Wall-clock time:** Total elapsed time (CPU + I/O + OS overhead — everything).
- **CPU time:** Only processor time spent on the task, split into *user CPU time* (your program) and *system CPU time* (OS on your behalf).

---

## 9. CPU Clocking

Clock period *T* = 1/*f*, where *f* is clock rate in Hz.

### The CPU Time Equation

```
CPU time = Clock cycles × T = Clock cycles / f
```

To improve: decrease cycles ↓ or increase clock rate ↑.

**Example:** Computer A has *f_A* = 2 GHz, CPU time = 10 s → 20 billion cycles. Computer B runs in 6 s but needs 1.2× more cycles (24 billion). So *f_B* = 24×10⁹ / 6 = **4 GHz**.

---

## 10. The Complete Performance Equation

```
CPU time = Instruction Count (IC) × CPI × T
```

| Factor | Influenced by |
|---|---|
| IC (instruction count) | Algorithm, compiler, ISA |
| CPI (cycles per instruction) | ISA, microarchitecture |
| T (clock period) | Microarchitecture, process technology |

**Example:** Same ISA — Machine A (*T*=250ps, CPI=2) → CPU time = IC × 500ps. Machine B (*T*=500ps, CPI=1.2) → CPU time = IC × 600ps. A is **1.2× faster**.

---

## 11. Weighted CPI (Instruction Mix)

When different instruction classes have different CPIs:

```
Total cycles = Σ (CPI_i × IC_i)
Average CPI  = Total cycles / Total IC
```

**Example** with classes A (CPI=1), B (CPI=2), C (CPI=3):

- **Sequence 1** (IC=5): 2+2+6 = 10 cycles, avg CPI = 2.0
- **Sequence 2** (IC=6): 4+2+3 = 9 cycles, avg CPI = 1.5

Sequence 2 has more instructions but fewer total cycles — it's faster.

---

## 12. MIPS as a Metric (and its Pitfalls)

```
MIPS = IC / (Execution time × 10⁶) = f / (CPI × 10⁶)
```

MIPS is misleading because it ignores what work each instruction does. A higher MIPS machine can actually be slower if its instructions accomplish less.

---

## 13. Amdahl's Law

```
Speedup = 1 / [(1 − f_O) + f_O / S_O]
```

Where *f_O* = fraction of execution time that's optimizable, *S_O* = speedup of that portion.

**Maximum speedup** (when *S_O* → ∞): 1 / (1 − *f_O*)

| f_O | Max Speedup |
|---|---|
| 0.5 | 2× |
| 0.75 | 4× |
| 0.9 | ~10× |
| 0.99 | 100× |

**Takeaway:** Even infinite speedup on half the program only gives 2× overall. Always optimize the common case.

---

## 14. Power Consumption

**Total Power = Dynamic + Static**

- **Dynamic power** ∝ C × V² × f (capacitance × voltage² × frequency)
- **Static power** ∝ V × I_leak (proportional to number of transistors/area). Was negligible in early CMOS but now dominant because V_th scaling stopped and leakage has exponential dependence on V_th.

---

## 15. Power — Architect's Perspective

- **Peak power:** Max instantaneous draw; exceeding it causes voltage droops and timing errors.
- **Thermal Design Power (TDP):** Sustained power level that determines cooling. Lower than peak, higher than average.
- **Thermal throttling:** Processors reduce clock speed when temperature limits are hit.
- **Energy efficiency** (Energy = Power × Time) is the right metric for comparing machines, since it captures both speed and power.

---

## 16. Big-Picture Takeaways

- Execution time is the most reliable performance metric — beware MIPS and other proxies.
- Static power means computers consume power even when idle → energy-proportional computing matters.
- Computing is power-limited — we can build more transistors than we can power ("dark silicon").
- Parallelism (multi-core) helps with the power wall, but Amdahl's Law limits its benefit.
- Moore's Law sustainability is an open question.

---

## Quick-Reference Equations

| Equation | Use |
|---|---|
| CPU time = Cycles × T | Basic performance |
| CPU time = IC × CPI × T | Full performance equation |
| Cycles = Σ(CPI_i × IC_i) | Weighted cycle count |
| Speedup = 1/[(1−f_O) + f_O/S_O] | Amdahl's Law |
| P_dyn ∝ C·V²·f | Dynamic power |
| P_static ∝ V·I_leak | Static power |