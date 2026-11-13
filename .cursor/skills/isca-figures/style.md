# Figure style

IEEEtran conference, two columns. Captions sit under the figure. The class writes the number, so the caption text does not start with "Figure".

## Fit

| Environment | Use when | Maximum content width |
| --- | --- | --- |
| `figure` | One column | 8.6 cm |
| `figure*` | Both columns, top of the page | 17.6 cm |

Placement is `[t]`. Do not use `[h]`, `\centerline`, or `\resizebox` to shrink a picture. If it does not fit, remove a label or switch to `figure*`.

Body font inside the picture is `\footnotesize` (8 pt). Secondary notes use the `lbl` style (`\scriptsize`). Never `\tiny`, and never a style named `cap` (`cap` is TikZ's line-cap key).

## Palette

Defined in `docs/paper/figures/iscafig.tex`. Meaning is fixed:

| Style | Fill | Use |
| --- | --- | --- |
| `core` / `fldcore` | blue | Blocks that execute bytecode, and ordinary values |
| `mem` / `fldmem` | green | Storage and pointers |
| `accel` / `fldacc` | amber | Container accelerator, `CONT` words, tags |
| `imm` / `fldimm` | slate | Immediates, counts, control |
| `hot` / `fldhot` | rose | Links, kinds, the object bit, ring metadata |
| `fre` | white, dashed | A free register |

Every box has a text label. Color is not the only encoding. Do not add shadows, gradients, 3D, rounded corners, or a new hue.

Arrows use the `arr` or `thinarr` style. No decorations other than a brace for a bit range or a span.

## Memory-map rows

Use `\rec{y}{offset}{style}{width}{text}`.

- `y` decreases by 0.52 cm or 0.55 cm per word.
- Offset is the byte offset, in `\scriptsize` typewriter, to the left of the box.
- One word is one row. Do not merge two words onto one row unless the caption says the row is a range and the offset is the first byte.

## Register ring

`\rfslot{prefix}{physical}{style}{text}` and `\rfnums`. Eight columns. Physical 0–7 on the first row, 8–15 on the second. Physical indices are the small numbers above the cells.

## Captions

Two to five sentences. Define `$sp$` and `$sb$` in the caption of any figure that uses them. Name the encoding (`RF_LINK`, `MUT_COLLEC`) in typewriter. Use `\upycore` for the core name. Green means pointer when the figure contains pointers. Say so once in that caption.

## Preamble

The styles live in `docs/paper/figures/iscafig.tex` in this repo. The temp compile may `\input` that file. The user's paper is outside the repo, so the reply never tells them to `\input` it. On the first figure of the conversation, the reply includes the file's full text as a second latex block, labeled as the preamble to paste once. A later revision of the same figure omits that block.

## What the latex block contains

The block they paste into the paper is the figure environment only:

```latex
\begin{figure}[t] % or figure*
\centering
\begin{tikzpicture}[iscafig]
  ...
\end{tikzpicture}
\caption{...}
\label{fig:name}
\end{figure}
```

No `\documentclass`, no `\input`, no comments, no title, no bibliography. The rendered PNG is a separate image in the reply, not a file in the repo.
