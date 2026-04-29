# MIPS Instruction Set Architecture — Study Guide

**EE 4363 / CSci 4203 — Computer Architecture & Machine Organization**

---

## Design Principles

Throughout the MIPS ISA, four key design principles recur. Know these and be able to identify which principle justifies a given design choice.

1. **Simplicity favors regularity** — Every arithmetic instruction operates on exactly three operands (two sources, one destination). This fixed format simplifies hardware.
2. **Smaller is faster** — Only 32 registers; a small register file can be accessed more quickly than a large one.
3. **Make the common case fast** — Immediate operands let you embed small constants directly in instructions, avoiding an extra load.
4. **Good design demands good compromises** — Multiple instruction formats (R, I, J) complicate decoding slightly but keep all instructions a uniform 32 bits.

---

## Registers

- MIPS has a **32 × 32-bit register file** (registers numbered 0–31).
- A 32-bit quantity is called a **word**.
- Key register conventions:
  - `$t0`–`$t9` → temporaries (caller-saved)
  - `$s0`–`$s7` → saved variables (callee-saved)
  - `$zero` (`$0`) → hardwired to **0**, cannot be overwritten
- **Trick:** Move between registers using `add $t2, $s1, $zero`.

---

## Arithmetic & Immediate Instructions

| Instruction | Example | Meaning |
|---|---|---|
| `add` | `add $s0, $t0, $t1` | `$s0 = $t0 + $t1` |
| `sub` | `sub $s0, $t0, $t1` | `$s0 = $t0 - $t1` |
| `addi` | `addi $s3, $s3, 4` | `$s3 = $s3 + 4` |

- There is **no `subi`** — use `addi` with a negative constant.
- **Compiling example:** `f = (g + h) - (i + j);` with `f`–`j` in `$s0`–`$s4`:

```
add $t0, $s1, $s2    # t0 = g + h
add $t1, $s3, $s4    # t1 = i + j
sub $s0, $t0, $t1    # f  = t0 - t1
```

---

## Memory Operands

- Memory is **byte-addressed**; each address identifies one 8-bit byte.
- Words are **aligned** — word addresses must be multiples of 4.
- MIPS is **Big Endian** (most-significant byte at the lowest address).
- Two key instructions:

| Instruction | Example | Meaning |
|---|---|---|
| `lw` | `lw $t0, 32($s3)` | Load word from `Mem[$s3 + 32]` into `$t0` |
| `sw` | `sw $t0, 48($s3)` | Store `$t0` into `Mem[$s3 + 48]` |

- **Offset calculation:** Array index × 4. So `A[8]` → offset = 8 × 4 = **32**.

### Example

```c
A[12] = h + A[8];   // h in $s2, base of A in $s3
```
```
lw  $t0, 32($s3)      # load A[8]
add $t0, $s2, $t0     # t0 = h + A[8]
sw  $t0, 48($s3)      # store into A[12]  (12×4 = 48)
```

### Registers vs. Memory

- Registers are **faster** to access.
- Compilers should keep frequently used variables in registers and only **spill** to memory when necessary.

---

## Number Representation (32-bit)

### Unsigned Integers
- Range: **0** to **2³² − 1** (0 to 4,294,967,295)

### Two's-Complement Signed Integers
- Range: **−2³¹** to **+2³¹ − 1** (−2,147,483,648 to +2,147,483,647)
- Bit 31 is the **sign bit** (1 = negative, 0 = non-negative).
- Special values to memorize:
  - `0`: `0000 0000 … 0000`
  - `−1`: `1111 1111 … 1111`
  - Most negative: `1000 0000 … 0000`
  - Most positive: `0111 1111 … 1111`

### Negation
- **Complement all bits and add 1.**
- Example: `+2` = `0000…0010` → complement = `1111…1101` → add 1 = `1111…1110` = `−2`.

### Sign Extension
- Replicate the **sign bit** to the left when expanding to more bits.
- Unsigned values: extend with **0s**.

---

## Instruction Encoding

All MIPS instructions are **32 bits wide**. Three formats:

### R-Format (register-register operations)

| op (6) | rs (5) | rt (5) | rd (5) | shamt (5) | funct (6) |
|---|---|---|---|---|---|

- `op` = 0 for R-type; `funct` distinguishes the operation.
- `rd` = destination, `rs` and `rt` = sources.
- Example: `add $t0, $s1, $s2` → op=0, rs=17, rt=18, rd=8, shamt=0, funct=32 → **0x02324020**

### I-Format (immediates, loads/stores, branches)

