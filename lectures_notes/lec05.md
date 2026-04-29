# Pipelining — Study Guide

*EE 4363 / CSci 4203 — Computer Architecture & Machine Organization (Lecture 5)*

---

## 1. The Big Picture: Speed Daemon vs. Brainiac

Two competing philosophies for making processors faster:

| Camp | Strategy | Goal |
|------|----------|------|
| **Speed Daemon** | Simpler hardware, faster clock | Decrease clock period |
| **Brainiac** | Complex hardware, more work per cycle | Decrease CPI |

Performance equation reminder:

```
Execution Time = Instructions × CPI × Clock Period
```

**Pipelining** is the technique that lets us push on *both* knobs at once — it shortens the clock period (each stage does less work) while keeping CPI close to 1 in the ideal case.

> The terms come from a 1990s *Microprocessor Report* editorial. The "complexity-effective" goal is to capture most of the brainiac's IPC benefits while keeping the speed-daemon's fast clock.

---

## 2. Pipelining Intuition — The Laundry Analogy

Doing 4 loads of laundry, each requiring wash → dry → fold → put away:

- **Sequential:** 8 hours total (each load fully completes before the next starts)
- **Pipelined:** 3.5 hours total (loads overlap — while one is drying, the next is washing)
- **Speedup:** 8 / 3.5 ≈ **2.3×** for 4 loads
- **Asymptotic speedup** (non-stop pipeline): approaches the **number of stages** (≈ 4)

**Key insight:** Pipelining improves *throughput*, not the latency of any single task.

---

## 3. The MIPS 5-Stage Pipeline

| # | Stage | Meaning |
|---|-------|---------|
| 1 | **IF** | Instruction Fetch from memory |
| 2 | **ID** | Instruction Decode & register read |
| 3 | **EX** | Execute operation OR calculate address |
| 4 | **MEM** | Access memory operand |
| 5 | **WB** | Write Back result to register |

### Worked Example: Single-Cycle vs. Pipelined Clock Period

Stage delays:
- 200 ps for IF, EX, MEM
- 100 ps for register read/write

| Instruction | IF | Reg Read | ALU | MEM | Reg Write | **Total** |
|-------------|-----|----------|-----|-----|-----------|-----------|
| `lw`        | 200 | 100      | 200 | 200 | 100       | **800 ps** |
| `sw`        | 200 | 100      | 200 | 200 | —         | **700 ps** |
| R-format    | 200 | 100      | 200 | —   | 100       | **600 ps** |
| `beq`       | 200 | 100      | 200 | —   | —         | **500 ps** |

- **Single-cycle** clock period = 800 ps (must accommodate the slowest instruction)
- **Pipelined** clock period = 200 ps (the slowest *stage* — register stages get padded)

---

## 4. Pipeline Speedup — Conditions for Maximum Benefit

Speedup is maximized when:

1. **All stages are balanced** (equal latency) — otherwise the slowest stage sets the clock
2. **The pipeline stays full** — enough independent work to feed it every cycle
3. **No hazards** stall execution

In the ideal case, throughput improves by a factor equal to the number of stages.

---

## 5. ISA Design for Pipelining

MIPS was deliberately designed to make pipelining easy:

| MIPS Feature | Why It Helps Pipelining |
|--------------|-------------------------|
| All instructions are 32 bits | Easy to fetch & decode in one cycle |
| Few, regular instruction formats | Decode + register read in one step |
| Load/store addressing only | Address calc in EX, memory in MEM |
| Aligned memory operands | Memory access takes one step |

**Contrast with x86:** instructions are 1–17 bytes long, making fetch and decode much harder to pipeline cleanly.

---

## 6. Hazards — The Three Things That Break the Pipeline

A **hazard** prevents the next instruction from starting in the next cycle.

### 6.1 Structural Hazards

A required hardware resource is busy.

**Classic example:** A pipeline with a single, single-ported memory. In one cycle, one instruction needs IF (instruction fetch) while another needs MEM (data access). They collide → IF must stall → **pipeline bubble**.

**Fix:** Duplicate the resource. Real MIPS implementations have separate instruction and data caches (Harvard-style L1).

### 6.2 Data Hazards

An instruction needs a value a previous instruction hasn't finished producing yet.

```mips
add  $s0, $t0, $t1     # writes $s0
sub  $t2, $s0, $t3     # reads $s0  ← depends on add!
```

Without intervention, the `sub` would have to wait until `add` reaches WB before it can read `$s0` from the register file — that's roughly 3 cycles of bubbles.

#### Solution A: Forwarding (a.k.a. Bypassing)

Use the result *as soon as it is computed*, without waiting for WB. The ALU output of `add` (end of EX) is routed directly into the ALU input of `sub` (start of its EX) via extra wires.

