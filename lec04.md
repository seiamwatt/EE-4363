# EE 4363 / CSci 4203 — Microarchitecture Study Notes

## Addressing Modes

- **Immediate addressing** — operand is in the instruction itself (immediate field)
- **Register addressing** — operand is in a register (R-type: op, rs, rt, rd, shamt, funct)
- **Base addressing** — address = register + offset; accesses byte, halfword, or word in memory
- **PC-relative addressing** — address = PC + offset; used for branches
- **Pseudodirect addressing** — address = top 4 bits of PC concatenated with 26-bit address and "00"; used for jumps

---

## Instruction Life Cycle

Five stages: **Fetch → Decode → Execute → Memory → Write-back** (F → D → EX → M → WB)

| Stage | Description |
|---|---|
| **Fetch** | PC goes to instruction memory, retrieve the 32-bit instruction word |
| **Decode** | Determine what functional units are needed, read source registers from register file; control unit generates control signals from opcode |
| **Execute** | ALU computes arithmetic result (R-type), memory address (load/store), or branch target address |
| **Memory** | Access data memory for load (read) or store (write); not used by R-type |
| **Write-back** | Write result to destination register (if applicable); update PC to either PC+4 or branch target |

---

## Datapath Components

| Component | Description |
|---|---|
| **PC** | 32-bit register holding current instruction address |
| **Instruction memory** | Addressed by PC, outputs 32-bit instruction |
| **Register file** | 32 registers, each 32 bits; supports 2 simultaneous reads and 1 write; write is clocked |
| **ALU** | Performs add, subtract, AND, OR, set-on-less-than, etc.; has a Zero output flag |
| **Data memory** | Separate from instruction memory; has Address, Read data, Write data ports; controlled by MemRead and MemWrite signals |
| **Sign-extend unit** | Extends 16-bit immediate to 32 bits by replicating the sign bit |
| **Shift left 2** | Just re-routes wires (no actual hardware cost) |
| **Multiplexers (Mux)** | Select between inputs using selection bits; a 2:1 mux takes two 32-bit inputs and one selection bit |

---

## Key Multiplexers in the Datapath

| Mux | Function |
|---|---|
| **PCSrc** | Selects next PC: PC+4 (normal) vs. branch target address |
| **ALUSrc** | Selects ALU second input: register value (R-type) vs. sign-extended immediate (load/store) |
| **MemtoReg** | Selects write-back data: ALU result (R-type) vs. memory read data (load) |
| **RegDst** | Selects destination register: rd field (R-type) vs. rt field (load) |
| **Jump** | Selects between branch/sequential PC and jump target address |

---

## Control Signals

Derived from instruction opcode (bits 31–26). The control unit outputs:

| Signal | Description |
|---|---|
| **RegDst** | Which register to write to (rd vs. rt) |
| **Branch** | Is this a branch instruction? |
| **MemRead** | Enable reading from data memory |
| **MemtoReg** | Write memory data or ALU result to register |
| **ALUOp** (2 bits) | Tells ALU control what category of operation |
| **MemWrite** | Enable writing to data memory |
| **ALUSrc** | ALU second operand source |
| **RegWrite** | Enable writing to register file |

> **PCSrc** is not a direct control output — it is `Branch AND Zero` (both must be true to take the branch).

---

## ALU Control

ALU control is a 4-bit signal derived from **ALUOp** (2 bits from main control) + **funct field** (6 bits, for R-type only).

| Instruction | ALUOp | Funct | ALU Control | ALU Function |
|---|---|---|---|---|
| lw | 00 | X | 0010 | add |
| sw | 00 | X | 0010 | add |
| beq | 01 | X | 0110 | subtract |
| R-type add | 10 | 100000 | 0010 | add |
| R-type sub | 10 | 100010 | 0110 | subtract |
| R-type AND | 10 | 100100 | 0000 | AND |
| R-type OR | 10 | 100101 | 0001 | OR |
| R-type slt | 10 | 101010 | 0111 | set-on-less-than |

