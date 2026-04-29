# Microarchitecture Study Guide
## EE 4363 / CSci 4203 — Computer Architecture & Machine Organization

---

## 1. Addressing Modes Summary

| # | Mode | How Address is Formed | Used By |
|---|------|----------------------|---------|
| 1 | **Immediate** | Operand is in the instruction itself (the "Immediate" field) | `addi`, `andi`, etc. |
| 2 | **Register** | Operand is in the register specified by `rd`/`rs`/`rt` | R-type ALU ops |
| 3 | **Base (Displacement)** | Address = Register + sign-extended offset | `lw`, `sw` |
| 4 | **PC-Relative** | Address = PC + sign-extended offset | `beq`, `bne` |
| 5 | **Pseudodirect** | Address = {PC[31:28], 26-bit addr, 00} | `j`, `jal` |

---

## 2. Instruction Life-Cycle (5 Stages)

Every instruction passes through these stages:

1. **Fetch (F)** — Use PC to read instruction from instruction memory.
2. **Decode (D)** — Determine the operation, read register operands from the register file, generate control signals.
3. **Execute (EX)** — Use the ALU to compute an arithmetic result, a memory address, or a branch target.
4. **Memory Access (M)** — Access data memory for loads and stores (unused for R-type/branch).
5. **Write-Back (WB)** — Write the result back to the destination register (if applicable); update PC to either PC+4 or the branch/jump target.

---

## 3. Key Datapath Components

### Combinational Elements (no state — output depends only on current input)

- **Adder** — Y = A + B (used to compute PC+4 and branch targets)
- **ALU** — Y = F(A, B), controlled by a 4-bit ALU control signal; also outputs a **Zero** flag
- **Multiplexer (Mux)** — Selects one of several inputs based on a control (selection) bit
- **Sign-Extend Unit** — Converts 16-bit immediate to 32 bits by replicating the sign bit
- **Shift Left 2** — Multiplies by 4 (word alignment); just re-routes wires

### Sequential (State) Elements (hold data across clock cycles)

- **Program Counter (PC)** — 32-bit register holding the address of the current instruction
- **Register File** — 32 registers × 32 bits; supports 2 simultaneous reads + 1 write per cycle
- **Instruction Memory** — Read-only in a single-cycle design
- **Data Memory** — Supports read (load) and write (store), controlled by MemRead / MemWrite

### How a Register Works
- **Edge-triggered** (positive edge): the stored value updates only when the clock transitions from 0 → 1.
- Data-in (32 bits) → Register → Data-out (32 bits), gated by the clock.

---

## 4. Control Signals

The **Control Unit** reads the opcode (bits [31:26]) and generates the following signals:

| Signal | Purpose |
|--------|---------|
| **RegDst** | Selects destination register: `rd` (R-type) vs `rt` (load) |
| **ALUSrc** | Selects ALU's second input: register data (R-type) vs sign-extended immediate (load/store) |
| **MemtoReg** | Selects write-back data: ALU result (R-type) vs memory read data (load) |
| **RegWrite** | Enables writing to the register file (R-type, load) |
| **MemRead** | Enables reading from data memory (load) |
| **MemWrite** | Enables writing to data memory (store) |
| **Branch** | Indicates a branch instruction; ANDed with ALU Zero to produce **PCSrc** |
| **ALUOp** | 2-bit signal sent to ALU control logic |
| **Jump** | Selects the jump target address for the PC |

### PCSrc Logic
```
PCSrc = Branch AND Zero
```
- If PCSrc = 0 → next PC = PC + 4
- If PCSrc = 1 → next PC = branch target (PC + 4 + sign-extended offset × 4)

---

## 5. ALU Control

The ALU control unit takes two inputs: the 2-bit **ALUOp** from the main control and the 6-bit **funct** field (bits [5:0]) from R-type instructions.

| Opcode | ALUOp | Funct Field | ALU Function | ALU Control |
|--------|-------|-------------|--------------|-------------|
| lw     | 00    | XXXXXX      | add          | 0010        |
| sw     | 00    | XXXXXX      | add          | 0010        |
| beq    | 01    | XXXXXX      | subtract     | 0110        |
| R-type | 10    | 100000 (add)| add          | 0010        |
| R-type | 10    | 100010 (sub)| subtract     | 0110        |
| R-type | 10    | 100100 (AND)| AND          | 0000        |
| R-type | 10    | 100101 (OR) | OR           | 0001        |
| R-type | 10    | 101010 (slt)| set-on-less-than | 0111   |

**Key insight:** For loads/stores, ALUOp = 00 always means "add" (address calculation). For branches, ALUOp = 01 always means "subtract" (equality check). Only R-type (ALUOp = 10) needs to consult the funct field.

---

## 6. Instruction Formats & Field Usage

