# MIPS Instruction Set Architecture — Study Notes

## 1. Instruction Sets Overview

An instruction set is the complete repertoire (vocabulary) of instructions a computer can execute. Different computers have different instruction sets, but many share common aspects. MIPS is an example of a simple, regular instruction set — simplicity in design leads to easier and faster hardware implementation.

## 2. Arithmetic Instructions

Each arithmetic instruction performs one operation on exactly three operands — two sources and one destination.

```
add a, b, c    # a ← b + c
sub a, b, c    # a ← b - c
```

> **Design Principle 1:** Simplicity favors regularity — a fixed number of operands keeps hardware simple.

### Compilation Example

**C:** `f = (g + h) - (i + j);`

```mips
add $t0, $s1, $s2    # t0 = g + h
add $t1, $s3, $s4    # t1 = i + j
sub $s0, $t0, $t1    # f = t0 - t1
```

## 3. Register Operands

- MIPS has a **32 × 32-bit register file** (registers numbered 0–31).
- A 32-bit chunk of data is called a **word**.
- Registers are faster than memory — the compiler should maximize their use.

### Register Naming

| Name | Reg # | Purpose |
|------|-------|---------|
| `$t0`–`$t7` | 8–15 | Temporary values |
| `$t8`–`$t9` | 24–25 | More temporaries |
| `$s0`–`$s7` | 16–23 | Saved variables |
| `$zero` | 0 | Hardwired to 0 |

> **Design Principle 2:** Smaller is faster — a small register file can be accessed more quickly.

### The Constant Zero (`$zero`)

Register 0 always reads as zero and cannot be overwritten. Useful for moves:

```mips
add $t2, $s1, $zero    # $t2 = $s1
```

## 4. Memory Operands

Main memory holds composite data (arrays, structures). To operate on memory data you must load into a register, compute, then store back.

- Memory is **byte-addressed** (each address = 1 byte).
- Words are **aligned**: addresses must be multiples of 4.
- MIPS is **Big Endian**: most-significant byte at the lowest address.

### Load/Store Syntax

```mips
lw $t0, offset($base)    # load word
sw $t0, offset($base)    # store word
```

### Example 1

**C:** `g = h + A[8];` (g→`$s1`, h→`$s2`, base of A→`$s3`)

```mips
lw  $t0, 32($s3)      # offset = 8 × 4 = 32
add $s1, $s2, $t0
```

### Example 2

**C:** `A[12] = h + A[8];`

```mips
lw  $t0, 32($s3)      # load A[8]
add $t0, $s2, $t0     # h + A[8]
sw  $t0, 48($s3)      # store to A[12], offset = 12 × 4
```

### Registers vs. Memory

Registers are faster; memory access requires extra load/store instructions. The compiler should keep frequently used variables in registers and only spill to memory when necessary.

## 5. Immediate Operands

Constants embedded directly in the instruction avoid a separate load.

```mips
addi $s3, $s3, 4       # $s3 += 4
addi $s2, $s1, -1      # no subi; use negative constant
```

> **Design Principle 3:** Make the common case fast — small constants are very common.

## 6. Number Representation

### Unsigned Binary

n-bit range: **0** to **2ⁿ − 1**. With 32 bits: 0 to 4,294,967,295.

### Two's Complement Signed

n-bit range: **−2ⁿ⁻¹** to **+2ⁿ⁻¹ − 1**. With 32 bits: −2,147,483,648 to +2,147,483,647.

Key values:

- Bit 31 = sign bit (1 = negative, 0 = non-negative)
- Zero: `0000…0000`
- −1: `1111…1111`
- Most negative: `1000…0000`
- Most positive: `0111…1111`

### Signed Negation

Complement all bits and add 1.

```
+2 = 0000 0000 … 0010
     1111 1111 … 1101  (complement)
+                    1
−2 = 1111 1111 … 1110
```

### Sign Extension

Represent a number with more bits while preserving value. Signed → replicate sign bit to the left. Unsigned → extend with zeros. Used by `addi`, `lb`, `lh`.

## 7. Representing Instructions (Machine Code)

Instructions are encoded as 32-bit binary words. MIPS uses a small number of formats.

### Hexadecimal

Base-16: each hex digit = 4 bits. Example: `0xECA86420` = `1110 1100 1010 1000 0110 0100 0010 0000`

