# CLAUDE.md — RISC-V 5-Stage Pipelined CPU

This file is the source of truth for anyone (human or AI assistant) working on this project. Read it fully before changing any code.

---

## 1. Project goal

Build a **5-stage pipelined RV32I processor** in Verilog with data forwarding, load-use stall detection, branch resolution in Decode, and two set-associative caches (I-cache and D-cache) with LRU replacement and critical-word-first refill. Verify it with a **directed, self-checking testbench** and run official `riscv-tests` for a reported pass count.

**Target outcome:** a resume-grade project that can be explained line by line in an interview, with measured results.

**Explicit non-goals (do not add without discussion):**
- UVM or any SystemVerilog class-based verification framework
- CSRs, traps, interrupts, privilege modes
- The M (multiply/divide) extension
- Superscalar or out-of-order execution
- FPGA board bring-up (`cpu.v`, `uart_trans.v`, `mem_ctrl.v` are out of scope for simulation work)

---

## 2. Architecture

| Stage | Module | Responsibility |
|---|---|---|
| IF | `stage_if.v` | Issue instruction fetch to I-cache, hold PC on stall, insert bubble after taken branch (`waiting_one`) |
| IF/ID | `reg_if_id.v` | Pipeline register; holds on stall, bubbles on flush |
| ID | `stage_id.v` | Decode, immediate generation, register read, forwarding mux selection, load-use detection, branch comparison |
| ID/EX | `reg_id_ex.v` | Pipeline register |
| EX | `stage_ex.v` | ALU, branch target, load/store address computation |
| EX/MEM | `reg_ex_mem.v` | Pipeline register |
| MEM | `stage_mem.v` | D-cache request issue and completion, load byte/halfword extraction and extension, store byte-lane selection |
| MEM/WB | `reg_mem_wb.v` | Pipeline register |
| WB | (in `riscv_cpu.v`) | Writes result to register file |

**Supporting modules:**
- `reg_pc.v` — program counter
- `regfile.v` — 32 × 32-bit registers, `x0` hardwired to zero, write on posedge, combinational read
- `ctrl.v` — priority encoder turning per-stage stall requests into the 6-bit stall vector
- `cache.v` — set-associative cache (parameters `INDEX_BIT`, `WORD_SELECT_BIT`, `NASSOC`), LRU tournament tree, critical-word-first refill
- `simple_ram.v` — backing RAM with per-byte write enables
- `defines.v` — all opcodes, funct3/funct7, ALU op codes, bus widths (the single source of naming)
- `utility.v` — `` `CLOG2 `` macro (ceil log2), used for width calculation

**Simulation harness:**
- `root_sim_top.v` — instantiates `riscv_cpu` and `root_sim_memory` (a behavioral two-channel memory, 4 KB; the program is written by `write_word` calls in an `initial` block, not loaded with `$readmemh`)
- `root_cpu_tb.v` — directed, self-checking testbench. Runs for 500 cycles, checks registers and memory, calls `$fatal` on mismatch.
- `trace_tb.v`, `trace2_tb.v`, `trace3_tb.v` — debug-only trace benches, not part of the regression

**Not part of this project's simulation path (legacy, ignore):**
- `sim_cpu.v`, `sim_mem.v`, `test_bench.v`, `pipeline_tb.v` — Zhekai Zhang's UART-based harness and an older project's testbench. They reference `cpu`, `Pipeline_top`, and absolute Windows paths. Do not use them for verification.
- `Pipeline_Top.v` and the Project 1 files (`ALU.v`, `Decode_Cyle.v`, etc.) belong to a separate, earlier design. Do not mix them with this build.

---

## 3. Verified behavior (as of last run)

The following passes in `root_cpu_tb.v`:
- `addi`, `add`
- `sw` to `0x100`, `lw` from `0x100`, with a load-use dependency
- taken `beq` (skips one instruction)

`test/alu_ctrl_mem_tb.v` (run by `test/run_regression.sh`, 24 register checks) also passes:
- `sub`, `and`, `or`, `xor`, `andi`, `ori`, `xori` (negative immediates), `slli`, `srli`, `srai`
- `slt`, `sltu`, `slti`, `sltiu`
- `lui`, `auipc`
- `bne`, `blt`, `bge`, `bltu`, `bgeu` taken; `beq` not taken; `jal` (skip + link value)
- `sw`, then `lh`/`lhu` at offset 2, `lb` at offset 3, `lbu` at offset 0

Passing these tests is **not** evidence that other instructions work. Treat every instruction not listed here as untested.

Update this section every time a new test passes.

---

## 4. Known bugs

**Fixed (do not reintroduce):**

| Bug | File | Fix |
|---|---|---|
| Typo `dcache_donea` (undeclared, silent phantom wire) | `riscv_cpu.v` | Corrected to `dcache_done` |
| PC reset value `4` skipped instruction at address 0 | `reg_pc.v` | Reset to `0` |
| `andi`/`ori`/`xori` zero-extended the immediate | `stage_id.v` | Sign-extend with `{{20{I_imm[11]}}, I_imm}` |
| `lh` at byte offset 2 took sign bit from `[15]` | `stage_mem.v` | Use `mem_data_i[31]` |
| Blocking/nonblocking mismatch in combinational logic | `regfile.v`, `cache.v` | Use `=` in `always @(*)`, `<=` in clocked blocks |
| Latch / unassigned outputs in `stage_if.v` | `stage_if.v` | Refactored: `waiting_one` and `mem_taking` are flip-flops, `next_*` computed combinationally |
| `mem_taking` multi-driver (combinational and clocked blocks both assigned it) | `stage_mem.v` | `SET_MEM_INST` and default case now drive `next_mem_taking` only |

**Open — known from code review, not yet tested:**

| Bug | File | Notes |
|---|---|---|
| `mem_done` declared but unused in `stage_if.v` / `stage_mem.v` | `stage_if.v`, `stage_mem.v` | Architectural; fix when touching the handshake |
| `cache.v` `CLOG2` returns -1 for index 0 in `one_hot_lookup` | `cache.v`, `utility.v` | Harmless because lookup is gated; document or guard |
| Missing include guard | `utility.v` | Add `` `ifndef `` guard like `defines.v` |
| `rd`/`rs`/`rt` declared with `RegBus` (32-bit) instead of `RegAddrBus` | `stage_id.v` | Cosmetic width issue |
| Branches on `funct3` ignore non-`beq` variants in some paths | `stage_id.v` | Verify with directed tests |

