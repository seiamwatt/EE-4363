# Pipelining III — Study Guide
## EE 4363 / CSci 4203 — Computer Architecture & Machine Organization

---

## 1. Datapath with Forwarding (Review)

The forwarding unit sits in the EX stage and compares source register numbers of the current instruction (from IF/ID) against destination register numbers of instructions in later pipeline stages (EX/MEM and MEM/WB). When a match is found and the producing instruction writes a register, the forwarding unit routes the correct value through muxes at the ALU inputs, bypassing the register file.

**Key signals checked by the forwarding unit:**
- `IF/ID.RegisterRs` and `IF/ID.RegisterRt` — source operands of the consumer
- `EX/MEM.RegisterRd` — destination of the instruction leaving EX
- `MEM/WB.RegisterRd` — destination of the instruction leaving MEM

Forwarding eliminates most data hazard stalls for R-type → R-type dependencies.

---

## 2. Load-Use Data Hazard

### The Problem
A **load instruction** (`lw`) does not have its result available until the end of the MEM stage. If the very next instruction needs that value in EX, forwarding alone cannot help — the data simply doesn't exist yet when the consumer needs it.

### Detection Condition
The hazard detection unit checks at the **ID stage**:

```
if  ID/EX.MemRead == 1
AND (ID/EX.RegisterRt == IF/ID.RegisterRs
  OR ID/EX.RegisterRt == IF/ID.RegisterRt)
→ STALL
```

- `ID/EX.MemRead` identifies a load in EX.
- `ID/EX.RegisterRt` is the load's destination (rt for I-type).
- `IF/ID.RegisterRs` / `IF/ID.RegisterRt` are the consumer's source operands.

### How the Stall Works
1. **Insert a bubble:** Force all control signals in the ID/EX register to 0 (NOP).
2. **Freeze the front end:** Prevent the PC and IF/ID register from updating.
3. After the 1-cycle stall, the load's data emerges from MEM and can be **forwarded** to EX normally.

### Example Sequence
```
lw   $2, 20($1)      # produces $2 at end of MEM
and  $4, $2, $5      # needs $2 in EX — STALL 1 cycle, then forward from MEM/WB
or   $8, $2, $6      # no stall — $2 available via forwarding
add  $9, $4, $2      # no stall
```

---

## 3. Datapath with Hazard Detection

The enhanced datapath adds a **hazard detection unit** in the ID stage. It receives:
- `ID/EX.MemRead` — is there a load in EX?
- `ID/EX.RegisterRt` — the load's destination register
- `IF/ID.RegisterRs`, `IF/ID.RegisterRt` — the current instruction's sources

When a load-use hazard is detected, the unit asserts:
- **IF/IDWrite = 0** (freeze IF/ID latch)
- **PCWrite = 0** (freeze PC)
- **Mux select = 0** on the control-signal mux feeding ID/EX (inject NOP)

---

## 4. Control Hazards

### Data Hazards vs. Control Hazards

| | Data Hazard | Control Hazard |
|---|---|---|
| **Effect on successors** | May be *stalled* | May be *flushed* (squashed) |
| **Effect on predecessors** | May forward data | No impact |
| **Cause** | Register dependency | Branch/jump changes PC |

### Branch Resolution in the Pipeline
In the standard 5-stage MIPS pipeline, the branch decision (taken/not-taken) and target address are resolved at the **end of the ID stage** (using a comparator added to ID). This means:
- The instruction fetched in the cycle after the branch (at PC+4) may be wrong.
- If the branch is **taken**, that instruction must be **flushed** (IF.Flush signal zeroes the IF/ID register).
- The branch penalty is **1 cycle** (one instruction is always fetched before the outcome is known).

### Control Hazard Example Walkthrough
```
36: sub $10, $4, $8
40: beq $1, $3, 7       # branch to address 72 if $1 == $3
44: and $12, $2, $5     # fetched speculatively (wrong path if taken)
48: or  $13, $2, $6     # also fetched speculatively
...
72: lw  $4, 50($7)      # branch target
```
- At clock 3: `beq` is in ID, `and` (addr 44) is being fetched.
- The comparator determines the branch is taken → IF.Flush activates.
- The `and` instruction in IF/ID is squashed (converted to NOP).
- PC is redirected to 72; `lw $4, 50($7)` is fetched next cycle.

---

## 5. Forwarding to ID (Branch Operands)

Because branches are resolved in ID, the branch operands must be available at the **end of ID** — earlier than the usual EX stage. This creates extra hazard scenarios:

### Case I: No Stall
- The producer is an **R-type** instruction at distance **≥ 2** from the branch.
- By the time the branch is in ID, the producer's result is in MEM/WB or later — forwarding works.

### Case II: 1-Cycle Stall
- The producer is an **R-type at distance 1** (immediately before the branch), OR
- The producer is a **load at distance 2**.
- The data isn't ready in time for ID; one stall cycle is needed.

### Case III: 2-Cycle Stall
- The producer is a **load at distance 1** (immediately before the branch).
- The load result isn't available until end of MEM, which is two stages after ID needs it.

---

## 6. Dynamic Branch Prediction

### Why Predict?
- Deeper pipelines → higher branch penalty (more wasted cycles on a misprediction).
- Dynamic prediction uses runtime history to guess branch direction, reducing the effective penalty.

### Branch History Table (BHT)
- Indexed by the **branch instruction's PC** (or a hash of it).
- Each entry stores the **predicted direction** (taken or not taken).
- On a branch: look up the table → fetch from the predicted path → verify later → update the table.