### R-Type: `[op(6) | rs(5) | rt(5) | rd(5) | shamt(5) | funct(6)]`
- **rs** → Read register 1 (always read)
- **rt** → Read register 2 (always read)
- **rd** → Write register (destination)
- **funct** → Determines specific ALU operation

### I-Type (Load/Store): `[op(6) | rs(5) | rt(5) | address/immediate(16)]`
- **rs** → Base register (always read)
- **rt** → Destination (load) or source data (store)
- **address** → Sign-extended, used as offset for base addressing

### I-Type (Branch): `[op(6) | rs(5) | rt(5) | address(16)]`
- **rs**, **rt** → Two registers compared for equality
- **address** → Sign-extended, shifted left 2, added to PC+4

### J-Type (Jump): `[op(6) | address(26)]`
- New PC = {PC+4[31:28], address[25:0], 00}

---

## 7. Datapath Walkthrough by Instruction Type

### R-Type (e.g., `add $rd, $rs, $rt`)
1. Fetch instruction; PC ← PC + 4
2. Read `rs` and `rt` from register file
3. ALU performs operation (determined by funct → ALU control)
4. Memory stage: nothing (MemRead = 0, MemWrite = 0)
5. ALU result written to `rd` (RegWrite = 1, MemtoReg = 0, RegDst = 1)

### Load Word (`lw $rt, offset($rs)`)
1. Fetch instruction; PC ← PC + 4
2. Read `rs` from register file; sign-extend 16-bit offset
3. ALU computes address: rs + sign-extended offset (ALUSrc = 1)
4. Read data memory at computed address (MemRead = 1)
5. Memory data written to `rt` (RegWrite = 1, MemtoReg = 1, RegDst = 0)

### Store Word (`sw $rt, offset($rs)`)
1. Fetch instruction; PC ← PC + 4
2. Read `rs` and `rt` from register file; sign-extend offset
3. ALU computes address: rs + sign-extended offset
4. Write `rt` data to data memory at computed address (MemWrite = 1)
5. No register write-back (RegWrite = 0)

### Branch on Equal (`beq $rs, $rt, offset`)
1. Fetch instruction; PC ← PC + 4
2. Read `rs` and `rt`; sign-extend offset; compute branch target = PC+4 + (offset << 2)
3. ALU subtracts: rs − rt; check Zero flag
4. If Zero = 1 → PCSrc = 1 → PC ← branch target; otherwise PC stays at PC+4
5. No register write-back (RegWrite = 0)

### Jump (`j target`)
1. Fetch instruction
2. New PC = {PC+4[31:28], instruction[25:0] << 2}
3. Requires extra mux controlled by **Jump** signal

---

## 8. Clocking Methodology

- All state elements are **positive-edge-triggered**.
- Combinational logic sits between state elements and computes results during the clock cycle.
- The **clock period** must be long enough for the slowest (longest-delay) path through the combinational logic.
- **Critical path** (determines max clock frequency): the **load instruction** path:
  - Instruction Memory → Register File → ALU → Data Memory → Register File

---

## 9. Multiplexers in the Datapath

There are three critical muxes (plus one more for jumps):

| Mux | Controlled By | Input 0 | Input 1 | Purpose |
|-----|--------------|---------|---------|---------|
| **ALUSrc Mux** | ALUSrc | Read data 2 (register) | Sign-extended immediate | Choose ALU's B input |
| **MemtoReg Mux** | MemtoReg | ALU result | Memory read data | Choose what to write back to register |
| **PCSrc Mux** | Branch AND Zero | PC + 4 | Branch target | Choose next PC |
| **RegDst Mux** | RegDst | rt field [20:16] | rd field [15:11] | Choose write register number |
| **Jump Mux** | Jump | PCSrc mux output | Jump target | Final next-PC selection |

---

## 10. Performance & Design Considerations

- **Single-cycle design:** Each instruction completes in one clock cycle. The clock period is set by the slowest instruction (load).
- **Problem:** Faster instructions (R-type, branches) are forced to wait for the same long clock period.
- **Solution preview:** Pipelining — break execution into stages so multiple instructions overlap, improving throughput.

---

## 11. Key Concepts to Remember

- **Separate instruction and data memories** are needed because an instruction might require both an instruction fetch and a data access in the same cycle.
- The **register file** allows 2 reads and 1 write simultaneously — reads are combinational (instant), writes happen on the clock edge.
- **Sign extension** replicates bit 15 of the immediate field into bits [31:16] to preserve the value's sign for address calculations.
- **Shift left 2** converts a word offset to a byte offset (since MIPS addresses are byte-addressed but instructions/words are 4 bytes).
- The **Zero flag** from the ALU is essential for branch decisions — it indicates whether the subtraction result is zero (i.e., the two operands are equal).

---

*Source: EE 4363/CSci 4203 Lecture 04 — Microarchitecture, Prof. Ulya Karpuzcu, University of Minnesota*