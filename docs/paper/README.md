# Paper / systems documentation

Near-complete PyCore subsystems get a LaTeX note here so we can pull prose,
figures, and tradeoff tables into the research paper without mining RTL comments
or planning markdown.

## Layout

| Path | Topic |
| --- | --- |
| `systems/call_fsm.tex` | `S_CALL` FSM, shared argument binder, CPython call shapes |
| `figures/iscafig.tex` | Shared TikZ style used by the progress gallery and by the temp render |
| `figures/*.tex` | Progress placeholders. The paper is outside this repo; the `isca-figures` skill does not add to this directory |

## Build

```bash
cd docs/paper/systems
pdflatex call_fsm.tex
pdflatex call_fsm.tex   # TOC

cd docs/paper/figures
pdflatex build.tex
```

Needs a TeX distribution with `IEEEtran`, `tikz`, `booktabs`, `hyperref`,
`listings`, `geometry`, `microtype`.

`build.tex` compiles the progress gallery. It is not the paper. The
`isca-figures` skill returns LaTeX in the reply and a rendered image, and
does not write figures here.

## Conventions

- One subsystem per `.tex` file under `systems/` (or a future `excore/`, etc.).
- Prefer diagrams that match RTL names (`call_phase_r`, binder subs) so the note
  stays a faithful companion to the code.
- Link the living opcode matrix (`pycore/docs/bytecode_support.md`) rather than
  duplicating support status that churns weekly.
- Remaining work lives in `planning/master_plan.md`, not in these notes.
