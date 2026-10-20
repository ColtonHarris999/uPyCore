---
name: isca-figures
description: >-
  Produce paste-ready IEEEtran TikZ figures for the uPyCore (μPyCore) ISCA
  paper. Use when the user asks for a figure, diagram, TikZ picture, memory
  layout, architecture drawing, or LaTeX graphic, including a request that
  only names a block (register file, spill, frame, tag, list, dict, set,
  bytearray, string, object, iterator, accelerator, call). The machine and
  the visual style are in this skill. Do not ask the user to restate either.
---

# ISCA figures for uPyCore

Draw one paste-ready figure. The user should be able to drop it into an IEEEtran conference paper.

## Read first

Read both files next to this skill before drawing or editing a figure:

- `style.md` — column widths, TikZ styles, caption, and output shape
- `architecture.md` — the machine the figure must match

Do not invent a block, a bit field, or a color. If the request disagrees with `architecture.md`, draw the machine in that file and add one sentence after the figure naming the disagreement.

## Where figures live

`docs/paper/figures/`

| File | Label | What it shows |
| --- | --- | --- |
| `overview.tex` | `fig:upycore` | Core, ring, local cache, ALU, string walks, container accelerator, collector, SRAM |
| `regfile.tex` | `fig:regfile` | Growth spill of 8 and the 48-byte chunk |
| `frame.tex` | `fig:frame` | Caller frame and the call snapshot |
| `values.tex` | `fig:value` | 36-bit register and wide values |
| `collections.tex` | `fig:collections` | List, bytearray, dict, set |
| `objects.tex` | `fig:object` | Instance, exception, type, function |
| `strings.tex` | `fig:strings` | `QSTR`, `SHORT_STR`, `STR` |
| `resize.tex` | `fig:resize` | Accelerator dict/set resize |
| `iterables.tex` | `fig:iter` | Tuple, range, `ITER` |

`iscafig.tex` is the shared preamble. `build.tex` compiles all of them.

## When asked for a figure that already exists

Return that file. Change it only if the user asked for a different emphasis. Recompile `build.tex` after any edit.

## When asked for a new figure

1. Add `docs/paper/figures/<name>.tex` as one `figure` or `figure*` environment. No preamble, no `\documentclass`.
2. Use only styles from `iscafig.tex`. New styles go in `iscafig.tex`, not in the figure.
3. Add an `\input` to `build.tex`.
4. Pick a new `\label{fig:...}` that is not already used.
5. Compile from `docs/paper/figures`:

```bash
pdflatex -interaction=nonstopmode build.tex
```

6. Fix overfull boxes and collisions before answering. Render the changed page to check alignment. Labels stay at `\footnotesize` (8 pt in IEEEtran). Do not drop to `\tiny` to force a fit. Widen to `figure*` or split the figure instead.

## What to hand back

The reply contains the figure environment in one `latex` block, the `\label`, and the sentence that should cite it (`Fig.~\ref{fig:...}`). State that `iscafig.tex` is pasted once into the preamble if this is the first figure.
