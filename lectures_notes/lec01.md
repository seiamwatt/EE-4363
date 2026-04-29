# EE 4363 / CSci 4203 — Lecture 1 Study Guide
## Basics & Impact of Technology

---

## 1. Computers as Data Processors

A computer is fundamentally a **data (information) processor**. To perform any task, two things must be represented in a computer-understandable format:

- **The task** itself (the instructions)
- **The data** to be processed

In classic computing, both are encoded as **strings of bits** (binary digits: 0 and 1).

### How is a bit physically represented?

A bit is stored in a **storage element** connected to a power supply. The element is either **off (0)** or **on (1)**.

### How is data processed?

- Changing bit values is done through **controlled switching**.
- A **switch** can be off (0) or on (1).
- Networks of switches form **functional units**.
- A processor consists of many functional units working together.

### What makes a processor "better"?

Given that all units correctly perform their assigned functionality:

- **Faster** switching/processing
- **Less power hungry** (lower energy consumption)
- **More reliable** operation

The key insight: **"better" switches → "better" processor**.

---

## 2. Dennard Scaling (Ideal Technology Scaling)

**Reference:** Dennard, 1974

Each technology generation (every ~2–3 years), with scaling factor *k* > 1:

| Property | Change per Generation |
|---|---|
| Switching delay | Reduces by **1/k** |
| Area per switch | Reduces by **1/k²** |
| Power per switch | Reduces by **1/k²** |

### Scenario 1: Constant Functionality (same number of switches, N)

- Power consumption of processor → reduces by **1/k²**
- Area of processor → reduces by **1/k²**
- **Power per unit area → remains constant:** (1/k²) / (1/k²) = 1

**Result:** Same functionality at **less area** and **lower power** — no overheating.

### Scenario 2: Constant Area (pack more switches into the same chip area)

- Number of switches → increases by **k²**
- Total power: k² × (1/k²) = **constant**
- **Power per unit area → remains constant:** 1

**Result:** **More functionality** at the **same area and power** — no overheating.

### Key Takeaway of Dennard Scaling

Under ideal scaling, you get a free lunch: either shrink the chip (same function, less power) or keep the chip the same size and add more functionality — all without increasing power density.

---

## 3. The End of Dennard Scaling (Practical Scaling)

In practice, Dennard scaling **broke down**. Modern technology generations see:

- Switching delay **no longer reduces** by 1/k
- Area per switch still reduces by ~1/k²
- Power per switch **no longer reduces** by 1/k²

### Why did it break down?

- Modern transistors (switches) **leak current even when turned off** → **leakage power**
- Leakage power **increases** with each technology generation
- Design optimizations that maintained Dennard scaling had to be abandoned to control leakage

### Consequences

| Scenario | Dennard (Ideal) | Practical |
|---|---|---|
| Constant functionality | Power density constant | Power density **increases** |
| Constant area | Power density constant | Power density **increases** |

Switching delay barely improves, and power per unit area is **no longer constant** — it tends to grow.

---

## 4. Dark Silicon

When you keep chip area constant and pack in k² more switches per generation, but power per switch doesn't scale down properly, you **cannot power all switches simultaneously** without overheating.

- **Total switches** on a chip grow exponentially (Moore's Law)
- **Powered-on switches** grow much more slowly
- The gap between total and powered-on switches is **dark silicon** — transistors that exist on the chip but must remain off at any given time

This is a central challenge in modern processor design.

---

## 5. Moore's Law

Moore's Law (observation, not a physical law): the number of transistors (switches) on a chip **doubles approximately every 2 years**.

This held remarkably well from the 1970s through at least the 2010s (Intel 4004 → Nehalem and beyond). The critical question it raises:

> **How do we make the best use of all these switches?**

---

## 6. The Role of Computer Architecture

### Classic Computer Architecture

How to **translate** the performance boost from improved switching technology **into improved efficiency** at the software layer.

### Modern Computer Architecture

How to **mask the stagnation** in switching technology and still **improve efficiency** at the software layer.

### The Stack

```
Software  (C programs, applications)
   ↕
Architecture  (ISA — the interface)
   ↕
Hardware  (microarchitecture, cores, memory)
```

Key hardware concepts mentioned: fetch, decode, latches, memory, multi-core processors.

---

## 7. Course Outline (Topics Ahead)

1. Impact of Technology *(this lecture)*
2. Instruction Set Architecture (ISA)
3. Microarchitecture
4. Memory Hierarchy Design

---

## 8. Key Terms to Know

| Term | Brief Definition |
|---|---|
| **Bit** | Binary digit; the smallest unit of data (0 or 1) |
| **Switch / Transistor** | Physical device that represents and manipulates bits |
| **Functional unit** | A network of switches that performs a specific operation |
| **Dennard scaling** | Observation that power density stays constant as transistors shrink (ideal) |
| **Leakage power** | Power consumed by a transistor even when it is "off" |
| **Dark silicon** | Transistors on a chip that cannot be powered on simultaneously due to thermal limits |
| **Moore's Law** | Transistor count on a chip doubles roughly every 2 years |
| **Power density** | Power consumption per unit area of the chip |
| **ISA** | Instruction Set Architecture — the interface between software and hardware |
| **Microarchitecture** | The implementation of an ISA in hardware |

---

## 9. Self-Check Questions

1. Why does Dennard scaling imply that power density remains constant?
2. Under constant-area scaling, why does the number of switches increase by k²?
3. What is leakage power, and why does it break Dennard scaling?
4. Explain the concept of dark silicon in your own words.
5. What is the difference between "constant functionality" and "constant area" scaling scenarios?
6. Why is computer architecture more challenging in the post-Dennard era?
7. Define the relationship between Moore's Law and dark silicon.