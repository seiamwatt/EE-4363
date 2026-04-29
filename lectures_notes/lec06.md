# Pipelining-II — Study Guide

*EE 4363 / CSci 4203 — Computer Architecture & Machine Organization (Lecture 6)*

---

## 1. What This Lecture Adds

Lecture 5 introduced the *concept* of pipelining and the three hazards. This lecture goes inside the box: how the **datapath**, **pipeline registers**, **control signals**, and **forwarding unit** are actually wired together to make a pipelined MIPS work in hardware.

---

## 2. The Pipelined MIPS Datapath

The datapath has the same five stages as before — IF, ID, EX, MEM, WB — but stages are now physically separated by **pipeline registers** named after the boundary they sit on:

| Pipeline Register | Sits Between | Carries |
|-------------------|--------------|---------|
| **IF/ID** | IF → ID | Fetched instruction, PC+4 |
| **ID/EX** | ID → EX | Register values, sign-extended immediate, control signals |
| **EX/MEM** | EX → MEM | ALU result, store data, destination register |
| **MEM/WB** | MEM → WB | Loaded data, ALU result, destination register |

**Why pipeline registers matter:** every stage operates on a *different* instruction in the same cycle. Without these latches, signals from one instruction would corrupt another. The latches hold each instruction's state at the stage boundary so the next stage can pick it up cleanly on the next clock edge.

### What Each Stage Does

- **IF** — PC indexes instruction memory; PC+4 (or branch target) is computed; instruction and PC+4 latch into IF/ID.
- **ID** — Instruction is decoded; register file is read; immediate is sign-extended. Everything needed downstream lands in ID/EX.
- **EX** — ALU performs the operation (or computes an effective address for loads/stores); branch target is computed in parallel.
- **MEM** — Data memory is accessed for loads (read) and stores (write). For ALU instructions, this stage just passes the result through.
- **WB** — The final result is written back to the register file.

---

## 3. Tracking an Instruction Through the Pipeline

Walking a `lw` (load word) through every stage:

| Stage | What `lw` Does |
|-------|----------------|
| **IF** | Fetch the `lw` instruction from memory |
| **ID** | Decode; read base register from regfile; sign-extend the offset |
| **EX** | ALU adds base + offset to compute the memory address |
| **MEM** | Read data memory at the computed address |
| **WB** | Write the loaded value into the destination register |

For a `sw` (store word), the first three stages are nearly identical, but in **MEM** the data memory is *written* (not read), and **WB does nothing** — there is no register destination for a store.

### The Bug & The Fix: Carrying the Destination Register

A subtle but important point: the register *number* to write to (the destination Rd or Rt) is decoded in ID — but the actual write happens in WB, four stages later. If we don't *carry the destination register number along the pipeline*, by the time WB happens, the register file is decoding a different (later) instruction's bits.

**Fix:** the destination register number is latched into ID/EX, then EX/MEM, then MEM/WB. The "Corrected Datapath for Load" slide highlights exactly this added wire.

---

## 4. Single-Cycle vs. Multi-Cycle Pipeline Diagrams

Two ways instructors draw the same pipeline:

- **Multi-cycle diagram** — Time runs left to right; each instruction is a row showing which stage it's in each cycle. Good for *seeing hazards* and overlap.
- **Single-cycle diagram** — A snapshot of the datapath at one instant, showing which instruction occupies each stage. Good for *seeing the hardware*.

Both views describe the same execution; pick whichever exposes what you need.

---

## 5. Fixed-Field Decoding (Why MIPS Is Easy to Pipeline)

MIPS's regular instruction formats let the ID stage decode and read registers in a single cycle without knowing yet what kind of instruction it is.

| Format | [31:26] opcode | [25:21] | [20:16] | [15:11] | [10:6] | [5:0] |
|--------|----------------|---------|---------|---------|--------|-------|
| **R-type** | 0 | rs | rt | rd | shamt | funct |
| **Load/Store** | 35 or 43 | rs | rt | address (16 bits) | | |
| **Branch** | 4 | rs | rt | address (16 bits) | | |

The key observation: `rs` and `rt` are *always* in the same bit positions. So the regfile can speculatively read them every cycle — even before we know whether they'll actually be used. If the instruction turns out not to need them, the values are just discarded.

| Field | Always Used For |
|-------|-----------------|
| opcode | Identifies the instruction type |
| rs | Always read |
| rt | Read (except for the load destination) |
| rd | Written for R-type (also load uses rt as destination) |
| address (16-bit) | Sign-extended and added (for load/store/branch) |

---

## 6. Pipelined Control Signals

In a single-cycle CPU, control signals come straight from the decode logic and feed every part of the datapath simultaneously. In a pipelined CPU, **the control signals must travel with their instruction down the pipe**, so each one arrives at the right stage at the right time.