### Two-Bit Saturating Counter
A 1-bit predictor flips on every misprediction, which is bad for branches that are almost always taken but occasionally not (e.g., loop exit). A **2-bit counter** requires **two consecutive mispredictions** to change the prediction.

**States (2-bit):**

| Value | Prediction | Meaning |
|---|---|---|
| 11 | Taken | Strongly taken |
| 10 | Taken | Weakly taken |
| 01 | Not taken | Weakly not taken |
| 00 | Not taken | Strongly not taken |

- **Taken outcome** → increment (saturate at 11)
- **Not-taken outcome** → decrement (saturate at 00)
- MSB determines the prediction.

---

## 7. Branch Target Buffer (BTB)

### Problem
Even if we predict the direction correctly, we still need the **target address** to start fetching from the right place immediately.

### Solution
- A small cache indexed by the **PC of the instruction being fetched**.
- Each entry stores the **target PC** (the address to fetch from if the branch is taken).
- If an entry is found, the instruction is predicted to be a **taken branch**, and fetching begins at the stored target in the **next cycle** → branch delay becomes **0** (if prediction is correct).

### BTB Operation Flow
1. **IF stage:** Send PC to both instruction memory and BTB simultaneously.
2. **Entry found?**
   - Yes → Use the predicted PC as next fetch address.
   - No → Proceed normally (PC+4).
3. **Later verification (ID/EX):**
   - Correct prediction → no penalty, continue.
   - Misprediction (predicted taken but actually not taken) → kill fetched instruction, restart, delete BTB entry.
   - Actual taken branch with no BTB entry → enter the branch address and target into the BTB for next time.

---

## 8. Advanced Branch Prediction Schemes

### Bimodal Prediction
- A table of 2-bit saturating counters indexed by the branch PC.
- Good for branches that are **strongly biased** in one direction.
- Multiple branches may alias to the same entry.

### Local Branch Prediction
- Maintains a **per-branch history register** (n bits recording the last n outcomes of *this specific* branch).
- The history register indexes into a table of 2-bit counters.
- Captures **repetitive patterns** within a single branch (e.g., a loop `for(i=1; i<=4; i++)` produces pattern `1110 1110 ...`).

### Global Branch Prediction
- Uses a single **Global History Register (GR)** that records the outcomes of the last n branches executed (across *all* branches).
- Good when branches are **correlated** with each other.

**Example of correlation:**
```c
if (a == 2) a = 0;    // B1
if (b == 2) b = 0;    // B2
if (a != b) ...       // B3
```
B3's outcome depends on B1 and B2. If both B1 and B2 are not taken (meaning a==2 and b==2, so both get zeroed), then a==b and B3 is taken. A global predictor can learn this correlation.

### gselect
- Index the pattern table by **concatenating** n bits of GR with m bits of PC → (n+m)-bit index.
- Simple but can cause aliasing when different branches with different histories map to the same entry.

### gshare
- Index the pattern table by **XOR-ing** n bits of GR with n bits of PC → n-bit index.
- Better distribution of entries (fewer destructive aliases) than gselect for a given table size.

### gselect vs. gshare Example

| Branch Addr | Global History | gselect (4/4) | gshare (8/8) |
|---|---|---|---|
| 00000000 | 00000001 | 00000001 | 00000001 |
| 00000000 | 00000000 | 00000000 | 00000000 |
| 11111111 | 00000000 | 11110000 | 11111111 |
| 11111111 | 10000000 | 11110000 | 01111111 |

Notice gselect produces a **collision** (rows 3 and 4 both map to `11110000`), while gshare maps them to distinct entries.

### Tournament (Combined) Predictor
- Runs **two predictors** (P1 and P2) in parallel — e.g., a local predictor and a global predictor.
- A **selector table** (array of 2-bit counters indexed by PC) tracks which predictor has been more accurate for each branch.
- Update rule for the selector:
  - Both correct or both wrong → no change.
  - P1 correct, P2 wrong → increment (favor P1).
  - P1 wrong, P2 correct → decrement (favor P2).

---

## 9. Key Takeaways

1. **Load-use hazards** are the one data hazard forwarding can't fully solve — they require a 1-cycle stall plus forwarding from MEM/WB.
2. **Control hazards** cause pipeline flushes, not stalls. Moving branch resolution to ID reduces the penalty to 1 cycle but creates new forwarding-to-ID complications.
3. **Branch prediction** is essential for performance. Two-bit saturating counters tolerate occasional anomalies. The BTB eliminates target-address delay for predicted-taken branches.
4. **Local predictors** capture per-branch patterns; **global predictors** capture inter-branch correlations; **tournament predictors** dynamically select the best of both.
5. **gshare** generally outperforms **gselect** because XOR-based indexing distributes entries more evenly and reduces aliasing.

---

## 10. Key Formulas & Conditions

**Load-use hazard detection:**
```
ID/EX.MemRead
AND (ID/EX.RegisterRt == IF/ID.RegisterRs
  OR ID/EX.RegisterRt == IF/ID.RegisterRt)
```

**EX hazard forwarding (from EX/MEM):**
```
EX/MEM.RegWrite AND EX/MEM.RegisterRd ≠ 0
AND EX/MEM.RegisterRd == ID/EX.RegisterRs (or Rt)
```

**MEM hazard forwarding (from MEM/WB):**
```
MEM/WB.RegWrite AND MEM/WB.RegisterRd ≠ 0
AND NOT (EX/MEM forwards same register)
AND MEM/WB.RegisterRd == ID/EX.RegisterRs (or Rt)
```

---

*Reference: Hennessy & Patterson, Chapter IV (Section IV.VIII); McFarling, "Combining Branch Predictors"*