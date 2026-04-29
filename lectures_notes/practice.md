# Pipelining Practice Exam — With Answers

*EE 4363 / CSci 4203 — Computer Architecture & Machine Organization (Lectures 5–7)*

---

## Section 1: Datapath & Control (Single-Cycle)

### Q1. Store Word Datapath Trace

Trace the complete datapath for a `sw` instruction. List every component activated, every control signal value, and identify which muxes are set to which input. Which parts of the datapath are idle during `sw`?

**Answer:**

The `sw` instruction path proceeds as follows. The **PC** sends its value to **Instruction Memory**, which outputs the instruction. The instruction's `rs` field (bits [25:21]) goes to Read Register 1, and `rt` (bits [20:16]) goes to Read Register 2 on the **Register File**. Read Data 1 (the base address) goes to ALU input A. The 16-bit immediate (bits [15:0]) passes through the **Sign Extend** unit, and the **ALUSrc mux** selects this extended immediate (ALUSrc = 1) as ALU input B. The **ALU** performs addition (ALUOp = 00) to compute the effective address (base + offset). The ALU result goes to the **Data Memory** address input. Read Data 2 from the register file provides the data to be stored, routed to the Write Data input of Data Memory. **MemWrite = 1** enables the write.

Control signal values: RegDst = X (don't care), ALUSrc = 1, MemtoReg = X, RegWrite = 0, MemRead = 0, MemWrite = 1, Branch = 0, ALUOp = 00.

**Idle components:** The **WB path** is entirely idle — MemtoReg mux output is unused, and RegWrite = 0 so nothing is written back to the register file. The RegDst mux is also idle since there's no write-back destination to select. The branch adder and PCSrc AND gate produce no useful result (Branch = 0).

---

### Q2. Unified Memory

The single-cycle datapath uses two separate memory units (instruction memory and data memory). A classmate proposes combining them into one memory with a single address port. Explain why this fails in a single-cycle design, and then explain under what type of design it *could* work.

**Answer:**

In a single-cycle design, instruction fetch and data access happen **simultaneously within the same clock cycle**. The PC drives the instruction memory address port while the ALU result drives the data memory address port — both at the same time. A unified single-ported memory can only service one address per cycle, so it cannot handle both an instruction fetch and a load/store data access in the same cycle. This is a **structural hazard**.

This could work in a **multi-cycle design**, where instruction fetch and data access occur in **different clock cycles**. Cycle 1 fetches the instruction from memory, and a later cycle (cycle 4, typically) accesses data memory for loads and stores. Since these happen at different times, a single memory port is sufficient. The original MIPS multi-cycle design by Hennessy and Patterson uses exactly this approach.

---

### Q3. Eliminating the RegDst Mux

The `RegDst` mux selects between `rt` and `rd` as the write destination. A classmate says we could eliminate this mux by always writing to `rd`. For which instruction(s) does this break, and why?

**Answer:**

This breaks **load word (`lw`)** and all other I-type instructions that write to a register. In I-type format, there is no `rd` field — the destination register is encoded in the `rt` field (bits [20:16]). The `rd` field (bits [15:11]) is part of the immediate/offset, so writing to "rd" would write to whatever register number happens to appear in bits [15:11] of the immediate — a completely wrong destination.

For example, `lw $t0, 8($sp)` should write to `$t0` (encoded in `rt`), but bits [15:11] of the offset `8` (binary `0000000000001000`) would yield register `$1` (`$at`) — corrupting the wrong register entirely.

---

### Q4. MemtoReg Mux

What are the two inputs of the `MemtoReg` mux, and for which instruction types is each input selected? What would go wrong if this signal were stuck at 1?

**Answer:**

The two inputs are the **ALU result** (selected when MemtoReg = 0) and the **Data Memory read output** (selected when MemtoReg = 1).

- **MemtoReg = 0:** Used by R-type instructions (add, sub, and, or, slt, etc.). The ALU computes the result and it goes directly to the register file's Write Data input.
- **MemtoReg = 1:** Used by `lw`. The data read from memory is what gets written to the register file.

If MemtoReg were **stuck at 1**, every instruction that writes a register would write the **Data Memory output** instead of the ALU result. R-type instructions like `add $t0, $t1, $t2` would write garbage (whatever Data Memory happens to output at the ALU's computed "address") into `$t0` instead of the sum. Only `lw` would work correctly. The processor would be fundamentally broken for all arithmetic and logic operations.

---

### Q5. ALU Control for Branches

The ALU receives a control input derived from `ALUOp` and the `funct` field. Suppose `ALUOp` is 2 bits. For a `beq` instruction, what ALU operation must be performed, and how does the controller determine this without looking at `funct`?

**Answer:**

For `beq`, the ALU must perform **subtraction**. The branch is taken if the two register values are equal, which is detected by subtracting them and checking if the result is zero (the ALU's Zero output flag).

The controller determines this through the **ALUOp encoding**. With 2-bit ALUOp:

- `ALUOp = 00` → add (used by lw/sw for address calculation)
- `ALUOp = 01` → subtract (used by beq for comparison)
- `ALUOp = 10` → determined by funct field (used by R-type)

When ALUOp = 01 (the branch case), the ALU control logic directly outputs the subtract control code **without consulting the funct field at all**. The funct field is only examined when ALUOp = 10, meaning the main control unit has already identified the instruction as R-type. This two-level decoding scheme keeps the main controller simple — it only needs to distinguish loads/stores, branches, and R-type, and delegates the R-type sub-decoding to the ALU control unit.

---

### Q6. PCSrc and Branch/BNE

Explain why `PCSrc` is computed as `Branch AND Zero` rather than just using `Branch` alone. Then explain what modification you'd need to support `bne` instead of `beq`.

**Answer:**

`Branch` alone only tells us the instruction **is** a branch — it doesn't tell us whether the branch condition is actually **satisfied**. The ALU computes rs − rt and raises the `Zero` flag when they're equal. ANDing `Branch` with `Zero` ensures PCSrc = 1 (select branch target) only when we have a branch instruction **and** the operands are equal. If Branch were used alone, every `beq` would be taken regardless of the register values.

For **`bne`** (branch if not equal), the condition is inverted: we branch when the operands are **not** equal, i.e., when Zero = 0. The modification is:

**PCSrc = Branch AND (NOT Zero)**

This can be implemented by adding an inverter on the Zero line before the AND gate, or by adding a mux controlled by a new 1-bit control signal (call it `BranchNE`) that selects between `Zero` and `NOT Zero`. The second approach is more flexible if you want to support both `beq` and `bne`.

---

### Q7. Sign-Extend Usage

A classmate claims the sign-extend unit is only needed for load/store instructions. Is this correct? List every instruction type in the basic MIPS subset that uses the sign-extended immediate, and explain how each uses it.

**Answer:**

This is **incorrect**. The sign-extend unit is used by three instruction types in the basic subset:

1. **`lw` (load word):** The 16-bit offset is sign-extended and added to the base register to compute the effective memory address. Sign extension is essential because offsets can be negative (e.g., `lw $t0, -4($sp)`).

2. **`sw` (store word):** Identical usage — the sign-extended offset is added to the base register for the store address.

3. **`beq` (branch if equal):** The 16-bit branch offset is sign-extended (and shifted left 2 to make it word-aligned) before being added to PC+4 to compute the branch target address. Sign extension matters because branches can go backward (negative offset for loops).

All three require sign extension because the 16-bit immediate must be expanded to 32 bits to participate in ALU addition, and these offsets are signed values (two's complement). Eliminating sign extension would break backward branches and any load/store with a negative offset.

---

## Section 2: Register File Timing & Ports

### Q8. Simultaneous Read and Write

In a single-cycle design, an R-type instruction reads two registers and writes one register all within the same clock cycle. Explain how the register file handles this without a conflict. Draw a timing diagram showing when reads and writes occur relative to the clock edge.

**Answer:**

The register file avoids conflict through a **split-cycle (edge-based) timing convention**:

- **Writes** occur on the **rising edge** of the clock (or the first half of the cycle). The data to be written must be stable before the edge arrives.
- **Reads** are **combinational** (asynchronous) — as soon as a read register number is applied to the input, the output data appears after the register file's read access time. Reads effectively happen throughout the second half of the cycle.

Timing within one clock period:
```
Rising Edge                                    Next Rising Edge
    |                                                |
    |--- Write occurs here ---|--- Read is valid here ---|
    |   (WB of previous instr)    (ID of current instr)  |
```

For an R-type like `add $t0, $t1, $t2`: Register numbers `$t1` and `$t2` are applied to Read Register 1 and Read Register 2 ports in the decode phase, and their values appear on Read Data 1 and Read Data 2 combinationally. Simultaneously, a **previous** instruction's result may be writing to the register file on the clock edge. Because the write completes at the edge and the read happens after, the newly written value is visible to the reader if they happen to reference the same register (this is the "write-first" or "write-before-read" convention used in MIPS).

---

### Q9. Single Read Port Register File

Suppose the register file is redesigned with only one read port instead of two. Which instructions can still execute correctly with no changes? Which cannot? For the ones that cannot, propose a minimal modification to the datapath.

**Answer:**

**Instructions that still work with one read port:**

- **`lw`:** Reads only one register (the base register `rs`). The second read port output is unused.
- **`sw` (partially):** Needs `rs` (base) for address calculation, but also needs `rt` (data to store) — this actually needs two reads. However, the base address read and the store data read could be sequenced if we add a cycle.
- **`j` (jump):** Reads no registers at all.

**Instructions that break:**

- **R-type (add, sub, and, or, slt):** Need to read both `rs` and `rt` as ALU operands simultaneously.
- **`beq`:** Needs to read both `rs` and `rt` for comparison.
- **`sw`:** Needs `rs` for address and `rt` for store data.

**Minimal modification:** Convert the design from single-cycle to a **multi-cycle design** (or add an extra register-read cycle). In cycle 1, read `rs` and latch the value into a temporary register (call it A). In cycle 2, read `rt` and latch into temporary register B. Then proceed with the ALU operation in a subsequent cycle. This requires adding a temporary register, a mux on the single read port, and a small FSM controller to sequence the two reads. The trade-off is that every two-operand instruction now takes at least one extra cycle, increasing CPI.

---

### Q10. Unused Read Port on Load

A `lw` instruction reads one register (the base) but the register file still receives two read-register inputs. What happens to the second read port's output? Where in the datapath is it guaranteed to be ignored?

**Answer:**

The second read port (Read Register 2, driven by `rt`) still outputs a value — the register file always reads whatever register number appears at its input. For `lw`, the `rt` field actually contains the **destination** register number (where the loaded value will be written), but the register file doesn't know that; it blindly reads register `rt` and outputs its current value on Read Data 2.

This output is **guaranteed to be ignored** at two points:

1. **The ALUSrc mux:** For `lw`, ALUSrc = 1, which selects the sign-extended immediate as ALU input B. Read Data 2 is connected to the "0" input of this mux and is not passed through. The ALU never sees it.

2. **Data Memory Write Data:** Read Data 2 also connects to the Write Data input of Data Memory. However, for `lw`, MemWrite = 0, so Data Memory ignores its Write Data input entirely. No spurious write occurs.

The value is computed but safely discarded by the control signals. This is an example of the "compute but ignore" philosophy that keeps MIPS hardware simple — it's cheaper to let the read happen and discard the result than to add logic preventing the read.

---

## Section 3: Pipeline Registers & Control Signal Propagation

### Q11. Pipeline Register Contents for Store Word

Name all four pipeline registers and state exactly what information each one must carry for a `sw` instruction. Pay special attention to which register value becomes the "write data" for memory and how it travels through the pipeline.

**Answer:**

**IF/ID register carries:**
- The 32-bit `sw` instruction (fetched from instruction memory)
- PC+4 (the incremented program counter)

**ID/EX register carries:**
- Read Data 1 (value of `rs` — the base register)
- Read Data 2 (value of `rt` — the data to be stored)
- Sign-extended 16-bit offset
- Control signals for downstream stages: ALUSrc=1, ALUOp=00, RegDst=X (EX); MemWrite=1, MemRead=0, Branch=0 (MEM); RegWrite=0, MemtoReg=X (WB)

**EX/MEM register carries:**
- ALU result (base + offset = effective memory address)
- Read Data 2 (the store data — this value must be **passed through** the EX stage unchanged, even though the ALU doesn't use it as an operand because ALUSrc selected the immediate instead)
- Control signals: MemWrite=1, MemRead=0, Branch=0 (MEM); RegWrite=0 (WB)

**MEM/WB register carries:**
- Technically latches values but they're irrelevant — RegWrite=0 means nothing is written back. The pipeline register still latches to maintain consistent timing, but WB is a no-op for stores.

**The critical subtlety:** The store data (Read Data 2, the value of `rt`) must travel through ID/EX and then EX/MEM before it reaches the Data Memory's Write Data input in the MEM stage. If this forwarding path is missing, the store would write the wrong data. This is a wire that's easy to overlook in datapath diagrams.

---

### Q12. Destination Register Latching Bug

A student builds a pipelined CPU but forgets to latch the destination register number into the pipeline registers. Instead, the destination is read directly from the IF/ID register during WB. Show a sequence where this causes incorrect behavior.

**Answer:**

Consider this sequence:
```mips
Cycle 1: add $t0, $t1, $t2    # should write $t0
Cycle 2: sub $t3, $t4, $t5    # should write $t3
Cycle 3: and $t6, $t7, $t8    # should write $t6
Cycle 4: or  $t9, $s0, $s1    # should write $t9
Cycle 5: slt $s2, $s3, $s4    # should write $s2
```

When `add` reaches WB in cycle 5, the correct destination is `$t0` (decoded back in cycle 1). But IF/ID now holds the `slt` instruction (fetched in cycle 5), whose `rd` field is `$s2`. The register file would write the `add` result into **`$s2` instead of `$t0`** — a completely wrong register.

Every instruction writes to the destination of whatever instruction happens to be 4 positions later in the program. This silently corrupts the register file, producing incorrect results for every register-writing instruction.

**The fix:** Latch the destination register number into ID/EX, pass it to EX/MEM, then to MEM/WB. In WB, use `MEM/WB.RegisterRd` (the latched value) as the write register address. This ensures each instruction writes to its own destination regardless of what's currently in IF/ID.

---

### Q13. Direct Wires for Control Signals

Control signals are generated in ID but some aren't used until MEM or WB. Explain why we can't just run wires directly from the control unit to the MEM and WB hardware. Illustrate with a concrete 3-instruction sequence.

**Answer:**

In a pipelined CPU, the control unit in ID is decoding a **different instruction every cycle**. If wires ran directly from the control unit to the MEM stage, then the MEM stage would receive control signals for whatever instruction is currently in ID — not the instruction that's actually in MEM.

Consider this sequence at cycle 5:
```
IF:  instruction 5 (being fetched)
ID:  instruction 4 (sw — generates MemWrite=1)
EX:  instruction 3 (add — should have MemWrite=0 in MEM)
MEM: instruction 2 (sub — should have MemWrite=0)
WB:  instruction 1 (lw — should have RegWrite=1, MemtoReg=1)
```

With direct wires, the `sw` in ID generates MemWrite=1, and this signal reaches the MEM stage hardware immediately. But instruction 2 (`sub`) is in MEM — a `sub` should **not** write to data memory. The direct wire causes the `sub` to perform a spurious memory write, corrupting memory with the ALU result of the subtraction.

Similarly, the WB stage would receive RegWrite and MemtoReg from the `sw` in ID (RegWrite=0), so instruction 1 (`lw`) in WB would fail to write its loaded value back to the register file.

**The fix:** Control signals must be **latched into pipeline registers** and travel with their instruction. ID generates all signals, packages them into ID/EX, each stage extracts what it needs and passes the rest forward. This ensures each stage executes with its own instruction's control signals.

---

## Section 4: Data Hazards & Forwarding

### Q14. Dependency Analysis

For the following sequence, identify every data dependency. For each, state whether it's handled by forwarding from EX/MEM, forwarding from MEM/WB, or requires a stall:
```mips
add  $3, $1, $2      # I1
sub  $5, $3, $4      # I2
and  $6, $3, $5      # I3
or   $7, $5, $3      # I4
```

**Answer:**

**Dependencies:**

| Dependency | Producer → Consumer | Distance | Resolution |
|---|---|---|---|
| `$3`: I1 → I2 | add writes `$3`, sub reads `$3` as rs | 1 instruction | **Forward from EX/MEM.** When sub is in EX, add is in MEM. The ALU result of add is forwarded via ForwardA = 10. |
| `$3`: I1 → I3 | add writes `$3`, and reads `$3` as rs | 2 instructions | **Forward from MEM/WB.** When and is in EX, add is in WB. The result is forwarded via ForwardA = 01. |
| `$5`: I2 → I3 | sub writes `$5`, and reads `$5` as rt | 1 instruction | **Forward from EX/MEM.** When and is in EX, sub is in MEM. Forwarded via ForwardB = 10. |
| `$3`: I1 → I4 | add writes `$3`, or reads `$3` as rt | 3 instructions | **No forwarding needed.** By the time or reaches EX, add has completed WB. The value is in the register file and is read normally during ID. |
| `$5`: I2 → I4 | sub writes `$5`, or reads `$5` as rs | 2 instructions | **Forward from MEM/WB.** When or is in EX, sub is in WB. Forwarded via ForwardA = 01. |

No stalls are needed — all dependencies are between ALU instructions and are fully resolved by forwarding.

---

### Q15. Forwarding Condition with Guards

Write the complete forwarding condition for `ForwardB = 10` (forward from EX/MEM to ALU input B). Then explain each clause.

**Answer:**

```
if (EX/MEM.RegWrite == 1
    AND EX/MEM.RegisterRd ≠ 0
    AND EX/MEM.RegisterRd == ID/EX.RegisterRt)
then ForwardB = 10
```

**Clause-by-clause explanation:**

1. **`EX/MEM.RegWrite == 1`** — The instruction in MEM must actually be writing to a register. Without this check, a `sw` instruction (which has RegWrite=0) could falsely match. For example, `sw $5, 0($3)` has register fields that could numerically match a consumer's source, but it produces no result to forward. Forwarding from it would send stale or garbage data.

2. **`EX/MEM.RegisterRd ≠ 0`** — Register `$zero` (`$0`) is hardwired to 0 in MIPS and cannot be changed. An instruction like `add $0, $t1, $t2` is valid but the write to `$0` is discarded. Without this guard, if a subsequent instruction reads `$0`, the forwarding unit would forward the ALU result (which is nonzero) instead of the correct value 0. For example: `add $0, $3, $4` followed by `sub $5, $0, $6` would incorrectly forward ($3+$4) as the value of `$0`.

3. **`EX/MEM.RegisterRd == ID/EX.RegisterRt`** — The destination of the producer must match the second source operand (`rt`) of the consumer. This is the actual dependency check. `RegisterRt` specifically (rather than `RegisterRs`) is what makes this the ForwardB condition — ForwardB controls ALU input B, which receives the `rt` operand.

---

### Q16. Double Data Hazard

Consider this sequence:
```mips
add  $4, $4, $1      # I1
add  $4, $4, $2      # I2
add  $4, $4, $3      # I3
```
This is a double data hazard. When I3 is in EX, both EX/MEM and MEM/WB want to forward `$4`. Which must win and why? Write the revised MEM/WB forwarding condition.

**Answer:**

**EX/MEM must win** because it contains the result of I2, which is the **more recent** producer of `$4`. MEM/WB contains I1's result, which has already been superseded by I2. Using the older value from MEM/WB would be incorrect — the program semantics require that I3 reads the value of `$4` as written by I2.

When I3 is in EX:
- EX/MEM holds I2's result: `$4(original) + $2`
- MEM/WB holds I1's result: `$4(original) + $1`
- I3 needs the value from I2, not I1.

**Revised MEM/WB forwarding condition (for ForwardA):**

```
if (MEM/WB.RegWrite == 1
    AND MEM/WB.RegisterRd ≠ 0
    AND MEM/WB.RegisterRd == ID/EX.RegisterRs
    AND NOT (EX/MEM.RegWrite == 1
             AND EX/MEM.RegisterRd ≠ 0
             AND EX/MEM.RegisterRd == ID/EX.RegisterRs))
then ForwardA = 01
```

The added **NOT** clause says: "Only forward from MEM/WB if EX/MEM is not already forwarding the same register." This gives EX/MEM priority since it carries the more recent value. Without this clause, the behavior would depend on hardware implementation details (which mux input gets priority), making the design incorrect or at best unpredictable.

---

### Q17. Forwarding Limitation

A classmate says: "Forwarding completely eliminates all data hazard stalls." Give a counterexample and explain why forwarding fails.

**Answer:**

**Counterexample — the load-use hazard:**
```mips
lw   $t0, 0($t1)      # load — value available at end of MEM
add  $t2, $t0, $t3    # needs $t0 at start of EX
```

**Why forwarding fails:** The `lw` instruction doesn't have its loaded value until the **end of its MEM stage**. The `add` needs that value at the **beginning of its EX stage**, which occurs in the **same clock cycle** as the load's MEM stage. Forwarding can route data from the end of one stage to the beginning of the next stage in the **following** cycle, but it cannot send data backward in time within the same cycle.

Timeline:
```
Cycle 4:  lw is in MEM (value appears at END of cycle 4)
          add is in EX (value needed at START of cycle 4)
```

The value simply doesn't exist yet when the consumer needs it. No amount of wiring can fix a temporal impossibility.

**What the hardware does instead:** The **hazard detection unit** in ID detects this pattern (ID/EX.MemRead == 1 and register match), inserts a **1-cycle bubble** (stall), freezes PC and IF/ID, and injects a NOP into the pipeline. After the stall, the load's data emerges from MEM and is forwarded from MEM/WB to the add's EX stage in the next cycle — so forwarding still helps, but only after the 1-cycle stall makes the timing work.

---

## Section 5: Load-Use Hazard Detection

### Q18. Load-Use Stall Trace

Write the load-use hazard detection condition. Then trace this sequence cycle by cycle:
```mips
lw   $6, 0($1)       # I1
add  $7, $6, $8      # I2
sub  $9, $7, $6      # I3
```

**Answer:**

**Detection condition:**
```
if  ID/EX.MemRead == 1
AND (ID/EX.RegisterRt == IF/ID.RegisterRs
  OR ID/EX.RegisterRt == IF/ID.RegisterRt)
→ STALL
```

**Cycle-by-cycle trace:**

| Cycle | IF | ID | EX | MEM | WB |
|---|---|---|---|---|---|
| 1 | lw | | | | |
| 2 | add | lw | | | |
| 3 | add (frozen) | add (frozen) | lw | | |
| 3* | — | **bubble** inserted | | | |
| 4 | sub | add | **nop** | lw | |
| 5 | | sub | add | nop | lw |
| 6 | | | sub | add | nop |
| 7 | | | | sub | add |
| 8 | | | | | sub |

**What happens in cycle 3:** The hazard detection unit sees `ID/EX.MemRead = 1` (lw is in EX) and `ID/EX.RegisterRt ($6) == IF/ID.RegisterRs ($6)` of the add. It stalls: PC and IF/ID are frozen, and a NOP is injected into ID/EX.

**Cycle 4:** The lw is now in MEM and produces $6 at the end of this cycle.

**Cycle 5:** The add is in EX and receives `$6` via **forwarding from MEM/WB** (ForwardA = 01). No stall needed for `$6` anymore.

**I3's dependencies:** When sub reaches EX (cycle 6), `$7` is forwarded from EX/MEM (add just left EX), and `$6` is available from the register file (lw completed WB in cycle 5). No additional stalls.

---

### Q19. Compiler Reordering

A compiler reorders the following code to eliminate a load-use stall. Show the reordered sequence and verify correctness:
```mips
lw   $2, 0($10)       # I1
add  $4, $2, $3       # I2 — uses $2 immediately → STALL
lw   $5, 4($10)       # I3
add  $6, $5, $3       # I4 — uses $5 immediately → STALL
```

**Answer:**

**Reordered sequence:**
```mips
lw   $2, 0($10)       # I1
lw   $5, 4($10)       # I3 (moved up)
add  $4, $2, $3       # I2 — $2 is now 2 cycles old, forwarded from MEM/WB
add  $6, $5, $3       # I4 — $5 is now 2 cycles old, forwarded from MEM/WB
```

**Verification of correctness:**

- `lw $5, 4($10)` does not depend on `$2` or `$4`, so moving it before I2 is safe. It doesn't overwrite any register that I2 needs.
- `add $4, $2, $3` still reads the same `$2` and `$3` values — neither has been modified by the inserted `lw`.
- `add $6, $5, $3` still reads `$5` (loaded by I3) and `$3` — correct.
- The final register values ($2, $4, $5, $6) are identical in both orderings.

**Performance improvement:** The original code has 2 load-use stalls (2 wasted cycles). The reordered code has 0 stalls — each load's consumer is 2 instructions away, so the loaded value is available via MEM/WB forwarding without any stall. This saves 2 cycles at zero cost.

---

### Q20. Why Check MemRead?

The hazard detection unit checks `ID/EX.MemRead` to identify a load. Why can't it just check `ID/EX.RegisterRd ≠ 0` like the forwarding unit does? What would go wrong?

**Answer:**

`RegisterRd ≠ 0` only tells you that the instruction in EX has a nonzero destination register — it doesn't tell you that the instruction is a **load**. An R-type instruction like `add $3, $1, $2` also has `RegisterRd = $3 ≠ 0`, but its result is available at the **end of EX**, not the end of MEM. The forwarding unit can handle add-to-add dependencies with zero stalls.

If the hazard detection unit used `RegisterRd ≠ 0` instead of `MemRead`, it would **insert unnecessary stalls for every ALU-to-ALU dependency**, even though forwarding from EX/MEM handles those perfectly. Every sequence like:
```mips
add $3, $1, $2
sub $5, $3, $4
```
would suffer a 1-cycle stall that is completely unnecessary, destroying performance.

`MemRead` is the precise discriminator: it's 1 only for loads, which are the only instructions whose results aren't ready until after MEM. The stall is only needed when the data physically cannot arrive in time — and that's exclusively the load-use case.

---

## Section 6: Control Hazards & Branch Handling

### Q21. Branch Penalty and Early Resolution

In the standard 5-stage pipeline, if branches are resolved at the end of EX, what is the branch penalty in cycles? How does moving resolution to ID reduce this, and what new hardware is needed?

**Answer:**

**If resolved at end of EX: penalty = 2 cycles.** The branch is fetched in cycle N. In cycles N+1 and N+2, two instructions are fetched (at PC+4 and PC+8) before we know whether the branch is taken. If taken, both must be flushed — 2 wasted cycles.

**If resolved at end of ID: penalty = 1 cycle.** The branch is fetched in cycle N. In cycle N+1, one instruction is fetched at PC+4 before the outcome is known. If taken, only this one instruction is flushed — 1 wasted cycle. This halves the branch penalty.

**New hardware required in the ID stage:**

1. **A comparator** — compares the two register values (rs and rt) to determine if they're equal. This replaces the ALU's role in branch resolution. It must be fast enough to complete within the ID stage's clock period.

2. **An adder** — computes the branch target address (PC+4 + sign-extended offset << 2) in parallel with the comparison. Previously this was done in EX.

3. **Additional forwarding paths to ID** — since branches now resolve in ID, the branch operands must be available by the end of ID rather than EX. This creates new hazard scenarios that may require extra stalls (see Q23).

The trade-off: the 1-cycle penalty is better, but the ID stage becomes more complex and potentially slower (which could affect the clock period).

---

### Q22. Predict-Not-Taken Trace

Trace this sequence assuming predict-not-taken, with branch resolution in ID:
```mips
40: beq  $1, $2, target    # target = address 80
44: or   $5, $6, $7
48: add  $8, $9, $10
...
80: sub  $3, $4, $5
```
If the branch is taken, which instruction(s) get flushed?

**Answer:**

**Cycle-by-cycle trace (branch IS taken):**

| Cycle | IF | ID | EX | MEM | WB |
|---|---|---|---|---|---|
| 1 | beq (addr 40) | | | | |
| 2 | or (addr 44) — predicted not-taken, so fetch PC+4 | beq — **branch resolves: TAKEN** | | | |
| 3 | sub (addr 80) — correct target fetched | **or is FLUSHED** (IF.Flush asserted, IF/ID → NOP) | beq | | |
| 4 | (next after 80) | sub | nop (was or) | beq | |
| 5 | ... | (next) | sub | nop | beq |

**What gets flushed:** Only the `or` instruction (addr 44) is flushed. It was fetched speculatively in cycle 2 under the predict-not-taken assumption. When `beq` resolves as taken at the end of cycle 2 (in ID), the IF.Flush signal is asserted, which zeroes out the IF/ID register (converting `or` into a NOP). Simultaneously, the PC is redirected to address 80.

**The `add` (addr 48) is never fetched** because the PC is corrected before cycle 3 begins. Only 1 instruction is wasted — consistent with the 1-cycle branch penalty of ID-stage resolution.

**If the branch were NOT taken:** The prediction would be correct, `or` would proceed normally, and there would be no penalty at all.

---

### Q23. Branch Operand Forwarding Stalls

Resolving branches in ID means operands must be available at the end of ID. For each scenario, state the stall cycles needed:

**(a)** An R-type instruction 2 instructions before the branch writes a branch operand.

**(b)** An R-type instruction immediately before the branch writes a branch operand.

**(c)** A `lw` immediately before the branch loads a branch operand.

**Answer:**

**(a) R-type at distance 2 → 0 stalls**
```mips
add  $3, $1, $2       # produces $3
(any instruction)
beq  $3, $5, target   # needs $3 in ID
```
When `beq` is in ID, the `add` is in MEM (2 stages ahead). The add's result is available in EX/MEM at the start of this cycle. Forwarding from EX/MEM to the ID-stage comparator delivers the value in time. No stall needed.

**(b) R-type at distance 1 → 1 stall**
```mips
add  $3, $1, $2       # produces $3
beq  $3, $5, target   # needs $3 in ID
```
When `beq` is in ID, the `add` is in EX. The add's result isn't available until the **end** of EX, but the branch comparator needs it at the **end of ID** (same cycle). The data doesn't exist yet. One stall cycle is inserted; after the stall, `add` is in MEM and can forward via EX/MEM to ID.

**(c) Load at distance 1 → 2 stalls**
```mips
lw   $3, 0($1)        # produces $3 at end of MEM
beq  $3, $5, target   # needs $3 in ID
```
When `beq` is in ID, `lw` is in EX — the load hasn't even reached MEM yet, let alone produced its value. After 1 stall: `lw` is in MEM, but the value isn't ready until the end of MEM, and ID needs it at the start/middle of the cycle. After 2 stalls: `lw` is in WB, and the value can be forwarded from MEM/WB to the ID-stage comparator. Total: **2 stall cycles**.

---

## Section 7: Branch Prediction

### Q24. 1-Bit vs. 2-Bit Predictor on a Loop

A 1-bit branch predictor tracks a loop that iterates 10 times. How many mispredictions occur? Now answer for a 2-bit saturating counter initialized to "strongly taken."

**Answer:**

**1-bit predictor:**

Assume the predictor starts as "taken" (since the first iteration has no history, it may start either way — let's say taken).

- Iterations 1–9: Branch is taken (loop continues). Prediction: taken → **correct** (9 correct).
- Iteration 10: Branch is not taken (loop exits). Prediction: taken → **misprediction**. Predictor flips to "not taken."
- Next execution of the loop, iteration 1: Branch is taken. Prediction: not taken → **misprediction**. Predictor flips back to "taken."

**Total: 2 mispredictions per loop execution** (one on exit, one on re-entry).

**2-bit saturating counter (initialized to 11, strongly taken):**

- Iterations 1–9: Branch taken, prediction taken → all **correct**. Counter stays at 11.
- Iteration 10: Branch not taken, prediction taken → **misprediction**. Counter decrements to 10 (weakly taken).
- Next execution, iteration 1: Branch taken, prediction taken (MSB of 10 is 1) → **correct**. Counter increments back to 11.

**Total: 1 misprediction per loop execution** (only on exit).

**Why 2-bit is better:** The 1-bit predictor "forgets" the dominant pattern after a single anomaly. The 2-bit counter requires two consecutive mispredictions to change the prediction direction, so a single loop-exit anomaly only moves it from "strongly taken" to "weakly taken" — it still predicts taken on the next loop entry. This is exactly the behavior we want for loops.

---

### Q25. 2-Bit Counter State Trace

A branch has the outcome sequence: T, T, T, N, T, T, N, T. Starting from state 00 (strongly not-taken), trace every step.

**Answer:**

**State machine transitions:**
- State 00 (Strongly Not-Taken): predict NT. If T → go to 01. If N → stay 00.
- State 01 (Weakly Not-Taken): predict NT. If T → go to 10. If N → go to 00.
- State 10 (Weakly Taken): predict T. If T → go to 11. If N → go to 01.
- State 11 (Strongly Taken): predict T. If T → stay 11. If N → go to 10.

**Trace:**

| Step | Outcome | State Before | Prediction | Correct? | State After |
|---|---|---|---|---|---|
| 1 | T | 00 | NT | **Miss** | 01 |
| 2 | T | 01 | NT | **Miss** | 10 |
| 3 | T | 10 | T | ✓ | 11 |
| 4 | N | 11 | T | **Miss** | 10 |
| 5 | T | 10 | T | ✓ | 11 |
| 6 | T | 11 | T | ✓ | 11 |
| 7 | N | 11 | T | **Miss** | 10 |
| 8 | T | 10 | T | ✓ | 11 |

**Total mispredictions: 4 out of 8.** The first two are "warm-up" mispredictions because the counter started cold at 00. After warming up, it settles into the "taken" region and only misses on the occasional N outcomes. If the counter had been initialized to 11, only 2 mispredictions would have occurred (steps 4 and 7).

---

### Q26. BHT vs. BTB

Explain the difference between a Branch History Table and a Branch Target Buffer. Which tells you *whether* to branch? Which tells you *where*? Can you use one without the other?

**Answer:**

**Branch History Table (BHT):**
- Stores the **predicted direction** (taken or not-taken) for each branch, typically as a 2-bit saturating counter.
- Indexed by the branch's PC (or a hash of it).
- Answers the question: **"Should I take this branch?"**
- Does NOT store the target address.

**Branch Target Buffer (BTB):**
- A small cache that stores the **target address** of previously taken branches.
- Indexed by the PC of the instruction being fetched.
- Answers the question: **"If I take this branch, where do I go?"**
- Implicitly also predicts direction — if an entry exists, the branch is predicted taken.

**Can you use one without the other?**

- **BHT without BTB:** You know *whether* to branch but not *where*. You'd still need to compute the target address, which typically isn't available until ID or EX. This limits the benefit — you save the direction decision but still can't start fetching from the target immediately. Penalty is reduced but not eliminated.

- **BTB without BHT:** The BTB itself acts as a simple predictor — if an entry is found, predict taken; if not, predict not-taken. This works but is less accurate than combining it with a sophisticated BHT, because the BTB's presence/absence is a crude 1-bit signal.

- **BTB + BHT together:** The ideal combination. The BTB provides the target address instantly, and the BHT provides an accurate direction prediction. If the BHT says "not taken," the BTB entry is ignored and PC+4 is fetched. This gives the best accuracy and the lowest penalty on correct predictions (effectively 0 cycles).

---

### Q27. BTB Operation Details

What problem does the BTB solve that the BHT cannot? Describe the BTB lookup flow for each case: hit, miss, correct prediction, misprediction.

**Answer:**

**Problem the BTB solves:** Even with a perfect direction prediction from the BHT, we still need the **target address** to fetch the next instruction. Computing the target (PC + sign-extended offset) normally happens in ID or EX — meaning there's at least a 1-cycle delay before we can fetch from the target. The BTB stores the target address so it's available **in the same cycle as the fetch**, eliminating this delay entirely.

**BTB lookup flow:**

**1. Hit (entry found for current PC):**
The instruction at this PC was a taken branch before. The BTB provides the stored target address. Fetch the next instruction from the target address (not PC+4). Direction prediction comes from the BHT — if BHT says "not taken," override the BTB and fetch PC+4 instead.

**2. Miss (no entry for current PC):**
Either this is not a branch, or it's a branch we haven't seen taken before. Proceed normally — fetch from PC+4. No penalty.

**3. Correct prediction (verified later in ID/EX):**
The branch outcome matches what we predicted. No penalty, no pipeline flush. The BTB entry remains valid. Continue executing.

**4. Misprediction — predicted taken, actually not taken:**
We fetched from the wrong address (the stored target). The wrongly-fetched instruction must be squashed/flushed. Restart fetching from PC+4 (the correct fall-through address). The BTB entry can be deleted or the BHT updated to "not taken" so we don't make the same mistake next time.

**5. Misprediction — no BTB entry, but branch is actually taken:**
We fetched PC+4 but should have fetched the target. Flush the wrong instruction, redirect fetch to the branch target. **Add a new entry** to the BTB with this branch's PC and target address, so next time the target is available immediately.

---

## Section 8: Advanced Prediction Schemes

### Q28. Local vs. Global Predictors

Explain the difference. Give code examples where each one wins.

**Answer:**

**Local predictor:** Maintains a separate history register for each branch (or each branch PC). The history records the last N outcomes of *that specific* branch. This history indexes into a table of 2-bit counters. It captures **repeating patterns within a single branch**.

**Global predictor:** Uses a single Global History Register (GHR) that records the last N outcomes of *all* branches across the entire program. The GHR (often XORed with the branch PC) indexes a table of counters. It captures **correlations between different branches**.

**Example where local wins:**
```c
for (int i = 0; i < 4; i++) {   // branch pattern: T T T N T T T N ...
    do_something();
}
```
The loop branch has a repeating pattern `TTTN`. A local predictor with a 4-bit history register learns this pattern: after seeing `TTT`, predict `N`; after seeing `TTN`, predict `T`; etc. A global predictor would have its history polluted by other branches, making it harder to learn this branch-specific pattern.

**Example where global wins:**
```c
if (x > 0)    // B1
    a = 1;
if (x > 0)    // B2 — perfectly correlated with B1
    b = 1;
```
B2's outcome is always identical to B1's. A global predictor records B1's outcome in the GHR, so when B2 is reached, the GHR tells the predictor exactly what B1 did — enabling a perfect prediction. A local predictor for B2 would only see B2's own history and miss the correlation with B1.

---

### Q29. gselect vs. gshare Aliasing

Two branches at different PCs both have global history `00000000`. Show a gselect collision and how gshare avoids it.

**Answer:**

**Setup:** Branch A at PC = `00001111`, Branch B at PC = `11110000`. Both have GHR = `00000000`. Table has 256 entries (8-bit index).

**gselect (4-bit PC concatenated with 4-bit GHR):**
- Branch A: index = upper 4 bits of PC ∥ upper 4 bits of GHR = `0000` ∥ `0000` = `00000000` (entry 0)
- Branch B: index = `1111` ∥ `0000` = `11110000` (entry 240)

Now change the scenario slightly — Branch A at PC = `11110000` and Branch B at PC = `11111111`, both with GHR = `00000000`:
- Branch A: `1111` ∥ `0000` = `11110000` (entry 240)
- Branch B: `1111` ∥ `0000` = `11110000` (entry 240) — **COLLISION!**

Both map to the same entry because gselect only uses the top 4 bits of the PC, and these two branches share those bits. They'll corrupt each other's prediction state.

**gshare (8-bit PC XOR 8-bit GHR):**
- Branch A: `11110000` XOR `00000000` = `11110000` (entry 240)
- Branch B: `11111111` XOR `00000000` = `11111111` (entry 255) — **No collision!**

XOR distributes entries more evenly across the table because it uses all bits of both the PC and the GHR, rather than splitting the index space between them. Different PCs with the same history almost always map to different entries.

---

### Q30. Tournament Predictor Selector Updates

In a tournament predictor, under what conditions does the selector counter update? What happens if both predictors are wrong?

**Answer:**

The tournament predictor runs two predictors (P1 and P2, typically local and global) in parallel, and a **selector table** (array of 2-bit counters, indexed by PC) tracks which one has been more accurate for each branch.

**Update rules:**

| P1 | P2 | Selector Action |
|---|---|---|
| Correct | Correct | **No change** — both agreed and were right; no information about which is better |
| Correct | Wrong | **Increment** — favor P1 (move toward P1) |
| Wrong | Correct | **Decrement** — favor P2 (move toward P2) |
| Wrong | Wrong | **No change** — both failed equally; no evidence to prefer one over the other |

**When both are wrong:** The selector does **not** change. This makes sense because the selector's job is to pick the *better* predictor — not to punish both. If both failed, we have no information about which one is more reliable. Changing the selector would be arbitrary and could actually hurt future predictions by moving away from the predictor that's generally better.

The actual branch prediction table entries in P1 and P2 are both updated regardless of whether they were selected — this ensures both predictors stay "warm" and can recover quickly if the selector switches to them.

---

## Section 9: Pipeline Performance & ISA Design

### Q31. Clock Period and Speedup Calculation

A 5-stage pipeline has stage latencies of 300ps, 200ps, 350ps, 300ps, and 150ps. What is the pipelined clock period? Single-cycle period? Ideal speedup? Why is actual speedup lower?

**Answer:**

**Pipelined clock period = 350 ps** — the clock must be set to the **slowest stage** (the 350ps stage), because every stage must complete within one clock period. The faster stages (200ps, 150ps) sit idle for part of the cycle.

**Single-cycle clock period = 300 + 200 + 350 + 300 + 150 = 1300 ps** — the single-cycle design must accommodate the total delay of the longest instruction path through all stages.

**Ideal speedup = 1300 / 350 = 3.71×**

Note this is less than 5× (the number of stages) because the stages are **unbalanced**. If all stages were equal (1300/5 = 260ps each), the pipelined clock would be 260ps and speedup would be 1300/260 = 5×.

**Why actual speedup is even lower than 3.71×:**

1. **Pipeline register overhead:** Each pipeline register adds a small latching delay (typically 10–20ps) to every cycle, making the actual clock period more like 350 + 20 = 370ps.
2. **Hazard stalls:** Load-use hazards insert bubbles (CPI > 1).
3. **Branch mispredictions:** Control hazards cause flushes (CPI > 1).
4. **Pipeline fill/drain:** At program start and end, the pipeline isn't fully utilized.

All of these push CPI above 1, reducing the effective throughput below the ideal.

---

### Q32. MIPS Pipeline-Friendly Features

Explain three specific features of the MIPS ISA that make it easier to pipeline than x86.

**Answer:**

**1. Fixed 32-bit instruction width**
- **Benefits IF stage:** The fetcher always reads exactly 4 bytes from the instruction memory. It knows the next instruction starts at PC+4. There's no need to determine instruction length before fetching the next one.
- **x86 problem:** Instructions range from 1 to 15 bytes. The fetcher doesn't know where the next instruction starts until it partially decodes the current one. This creates a dependency between IF and ID, requiring complex pre-decode logic or fetch buffers.

**2. Few, regular instruction formats with fixed field positions**
- **Benefits ID stage:** The `rs` field is always in bits [25:21] and `rt` is always in bits [20:16], regardless of instruction type. The register file can speculatively read these registers every cycle without waiting for the opcode to be fully decoded. Decode and register read happen in parallel within a single stage.
- **x86 problem:** Source and destination operands can appear in different positions depending on the instruction, prefix bytes, and addressing modes. Decoding is a multi-step process that's hard to fit in one pipeline stage.

**3. Load/store architecture with aligned memory access**
- **Benefits MEM stage:** Only `lw` and `sw` access memory. Memory access is a simple, single-cycle operation because operands are aligned (a word starts at a multiple of 4). The address calculation (base + offset) happens in EX, and the access happens in MEM — clean separation.
- **x86 problem:** Almost any instruction can have a memory operand (e.g., `ADD [mem], reg`), requiring address calculation and memory access to be available for arbitrary instructions, not just loads/stores. Unaligned accesses can span cache lines, taking multiple cycles.

---

### Q33. Effective CPI Calculation

Instruction mix: 30% ALU, 25% loads, 10% stores, 25% branches (60% taken), 10% jumps. With forwarding, 40% of loads cause a load-use stall. Branch penalty is 1 cycle (predict not-taken). Calculate the effective CPI.

**Answer:**

**Base CPI = 1** (ideal pipelined execution, one instruction per cycle).

**Load-use stall penalty:**
- 25% of instructions are loads.
- 40% of those loads cause a 1-cycle stall.
- Penalty contribution = 0.25 × 0.40 × 1 = **0.10 cycles/instruction**

**Branch misprediction penalty (predict not-taken):**
- 25% of instructions are branches.
- With predict-not-taken, mispredictions occur when the branch is **taken** = 60% of branches.
- Penalty per misprediction = 1 cycle.
- Penalty contribution = 0.25 × 0.60 × 1 = **0.15 cycles/instruction**

**Jump penalty:**
- 10% of instructions are jumps.
- Jumps always change the PC (always "taken"), so with predict-not-taken, every jump incurs a 1-cycle penalty.
- Penalty contribution = 0.10 × 1 = **0.10 cycles/instruction**

**Effective CPI = 1 + 0.10 + 0.15 + 0.10 = 1.35**

This means on average, each instruction takes 1.35 cycles instead of the ideal 1 cycle. The pipeline's actual throughput is 1/1.35 ≈ 74% of ideal. Branches are the largest single source of wasted cycles in this workload.

---

*End of Practice Exam*