- **Cost:** extra muxes and wires in the datapath, plus hazard-detection logic
- **Benefit:** zero stalls for most ALU-to-ALU dependencies

#### Solution B: Stalls (when forwarding isn't enough)

Some hazards can't be fixed by forwarding alone — see load-use below.

### 6.3 The Load-Use Hazard (Special Case)

```mips
lw   $s0, 20($t1)      # value available at end of MEM
sub  $t2, $s0, $t3     # needs $s0 at start of EX
```

The load doesn't have its value until the **end of MEM**, but the `sub` needs it at the **start of EX** — which would be one cycle *earlier*. **You can't forward backward in time**, so one stall is unavoidable.

> Forwarding hides the stalls; the load-use hazard is the one place a single stall remains.

#### Compiler Solution: Code Scheduling

Reorder independent instructions to fill the slot after a load. For `A = B + E; C = B + F;`:

**Original (with stalls):**
```mips
lw   $t1, 0($t0)
lw   $t2, 4($t0)
add  $t3, $t1, $t2     # ← stall (uses $t2 right after lw)
sw   $t3, 12($t0)
lw   $t4, 8($t0)
add  $t5, $t1, $t4     # ← stall (uses $t4 right after lw)
sw   $t5, 16($t0)
```
Total: **n cycles** (with 2 stalls)

**Reordered (no stalls):**
```mips
lw   $t1, 0($t0)
lw   $t2, 4($t0)
lw   $t4, 8($t0)       # moved up — fills the slot
add  $t3, $t1, $t2     # $t2 ready by now (lw finished a cycle ago)
sw   $t3, 12($t0)
add  $t5, $t1, $t4     # $t4 ready
sw   $t5, 16($t0)
```
Total: **n − 2 cycles**

### 6.4 Control Hazards

The next PC depends on a branch outcome we haven't computed yet.

```mips
beq  $1, $2, 40        # is the branch taken?
???                    # what do we fetch next?
```

While the branch is still in ID/EX, the pipeline doesn't know whether to fetch the fall-through instruction or the branch target.

#### Mitigation Options

| Strategy | What It Does | Cost / Trade-off |
|----------|--------------|------------------|
| **Stall** | Wait until branch resolves | Loses cycles every branch |
| **Resolve early** | Add hardware to compare registers + compute target in ID | More complex ID stage |
| **Predict not-taken** | Fetch the next sequential instruction; squash if wrong | Free when correct, penalty when wrong |
| **Static prediction** | Backward branches → taken (loops); forward → not taken | Simple, decent accuracy |
| **Dynamic prediction** | Hardware tracks per-branch history | Best accuracy, most hardware |

#### Predict Not-Taken Example

- **Prediction correct** → no penalty, pipeline keeps flowing
- **Prediction wrong** → must squash the wrongly-fetched instructions and refetch from the branch target → bubbles equal to the branch resolution depth

---

## 7. Branch Prediction Deep Dive

### Static Prediction
Decision baked in at compile time, based on typical patterns:
- **Backward branch → predict taken** (likely a loop)
- **Forward branch → predict not taken** (likely an `if` exit)

### Dynamic Prediction
Hardware records the recent history of each branch and assumes the trend continues:
- Maintain a small table indexed by branch PC
- Track outcomes (taken / not-taken) over recent executions
- On misprediction: flush wrongly-fetched instructions, update history, refetch

**Why it matters more in deeper pipelines:** the misprediction penalty grows with pipeline depth, so accurate prediction becomes critical.

---

## 8. Quick-Reference Cheat Sheet

| Concept | One-Line Answer |
|---------|----------------|
| What does pipelining improve? | Throughput (not single-instruction latency) |
| Ideal speedup? | Number of pipeline stages |
| Pipelined clock period? | Determined by the slowest stage |
| Structural hazard fix? | Duplicate the contended resource |
| Data hazard fix? | Forwarding / bypassing |
| Load-use hazard fix? | One stall (or compiler reordering) |
| Control hazard fixes? | Stall, early resolution, prediction |
| Why MIPS is pipeline-friendly? | Fixed 32-bit width, regular formats, aligned memory |

---

## 9. Common Exam Pitfalls

- **Latency vs. throughput** — pipelining doesn't make a single instruction faster; it lets more instructions complete per unit time.
- **Clock period after pipelining** — set by the *slowest stage*, not the average. Unbalanced stages hurt.
- **Forwarding has limits** — load-use is the canonical case where forwarding alone can't eliminate the stall.
- **"Predict not-taken" isn't free** — it's free *only when the prediction is correct*. Mispredictions still cost a full flush.
- **Bubble counting** — when a hazard inserts a stall, every instruction behind it shifts by that many cycles.

---

## 10. Reference

Hennessy & Patterson, *Computer Organization and Design*, Chapter IV (especially §IV.V).