| op (6) | rs (5) | rt (5) | immediate/address (16) |
|---|---|---|---|

- Immediate range: **−2¹⁵** to **+2¹⁵ − 1** (−32,768 to 32,767)

### J-Format (jumps)

| op (6) | address (26) |
|---|---|

### Register Numbers

| Name | Number | Name | Number |
|---|---|---|---|
| `$t0`–`$t7` | 8–15 | `$s0`–`$s7` | 16–23 |
| `$t8`–`$t9` | 24–25 | `$zero` | 0 |

---

## Logical Operations

| Operation | C operator | MIPS instruction |
|---|---|---|
| Shift left | `<<` | `sll` |
| Shift right | `>>` | `srl` |
| Bitwise AND | `&` | `and`, `andi` |
| Bitwise OR | `\|` | `or`, `ori` |
| Bitwise NOT | `~` | `nor` (with `$zero`) |

### Key Points
- `sll` by *i* bits = multiply by **2ⁱ**.
- `srl` by *i* bits = divide by **2ⁱ** (unsigned only).
- **AND** masks (clears) bits; **OR** sets bits; **NOR with $zero** inverts all bits.
- NOT is done as: `nor $t0, $t1, $zero`

---

## Conditional Operations

### Branch Instructions

| Instruction | Meaning |
|---|---|
| `beq rs, rt, L1` | Branch to L1 if `rs == rt` |
| `bne rs, rt, L1` | Branch to L1 if `rs != rt` |
| `j L1` | Unconditional jump to L1 |

### Set-on-Less-Than

| Instruction | Meaning |
|---|---|
| `slt rd, rs, rt` | `rd = (rs < rt) ? 1 : 0` (signed) |
| `slti rt, rs, imm` | `rt = (rs < imm) ? 1 : 0` (signed) |
| `sltu` / `sltiu` | Same but **unsigned** comparison |

### Implementing "branch if less than"

```
slt  $t0, $s1, $s2     # $t0 = 1 if $s1 < $s2
bne  $t0, $zero, L     # branch to L if $t0 ≠ 0
```

### Why no `blt` instruction?
- Hardware for `<` is slower than `==`/`≠`. Combining it with a branch would slow the clock for *all* instructions. Using `slt` + `beq`/`bne` is the design compromise.

### Signed vs. Unsigned Comparison Example
If `$s0 = 0xFFFFFFFF` and `$s1 = 1`:
- `slt` (signed): −1 < 1 → result = **1**
- `sltu` (unsigned): 4,294,967,295 > 1 → result = **0**

---

## 32-bit Constants

Most constants fit in 16 bits, but for a full 32-bit constant:

```
lui $s0, 61          # load upper 16 bits (61 = 0x003D)
ori $s0, $s0, 2304   # OR in lower 16 bits (2304 = 0x0900)
# Result: $s0 = 0x003D0900
```

---

## Addressing Modes (5 total)

1. **Immediate** — operand is a constant in the instruction itself.
2. **Register** — operand is in a register.
3. **Base (displacement)** — address = register + signed offset (used by `lw`/`sw`).
4. **PC-relative** — target = PC + (offset × 4). Used by `beq`/`bne`.
5. **Pseudodirect** — target = PC₃₁₋₂₈ : (26-bit address × 4). Used by `j`.

### Branching Far Away
If a branch target exceeds the 16-bit offset range, the assembler rewrites it:
```
beq $s0, $s1, L1        # can't reach L1
↓  assembler transforms to:
bne $s0, $s1, L2         # skip over jump
j   L1                   # jump has 26-bit range
L2: …
```

---

## Stored Program Concept

- Instructions are encoded in binary, just like data.
- Both instructions and data reside in memory.
- This allows programs to operate on other programs (compilers, linkers, loaders).
- **Binary compatibility** via standardized ISAs means compiled programs run on different hardware implementations of the same ISA.

---

## Quick Self-Test Questions

1. Why does MIPS use exactly 32 registers instead of, say, 1000?
2. Convert `A[5] = A[3] + 7;` to MIPS (base of A in `$s0`).
3. What is the two's-complement representation of −5 in 8 bits?
4. Encode `add $t1, $s2, $s3` as a 32-bit hex machine instruction.
5. Write MIPS code for: *if (a < b) goto L;* where a is in `$s0`, b in `$s1`.
6. Why does MIPS use PC-relative addressing for branches but pseudodirect for jumps?

---

*Reference: Hennessy & Patterson, Chapter 2 (Sections 2.1–2.8, 2.10)*