- For **load/store**, ALU always adds (base + offset).
- For **beq**, ALU subtracts to check equality (Zero flag).
- For **R-type**, the funct field determines the specific operation.

---

## Instruction Format Fields

### R-type
```
[op 6 | rs 5 | rt 5 | rd 5 | shamt 5 | funct 6]
```
- **rs**: always read
- **rt**: read (second source)
- **rd**: write destination

### Load/Store (I-type)
```
[op 6 | rs 5 | rt 5 | address 16]
```
- **rs**: base register (always read)
- **rt**: destination for load (write) / source for store (read)
- **address**: 16-bit offset, sign-extended

### Branch (I-type)
```
[op 6 | rs 5 | rt 5 | address 16]
```
- **rs, rt**: both read for comparison
- **address**: sign-extended, shifted left 2, added to PC+4

### Jump (J-type)
```
[op 6 | address 26]
```
- New PC = `{PC+4[31:28], address[25:0], 00}`

---

## Logic Design Basics

- **Combinational elements** — output depends only on current inputs (AND gates, adders, ALU, muxes)
- **Sequential (state) elements** — output depends on stored state + input; updated on clock edge (registers, PC)
- **Edge-triggered** — state updates on rising edge of clock
- **Clocking methodology** — combinational logic sits between state elements; data is processed between clock edges; the longest delay path determines the minimum clock period

---

## Branch Execution (beq)

`beq`: if `r_inp1 == r_inp2`, then `PC ← branch target`; else `PC ← PC+4`

**Implementation:** ALU subtracts the two register values. If result is zero (Zero flag = 1), and Branch control signal = 1, then PCSrc = 1, selecting the branch target.

```
Branch target = PC+4 + (sign-extended offset << 2)
```

---

## Data Flow by Instruction Type

### R-type (e.g., `add $rd, $rs, $rt`)

Fetch instruction → read rs and rt from register file → ALU performs operation on both values → result written back to rd → PC ← PC+4

| Signal | Value |
|---|---|
| RegDst | 1 |
| ALUSrc | 0 |
| MemtoReg | 0 |
| RegWrite | 1 |
| MemRead | 0 |
| MemWrite | 0 |
| Branch | 0 |
| ALUOp | 10 |

### Load (`lw $rt, offset($rs)`)

Fetch → read rs → ALU adds rs + sign-extended offset → address sent to data memory → read data written back to rt → PC ← PC+4

| Signal | Value |
|---|---|
| RegDst | 0 |
| ALUSrc | 1 |
| MemtoReg | 1 |
| RegWrite | 1 |
| MemRead | 1 |
| MemWrite | 0 |
| Branch | 0 |
| ALUOp | 00 |

### Store (`sw $rt, offset($rs)`)

Fetch → read rs and rt → ALU adds rs + sign-extended offset → address sent to data memory → rt value written to memory → PC ← PC+4

| Signal | Value |
|---|---|
| ALUSrc | 1 |
| RegWrite | 0 |
| MemRead | 0 |
| MemWrite | 1 |
| Branch | 0 |
| ALUOp | 00 |

### Branch (`beq $rs, $rt, offset`)

Fetch → read rs and rt → ALU subtracts → if Zero, PC ← branch target; else PC ← PC+4

| Signal | Value |
|---|---|
| ALUSrc | 0 |
| RegWrite | 0 |
| MemRead | 0 |
| MemWrite | 0 |
| Branch | 1 |
| ALUOp | 01 |

---

## Performance

- **Critical path** (longest delay): **load instruction** — instruction memory → register file → ALU → data memory → register file
- This path determines the clock period for the entire processor in a single-cycle design
- All instructions take one clock cycle, so the clock must be slow enough for the worst case (load)
- **Improvement idea:** pipelining (covered later)