### Control Signals by Stage

| Stage | Control Signals |
|-------|-----------------|
| **EX** | `ALUSrc`, `ALUOp`, `RegDst` |
| **MEM** | `Branch`, `MemRead`, `MemWrite` |
| **WB** | `RegWrite`, `MemtoReg` |

### How They Travel

Decode generates *all* control signals in ID. They're packaged into the ID/EX register. Each downstream stage extracts the signals it needs and forwards the rest to the next pipeline register:

```
Control (in ID) → [EX, MEM, WB bundle] → ID/EX
                  [    MEM, WB bundle] → EX/MEM
                  [         WB bundle] → MEM/WB
```

This is why the pipeline-control diagram shows shrinking rectangles of control bits as you move right — each stage strips off the ones it consumes.

### Key Signals Explained

| Signal | Purpose |
|--------|---------|
| `RegDst` | Selects rd vs. rt as the destination register (R-type vs. load) |
| `ALUSrc` | Selects register vs. sign-extended immediate as ALU input B |
| `ALUOp` | Encodes which ALU operation (combined with funct in EX) |
| `Branch` | This instruction *might* branch — combined with Zero to set PCSrc |
| `MemRead` | Read data memory (loads) |
| `MemWrite` | Write data memory (stores) |
| `MemtoReg` | Selects memory output vs. ALU result as the value to write back |
| `RegWrite` | Enables register file write in WB |
| `PCSrc` | Selects PC+4 vs. branch target — driven by `Branch AND Zero` |

---

## 7. Detecting Data Dependencies

The classic example sequence:

```mips
sub  $2, $1, $3        # producer: writes $2
and  $12, $2, $5       # consumer (1 cycle later): reads $2
or   $13, $6, $2       # consumer (2 cycles later): reads $2
add  $14, $2, $2       # consumer (3 cycles later): reads $2 (twice!)
sw   $15, 100($2)      # consumer (4 cycles later): reads $2
```

Tracing register `$2` over 9 cycles, it changes from `10` to `–20` mid-execution. Without intervention, only the last two consumers read the new value through the register file.

### How to Detect a Dependency

- Data dependencies are carried *through registers*
- Compare the **destination register** of an in-flight producer with the **source registers** of a consumer in ID/EX
- This requires passing register numbers along the pipeline — not just values

### The Two Forwarding Cases

**Forward from EX/MEM** (producer is exactly 1 cycle ahead — in MEM):
```
EX/MEM.RegRd == ID/EX.RegRs   →  forward to ALU input A
EX/MEM.RegRd == ID/EX.RegRt   →  forward to ALU input B
```

**Forward from MEM/WB** (producer is 2 cycles ahead — in WB):
```
MEM/WB.RegRd == ID/EX.RegRs   →  forward to ALU input A
MEM/WB.RegRd == ID/EX.RegRt   →  forward to ALU input B
```

> **Dependency checks control forwarding decisions.** The forwarding unit watches the pipeline registers each cycle and decides whether to use a forwarded value or the regfile read.

---

## 8. When *Not* to Forward

Forwarding is only valid when the upstream instruction will actually produce a result we care about. Two guard conditions:

