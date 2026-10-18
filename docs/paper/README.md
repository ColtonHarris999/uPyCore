# Paper / systems documentation

Near-complete PyCore subsystems get a LaTeX note here so we can pull prose,
figures, and tradeoff tables into the research paper without mining RTL comments
or planning markdown.

## Layout

| Path | Topic |
| --- | --- |
| `systems/call_fsm.tex` | `S_CALL` FSM, shared argument binder, CPython call shapes |
| `systems/upycore_architecture.tex` | uPyCore system and subsystem diagrams: build flow, SoC, core and hook dispatch, frames, memory map, value tags, heap objects, ALU/FPU, GC, IRQ/peripherals, verification |

## Build

```bash
cd docs/paper/systems
pdflatex call_fsm.tex
pdflatex call_fsm.tex   # TOC
pdflatex upycore_architecture.tex && pdflatex upycore_architecture.tex
```

Needs a TeX distribution with `tikz`, `booktabs`, `hyperref`, `listings`,
`geometry`, `microtype` (`upycore_architecture.tex` also uses `caption`, `float`,
and the TikZ `shapes.misc` / `patterns` libraries).

## Conventions

- One subsystem per `.tex` file under `systems/` (or a future `excore/`, etc.).
- Prefer diagrams that match RTL names (`call_phase_r`, binder subs) so the note
  stays a faithful companion to the code.
- Link the living opcode matrix (`pycore/docs/bytecode_support.md`) rather than
  duplicating support status that churns weekly.
- Remaining work lives in `planning/master_plan.md`, not in these notes.
