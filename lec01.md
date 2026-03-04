# EE 4363 / CSci 4203 — Lecture 01: Basics & Impact of Technology

**Prof. Ulya Karpuzcu**

---

## Computer as a Data Processor

A computer is fundamentally a data (information) processor. To perform any task, both the task itself and the data must be represented in a computer-understandable format.

In classic computing, data is encoded as strings of **bits** (binary digits). A bit is physically represented by a storage element connected to a power supply — *off* represents 0, *on* represents 1.

Processing data means changing bit values through controlled switching. Networks of switches form functional units, and a processor is composed of many functional units.

A "better" processor means: **faster**, **less power hungry**, and/or **more reliable** — provided correctness is maintained. Better switches lead to a better processor.

---

## Dennard Scaling (1974)

Each technology generation (every 2–3 years), where *k* is a constant greater than 1:

- Switching delay reduces by 1/*k*
- Area per switch reduces by 1/*k*²
- Power consumption per switch reduces by 1/*k*²

### Case 1 — Constant Functionality (same number of switches *N*)

- Total power reduces by 1/*k*²
- Total area reduces by 1/*k*²
- Power per unit area stays constant: (1/*k*²) / (1/*k*²) = 1
- **Result:** Same functionality at less area and lower power

### Case 2 — Constant Area (pack more switches into the same chip area)

- Number of switches increases by *k*²
- Total power stays constant: *k*² × (1/*k*²) = 1
- Power per unit area stays constant
- **Result:** More functionality at the same area and power

In both cases, there is no thermal runaway ("no burning the machine").

---

## Practical Scaling (Post-Dennard Era)

In reality, Dennard scaling has broken down:

- Switching delay **no longer** reduces by 1/*k*
- Area per switch **still** reduces by 1/*k*²
- Power per switch **no longer** reduces by 1/*k*²

**Why?** Modern transistors leak current even when turned off, consuming leakage power on top of switching power. Leakage power increases over technology generations. Physical design optimizations that enabled Dennard scaling had to be abandoned to control leakage.

### Implications

- Switching delay barely improves across generations
- Power per unit area is no longer constant — it tends to **increase**
- **Case 1 (Constant Functionality):** Power per unit area tends to increase because power drops by less than 1/*k*² while area still drops by 1/*k*².
- **Case 2 (Constant Area):** Power per unit area also tends to increase because total power grows (*k*² × something greater than 1/*k*²).

---

## Dark Silicon

With constant chip area, the number of transistors keeps growing (Moore's Law), but the number that can be simultaneously powered on grows much more slowly. The gap between total switches and powered-on switches is called **"dark silicon"** — transistors that must remain off to avoid overheating.

Over time, the fraction of the chip that stays dark increases.

---

## Moore's Law

The number of transistors on a chip roughly doubles every ~2 years. This trend held from the Intel 4004 (1971, ~2,300 transistors) through processors with billions of transistors. The central question becomes: *how to make the best use of all these switches?*

---

## Computer Architecture — The Big Picture

The system is organized in layers:

> **Software → Architecture → Hardware** (Microarchitecture → Logic/Circuits)

- **Architecture** defines the interface (instruction set) between software and hardware.
- **Microarchitecture** is the hardware implementation of that interface (fetch, decode, execute pipeline, cores, memory hierarchy).
- **Classic computer architecture** asked: how to translate improved switching technology into improved software efficiency?
- **Modern computer architecture** asks: how to mask the stagnation in switching technology while still improving software efficiency?

---

## Course Outline

1. Impact of Technology
2. Instruction Set Architecture (ISA)
3. Microarchitecture
4. Memory Hierarchy Design