1. **The upstream instruction must be writing a register.** Check `EX/MEM.RegWrite` or `MEM/WB.RegWrite`. (A store, for example, doesn't write any register — forwarding from it would be nonsense.)
2. **The destination register must not be `$zero`.** Writes to `$zero` are discarded anyway — `EX/MEM.RegisterRd ≠ 0` and `MEM/WB.RegisterRd ≠ 0`.

Both conditions are bundled into the full forwarding rules below.

---

## 9. Full Forwarding Conditions

The forwarding unit drives two 2-bit muxes — `ForwardA` (ALU input 1) and `ForwardB` (ALU input 2):

| Code | Source |
|------|--------|
| `00` | Use the value read from the regfile (default) |
| `10` | Forward from EX/MEM |
| `01` | Forward from MEM/WB |

### Forward from EX (1-cycle distance)

```
if (EX/MEM.RegWrite
    and (EX/MEM.RegisterRd ≠ 0)
    and (EX/MEM.RegisterRd == ID/EX.RegisterRs))
    ForwardA = 10

if (EX/MEM.RegWrite
    and (EX/MEM.RegisterRd ≠ 0)
    and (EX/MEM.RegisterRd == ID/EX.RegisterRt))
    ForwardB = 10
```

### Forward from MEM (2-cycle distance)

```
if (MEM/WB.RegWrite
    and (MEM/WB.RegisterRd ≠ 0)
    and (MEM/WB.RegisterRd == ID/EX.RegisterRs))
    ForwardA = 01

if (MEM/WB.RegWrite
    and (MEM/WB.RegisterRd ≠ 0)
    and (MEM/WB.RegisterRd == ID/EX.RegisterRt))
    ForwardB = 01
```

---

## 10. The Double Data Hazard (and Why MEM Forwarding Needs a Tweak)

Consider a chain that writes the *same* register repeatedly:

```mips
add  $1, $1, $2        # producer 1
add  $1, $1, $3        # producer 2 — also writes $1
add  $1, $1, $4        # consumer — wants the most recent $1
```

When the third `add` reaches EX:
- Both producer 1 (now in MEM/WB) and producer 2 (now in EX/MEM) want to forward their `$1` to it.
- We need the **most recent** value — the one from EX/MEM, not MEM/WB.

**Fix:** the MEM-forwarding rule must include a *negation*: only forward from MEM/WB if no EX/MEM forward is available for the same register.

### Revised MEM Forwarding Condition

```
if (MEM/WB.RegWrite
    and (MEM/WB.RegisterRd ≠ 0)
    and NOT (EX/MEM.RegWrite
             and (EX/MEM.RegisterRd ≠ 0)
             and (EX/MEM.RegisterRd == ID/EX.RegisterRs))
    and (MEM/WB.RegisterRd == ID/EX.RegisterRs))
    ForwardA = 01
```

(And the symmetric rule for `ForwardB` using RegisterRt.)

In plain English: forward from MEM/WB **only if the EX/MEM stage isn't already overriding it for the same source register**.

---

## 11. The Forwarding Unit — Hardware View

Inputs to the forwarding unit:
- `ID/EX.RegisterRs`, `ID/EX.RegisterRt` — source registers of the instruction in EX
- `EX/MEM.RegisterRd`, `EX/MEM.RegWrite` — destination/write-enable of the instruction in MEM
- `MEM/WB.RegisterRd`, `MEM/WB.RegWrite` — destination/write-enable of the instruction in WB

Outputs:
- `ForwardA`, `ForwardB` — 2-bit signals controlling the ALU input muxes

Each ALU input is now a 3-way mux:
- Regfile read (no forward)
- EX/MEM ALU result (1-cycle-old result)
- MEM/WB final value (2-cycle-old result)

This is purely combinational logic — it adds wire and mux delay to the EX stage but **no extra cycles**.

---

## 12. What Forwarding Doesn't Solve

Forwarding handles every ALU-to-ALU dependency cleanly. The case it **can't** solve is the **load-use hazard** (covered in Lecture 5): a load's data isn't ready until the *end* of MEM, but the consumer needs it at the *start* of its EX. Forwarding can't go backward in time, so one stall is unavoidable — that requires a **hazard detection unit** (a separate piece of logic, distinct from the forwarding unit).

---

## 13. Quick-Reference Cheat Sheet

| Concept | One-Line Answer |
|---------|----------------|
| What separates pipeline stages? | Pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB) |
| How do control signals reach the right stage? | Generated in ID, latched and passed forward each cycle |
| Why does MIPS make ID easy? | Fixed-field encoding — rs/rt always in the same bit positions |
| How are dependencies detected? | Compare destination Rd of upstream stages to Rs/Rt of ID/EX |
| Forward from EX/MEM means? | Producer is 1 instruction ahead (currently in MEM) |
| Forward from MEM/WB means? | Producer is 2 instructions ahead (currently in WB) |
| Why guard with RegWrite and Rd ≠ 0? | Don't forward from non-writers or from `$zero` |
| What's the double data hazard? | Two recent producers of the same register — must pick EX/MEM |
| Where forwarding fails? | Load-use hazard — needs a stall instead |

---

## 14. Common Exam Pitfalls

- **Mixing up RegRd vs. RegRt vs. RegRs** — Rd is the *destination*, Rs and Rt are *sources*. Forwarding compares an upstream Rd to a downstream Rs or Rt.
- **Forgetting the RegWrite guard** — A store has no destination register; checking only Rd values would falsely match and forward garbage.
- **Forgetting `$zero`** — Writes to `$0` are silently dropped; a stale forward from a `$0`-destination would still match by register number.
- **Picking MEM/WB over EX/MEM in a double hazard** — EX/MEM is more recent and must win.
- **Treating control signals like single-cycle** — In a pipelined CPU, every control signal must be latched into pipeline registers and travel with its instruction; otherwise it controls the *wrong* instruction.
- **Confusing forwarding with hazard detection** — forwarding handles most dependencies with no stalls; the hazard detection unit handles the load-use case by inserting a bubble.

---

## 15. Reference

Hennessy & Patterson, *Computer Organization and Design*, Chapter IV (especially §IV.VI).