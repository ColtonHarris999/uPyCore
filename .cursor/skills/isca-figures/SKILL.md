---
name: isca-figures
description: >-
  Produce a paste-ready IEEEtran TikZ figure for the uPyCore (μPyCore) ISCA
  paper. Use when the user asks for a figure, diagram, TikZ picture, memory
  layout, architecture drawing, or LaTeX graphic, including a request that
  only names a block (register file, spill, frame, tag, list, dict, set,
  bytearray, string, object, iterator, accelerator, call). Reply with the
  LaTeX in plain text and a rendered image. Do not add or edit figure files
  in the repo. The machine and the visual style are in this skill. Do not
  ask the user to restate either.
---

# ISCA figures for uPyCore

The paper lives outside this repo. Answer with the figure as plain text and a rendered drawing, so the user can approve it or critique it. Then stop.

## Read first

Read both files next to this skill before drawing:

- `style.md` — column widths, TikZ styles, caption, and what the reply contains
- `architecture.md` — the machine the figure must match

Do not invent a block, a bit field, or a color. If the request disagrees with `architecture.md`, draw the machine in that file and add one sentence after the image naming the disagreement.

## Do not write the figure into the repo

`docs/paper/figures/` is a progress gallery. Those files are placeholders. They are not the paper, and they are not the reply.

- Do not add, edit, or delete files under `docs/paper/figures/`.
- Do not update `build.tex`.
- Do not commit a `.tex`, `.pdf`, or `.png` of the figure.
- Do not tell the user to `\input` a path in this repo. Their paper cannot see it.

Draw from `architecture.md` and `style.md`. A placeholder with the same subject is not the answer to return.

## Render outside the repo

Compile a throwaway driver in a temp directory, then show the PNG.

```bash
mkdir -p /tmp/isca-fig
# write /tmp/isca-fig/fig.tex as a complete IEEEtran document:
#   \documentclass[conference]{IEEEtran}
#   \usepackage{amsmath,amssymb,amsfonts,graphicx,xcolor}
#   \input{<absolute path to this repo>/docs/paper/figures/iscafig.tex}
#   \begin{document}
#   <the figure environment>
#   \end{document}
pdflatex -interaction=nonstopmode -output-directory /tmp/isca-fig /tmp/isca-fig/fig.tex
pdftoppm -png -r 140 -f 1 -l 1 /tmp/isca-fig/fig.pdf /tmp/isca-fig/fig
```

`\input` of `iscafig.tex` is only for this temp compile. Fix overfull boxes and collisions before answering. Labels stay at `\footnotesize` (8 pt in IEEEtran). Do not drop to `\tiny` to force a fit. Widen to `figure*` or split the figure instead.

Show the PNG in the reply. When `/opt/cursor/artifacts/` exists, copy the PNG there and use an HTML image tag with that absolute path. Otherwise show the PNG from the temp directory.

## What the reply contains

1. One `latex` block with the figure environment only. No preamble, no `\documentclass`, no comments about the repo. This is what they paste into the paper.
2. The rendered image.
3. On the first figure of the conversation, a second `latex` block with the full contents of `docs/paper/figures/iscafig.tex`, introduced as the preamble to paste once. Skip it on a revision of a figure that already uses those macros.

Nothing else, except the one sentence required when the request disagrees with `architecture.md`.