## 8. Instruction Formats

### R-format (Register)

For register-to-register arithmetic/logic.

| op (6) | rs (5) | rt (5) | rd (5) | shamt (5) | funct (6) |
|--------|--------|--------|--------|-----------|-----------|

- **op** = 0 for all R-type
- **rs** = first source, **rt** = second source, **rd** = destination
- **shamt** = shift amount (0 for non-shifts)
- **funct** = identifies specific operation

**Example:** `add $t0, $s1, $s2` → op=0, rs=17, rt=18, rd=8, shamt=0, funct=32 → Hex `0x02324020`

### I-format (Immediate)

For immediate arithmetic, loads, stores, branches.

| op (6) | rs (5) | rt (5) | constant/address (16) |
|--------|--------|--------|-----------------------|

- Constant range: −32,768 to +32,767
- For loads/stores the 16-bit field is an offset added to base register `rs`

> **Design Principle 4:** Good design demands good compromises — different formats complicate decoding but keep all instructions uniformly 32 bits.

## 9. Stored Program Concept

Instructions are binary data stored in memory, just like other data. This allows programs to operate on programs (compilers, linkers) and enables binary compatibility across machines with the same ISA.

## 10. Logical Operations

| Operation | C | MIPS |
|-----------|---|------|
| Shift left | `<<` | `sll` |
| Shift right | `>>` | `srl` |
| Bitwise AND | `&` | `and`, `andi` |
| Bitwise OR | `\|` | `or`, `ori` |
| Bitwise NOT | `~` | `nor` with `$zero` |

### Shifts

- `sll` by *i* = multiply by 2ⁱ
- `srl` by *i* = divide by 2ⁱ (unsigned only)

**AND** = Masking (select bits, clear others)
**OR** = Unmasking (set bits to 1, leave others)

### NOT via NOR

```mips
nor $t0, $t1, $zero    # NOT $t1 (since a NOR 0 = NOT a)
```

## 11. Conditional Operations

### Branches

```mips
beq rs, rt, L1    # branch if equal
bne rs, rt, L1    # branch if not equal
j   L1            # unconditional jump
```

### Set on Less Than

```mips
slt  rd, rs, rt        # rd = (rs < rt) ? 1 : 0   (signed)
slti rt, rs, const     # rt = (rs < const) ? 1 : 0 (signed)
sltu / sltiu           # unsigned versions
```

**Pattern for "branch if less than":**

```mips
slt $t0, $s1, $s2
bne $t0, $zero, L      # branch to L if $s1 < $s2
```

### Why no `blt`/`bge`?

Hardware for `<`/`≥` is slower than `=`/`≠`. A combined compare-and-branch would slow the clock for all instructions. `beq`/`bne` are the common case — keep them fast.

### Signed vs. Unsigned Comparison Example

`$s0` = `0xFFFFFFFF`, `$s1` = 1:

- `slt` → −1 < 1 → result = **1**
- `sltu` → 4,294,967,295 > 1 → result = **0**

**Array bounds trick:** `sltu index, size` checks both non-negative and less-than-size in one instruction.

## 12. Loading 32-bit Constants

```mips
lui $s0, 61          # load 61 into upper 16 bits, lower 16 = 0
ori $s0, $s0, 2304   # OR in the lower 16 bits
```

## 13. Addressing Modes

### PC-Relative (Branches)

**Target** = PC + offset × 4
16-bit offset field; PC already incremented by 4.

### Pseudodirect (Jumps)

**Target** = PC\[31:28\] : (address × 4)
26-bit address field in J-format.

### Branching Far Away

If target too far, assembler rewrites:

```mips
beq $s0, $s1, L1  →  bne $s0, $s1, L2
                      j L1
                  L2: ...
```

### All Five Modes

1. **Immediate** — operand is a constant in the instruction
2. **Register** — operand is in a register
3. **Base/Displacement** — memory address = register + offset
4. **PC-relative** — branch target = PC + offset × 4
5. **Pseudodirect** — jump target = PC upper bits concatenated with address × 4

## 14. Design Principles Recap

1. **Simplicity favors regularity** — fixed size, three-operand format
2. **Smaller is faster** — small register file
3. **Make the common case fast** — immediate operands, simple branches
4. **Good design demands good compromises** — multiple formats, uniform 32-bit width