---

## 5. Test plan (the path to a credible project)

Run tests in this order. Each test must pass before moving to the next.

**Tier A — ALU (R-type and I-type)**
- `add`, `sub`, `addi`, `and`, `or`, `xor`, `andi`, `ori`, `xori`
- `sll`, `srl`, `sra`, `slli`, `srli`, `srai` (check shift amount masking to 5 bits)
- `slt`, `sltu`, `slti`, `sltiu` (including negative numbers and `sltiu` with immediate `1`)

**Tier B — Control flow**
- `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, both taken and not taken
- `jal`, `jalr` (link register value and target)
- `lui`, `auipc`

**Tier C — Memory**
- `lw`, `sw` at multiple addresses and two different cache blocks (forces a D-cache refill)
- `lb`, `lbu`, `lh`, `lhu` at all byte offsets
- `sb`, `sh` at all byte offsets, verify neighbouring bytes are untouched
- Load-use hazard for each load width

**Tier D — Pipeline hazards**
- ALU→ALU forwarding at distance 1, 2, 3
- Load→use at distance 1 (stall) and 2 (no stall)
- Branch immediately after an ALU producer and after a load producer
- Writes to `x0` are discarded
- Back-to-back taken branches

**Tier E — Cache**
- I-cache miss on first fetch of a new block
- D-cache hit after miss in the same block
- D-cache eviction when NASSOC+1 blocks map to one index

**Tier F — Official suite**
- `riscv-tests` `rv32ui-p-*` tests (ALU, branch, jump, load/store). Report the pass count.

**Tier G — Real program**
- A sort or Fibonacci compiled with a RISC-V GCC toolchain, with a checkable result in memory.

**Tier H — Measurement**
- CPI, stall cycles per hazard type, D-cache and I-cache hit rates, for the Tier G program.

**Tier I — Synthesis**
- Yosys area and max frequency, reported with the target library.

---

## 6. Working rules

1. **Never claim an instruction works without a test that exercises it.** Code review is not verification.
2. **Run the full regression after every change**, not just the new test. Regressions have already happened in this project.
3. **One bug per change where possible.** Make the smallest edit that fixes the failing test, then rerun.
4. **Single driver per `reg`.** Any signal assigned in more than one `always` block is a bug. Check with `grep -n "^\s*reg " *.v` when refactoring.
5. **Blocking `=` in `always @(*)`, nonblocking `<=` in `always @(posedge clk)`.** No exceptions.
6. **Every combinational `always @(*)` must assign every output on every path**, using defaults at the top of the block.
7. **Don't weaken a test to make it pass.** If a test fails, the design or the test expectation is wrong, and you find out which before changing either.
8. **Keep `defines.v` as the only place opcode and funct values are written.** No magic numbers in stage logic.
9. **Document attribution.** `cache.v` and `utility.v` are based on Zhekai Zhang's code. Say so in the README and do not present them as original.
10. **No UVM, no SystemVerilog verification classes.** The testbench stays directed Verilog.

---

## 7. Commands

Full regression (ModelSim ASE, from `test/`; `iverilog` is not installed on this machine, and Questa FSE has no license):
```bash
cd test && ./run_regression.sh
```

Generic iverilog flow (paths relative to `src/cpu`, testbench files live in `test/`):

Compile the regression (excludes legacy files and the duplicate `simple_ram.v` include):
```bash
iverilog -g2005 -o sim \
  defines.v utility.v cache.v ctrl.v reg_pc.v stage_if.v reg_if_id.v stage_id.v \
  regfile.v reg_id_ex.v stage_ex.v reg_ex_mem.v stage_mem.v reg_mem_wb.v riscv_cpu.v \
  root_sim_top.v root_cpu_tb.v
vvp sim
```

Check for multi-driver regs:
```bash
grep -n "^\s*reg " *.v
```

---

## 8. Resume wording (fill in only after measured)

Only claim what has been tested and measured:

> Implemented a 5-stage pipelined RISC-V (RV32I) core in Verilog with data forwarding, load-use stall detection, and two-way/four-way set-associative caches with LRU replacement. Verified with a directed self-checking testbench passing N/M instructions from `riscv-tests`; measured CPI of X on [program]; synthesized to Y MHz on [target] using Yosys.

Do not claim UVM, do not claim a feature listed under "Explicit non-goals," and do not claim any instruction that is in the untested list above until a test exercises it.
