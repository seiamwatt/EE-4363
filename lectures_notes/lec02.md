# EE 4363 / CSci 4203 — Lecture 2 Study Guide
## How to Quantify "Better"?

---

## 1. Technology Scaling (Dennard '74)

Each technology generation (every 2–3 years), transistor parameters scale by a factor **κ**:

| Parameter | Scaling Factor |
|---|---|
| Supply voltage (V_dd) | 1/κ |
| Threshold voltage (V_th) | 1/κ |
| Capacitance (C) | 1/κ |
| Current (I) | 1/κ |
| Area (same functionality) | 1/κ² |
| Transistor delay (C·V/I) | 1/κ |
| Power dissipation (V·I) | 1/κ² |
| **Power density** | **1 (constant)** |

**Key insight — two ways to use scaling:**

- **Constant functionality:** Same number of switches → area shrinks by 1/κ², power shrinks by 1/κ². *Same work, less area, less power.*
- **Constant area:** Fit κ² more switches → power stays constant (κ² × 1/κ² = 1). *More work at the same power budget.*

---

## 2. Classes of Computers

| Class | Characteristics |
|---|---|
| **Desktop** | General-purpose, performance-critical |
| **Server** | Networked, optimized for reliability + high capacity |
| **Embedded** | Often special-purpose, tight power & performance constraints |

---

## 3. Understanding Performance

Performance depends on every layer of the stack:

- **Algorithm** → determines instruction count
- **Compiler / Assembler** → translates high-level code to machine instructions
- **ISA (Architecture)** → defines the instruction set
- **Microarchitecture / Organization** → determines CPI
- **Hardware / Technology** → determines clock period

---

## 4. Performance Metrics

### Response Time (Latency)
Time from start to completion of a task.

### Throughput (Bandwidth)
Number of operations completed per unit time.

> A faster processor improves **response time**. More processors can improve **throughput** — but only if the work is parallelizable.

### Wall Clock Time vs. CPU Time
- **Wall clock time** — total elapsed time including I/O, OS overhead, etc.
- **CPU time** — time the processor spends on *your* task (user + system)

---

## 5. The CPU Performance Equation

### Core Formula

$$\text{CPU time} = \text{Clock Cycles} \times \text{Clock Period} = \frac{\text{Clock Cycles}}{\text{Clock Rate}}$$

### Expanding Clock Cycles

$$\text{Clock Cycles} = \text{Instruction Count} \times \text{CPI}$$

### The Full Equation

$$\boxed{\text{CPU time} = \text{Instruction Count} \times \text{CPI} \times \text{Clock Period}}$$

| Factor | What affects it |
|---|---|
| **Instruction Count** | Algorithm, compiler, ISA |
| **CPI** (Cycles Per Instruction) | ISA, microarchitecture |
| **Clock Period** (1/frequency) | Hardware technology, organization |

### Weighted CPI (multiple instruction classes)

$$\text{Clock Cycles} = \sum_{i=1}^{N} \text{CPI}_i \times \text{IC}_i$$

$$\text{Average CPI} = \frac{\text{Total Cycles}}{\text{Total Instructions}}$$

---

## 6. Worked Examples

### Example 1 — Clock Rate

- Computer A: f_A = 2 GHz, CPU time = 10 s
- Computer B: CPU time = 6 s, but requires 1.2× more clock cycles

**Solution:**
- Cycles_A = f_A × time_A = 2 × 10⁹ × 10 = 20 × 10⁹
- Cycles_B = 1.2 × Cycles_A = 24 × 10⁹
- f_B = Cycles_B / time_B = 24 × 10⁹ / 6 = **4 GHz**

### Example 2 — Comparing CPI and Clock Period

- Computer A: T = 250 ps, CPI = 2
- Computer B: T = 500 ps, CPI = 1.2 (same ISA → same instruction count)

**Solution:**
- CPU time_A = IC × 2 × 250 = 500 × IC ps
- CPU time_B = IC × 1.2 × 500 = 600 × IC ps
- **A is faster** (500 < 600)

### Example 3 — Weighted CPI

| Class | CPI | IC (Seq 1) | IC (Seq 2) |
|---|---|---|---|
| A | 1 | 2 | 4 |
| B | 2 | 1 | 1 |
| C | 3 | 2 | 1 |

- **Seq 1:** Cycles = 1×2 + 2×1 + 3×2 = 10, IC = 5, Avg CPI = 2.0
- **Seq 2:** Cycles = 1×4 + 2×1 + 3×1 = 9, IC = 6, Avg CPI = 1.5
- Seq 2 has fewer cycles → faster despite more instructions

---

## 7. MIPS as a Metric

$$\text{MIPS} = \frac{\text{Instruction Count}}{\text{Execution Time} \times 10^6} = \frac{\text{Clock Rate}}{\text{CPI} \times 10^6}$$

**Caution:** MIPS can be misleading — it doesn't account for the *work* each instruction does. Different ISAs may need different instruction counts for the same task.

---

## 8. Amdahl's Law

If only a fraction of a program can be optimized:

$$\text{Speedup} = \frac{1}{(1 - f_O) + \frac{f_O}{S_O}}$$

Where:
- **f_O** = fraction of execution time that *can* be optimized
- **S_O** = speedup of the optimized portion

### Maximum Speedup (S_O → ∞)

$$\text{Speedup}_{\max} = \frac{1}{1 - f_O}$$

| f_O | Max Speedup |
|---|---|
| 0.50 | 2× |
| 0.75 | 4× |
| 0.90 | 10× |
| 0.99 | 100× |

**Takeaway:** The unoptimizable portion dominates. Even with infinite speedup on 50% of the code, you can never exceed 2× overall.

---

## 9. Power Consumption

### Total Power = Dynamic + Static

**Dynamic Power:**

$$P_{\text{dynamic}} \propto C \times V^2 \times f$$

- C = capacitance (proportional to number of switches)
- V = supply voltage
- f = clock frequency

**Static Power:**
- Proportional to V × I (leakage current)
- Proportional to chip area / number of transistors
- Was negligible in early CMOS; now significant
- Depends exponentially on threshold voltage V_th
- V_th scaling has stalled → voltage scaling stagnating

### Architect's Power Concerns

| Concept | Meaning |
|---|---|
| **Peak Power** | Max instantaneous draw; exceeding it causes voltage drops / timing errors |
| **Thermal Design Power (TDP)** | Sustained power that determines cooling requirements |
| **Energy Efficiency** | Energy per task = Power × Execution Time |

---

## 10. Key Takeaways

1. **Execution time is the most reliable performance metric** — always prefer it over MIPS.
2. **The CPU performance equation** ties together instruction count, CPI, and clock period — improving one may worsen another.
3. **Amdahl's Law** sets a hard ceiling on speedup based on the serial fraction.
4. **Power is the primary constraint** in modern computing — Dennard scaling has ended, making power density a limiting factor.
5. **Dark silicon** — chips have more transistors than can be simultaneously powered, motivating energy-efficient and parallel architectures.

---

*Reference: Hennessy & Patterson, Chapter 1 (Sections 1.1, 1.2, 1.4, 1.5, 1.6, 1.8, 1.9)*