#!/usr/bin/env python3
"""Minimal STA over a Yosys JSON netlist (see run.py, which drives it).

Usage: sta_lite.py netlist.json liberty.lib [groups]

Flops are FFBOX cells (C, D, Q). Arrival at Q = CLKQ; each endpoint is an
FFBOX D (plus SETUP) or a module output. Cell delay and output slew come
from the liberty NLDM tables (input transition x output load), worst of
rise/fall, worst over arcs; load = sum of fanout pin capacitances (no wire).
A net driving more than CMAX gets a fanout-4 buffer tree. Yosys's simple
gates ($_AND_ ...) are timed as the matching sky130 cells. Endpoints are
grouped by RTL register name; each line names the start of its worst path.
TRACE=<regex> prints the named nets on the worst path into that group;
INPUTS_ONLY=1 times only paths from module inputs.
"""
import json, re, sys, bisect, os
from collections import defaultdict

CLKQ, SETUP, IN_SLEW, FF_DCAP = 0.33, 0.12, 0.05, 0.0017
# Yosys internal gates -> a sky130 cell and pin map (unmapped netlists).
GATES = {
    '$_AND_': ('sky130_fd_sc_hd__and2_1', {'A': 'A', 'B': 'B', 'Y': 'X'}),
    '$_OR_': ('sky130_fd_sc_hd__or2_1', {'A': 'A', 'B': 'B', 'Y': 'X'}),
    '$_XOR_': ('sky130_fd_sc_hd__xor2_1', {'A': 'A', 'B': 'B', 'Y': 'X'}),
    '$_XNOR_': ('sky130_fd_sc_hd__xnor2_1', {'A': 'A', 'B': 'B', 'Y': 'Y'}),
    '$_NAND_': ('sky130_fd_sc_hd__nand2_1', {'A': 'A', 'B': 'B', 'Y': 'Y'}),
    '$_NOR_': ('sky130_fd_sc_hd__nor2_1', {'A': 'A', 'B': 'B', 'Y': 'Y'}),
    '$_ANDNOT_': ('sky130_fd_sc_hd__and2b_1', {'A': 'B', 'B': 'A_N', 'Y': 'X'}),
    '$_ORNOT_': ('sky130_fd_sc_hd__or2b_1', {'A': 'A', 'B': 'B_N', 'Y': 'X'}),
    '$_MUX_': ('sky130_fd_sc_hd__mux2_1', {'A': 'A0', 'B': 'A1', 'S': 'S', 'Y': 'X'}),
    '$_NOT_': ('sky130_fd_sc_hd__inv_1', {'A': 'A', 'Y': 'Y'}),
    '$_BUF_': ('sky130_fd_sc_hd__buf_1', {'A': 'A', 'Y': 'X'}),
}
BUF = 'sky130_fd_sc_hd__buf_4'
CMAX = 0.03   # pF a gate drives before a buffer tree (repair_design-like)

def parse_lib(path, wanted):
    txt = open(path).read()
    cells = {}
    for m in re.finditer(r'\n\s*cell\s*\(\s*"?([\w]+)"?\s*\)\s*\{', txt):
        name = m.group(1)
        if name not in wanted:
            continue
        # cell body: brace matching
        i = m.end(); depth = 1
        while depth:
            c = txt[i]
            if c == '{': depth += 1
            elif c == '}': depth -= 1
            i += 1
        body = txt[m.end():i]
        cells[name] = parse_cell(body)
    return cells

def groups(body, kind):
    out = []
    for m in re.finditer(r'\b' + kind + r'\s*\(\s*"?([^")]*)"?\s*\)\s*\{', body):
        i = m.end(); depth = 1
        while depth:
            c = body[i]
            if c == '{': depth += 1
            elif c == '}': depth -= 1
            i += 1
        out.append((m.group(1), body[m.end():i - 1]))
    return out

def table(body, kind):
    for name, b in groups(body, kind):
        i1 = [float(x) for x in re.search(r'index_1\s*\(\s*"([^"]*)"', b).group(1).split(',')]
        i2 = [float(x) for x in re.search(r'index_2\s*\(\s*"([^"]*)"', b).group(1).split(',')]
        vals = re.search(r'values\s*\((.*?)\)\s*;', b, re.S).group(1)
        rows = [[float(x) for x in r.split(',')] for r in re.findall(r'"([^"]*)"', vals)]
        return (i1, i2, rows)
    return None

def parse_cell(body):
    pins = {}
    for pname, pb in groups(body, 'pin'):
        cap = re.search(r'\bcapacitance\s*:\s*([\d.eE+-]+)', pb)
        arcs = []
        for _, tb in groups(pb, 'timing'):
            rp = re.search(r'related_pin\s*:\s*"([^"]*)"', tb)
            if not rp:
                continue
            tt = re.search(r'timing_type\s*:\s*"?(\w+)', tb)
            if tt and tt.group(1) not in ('combinational', 'combinational_rise', 'combinational_fall'):
                continue
            arcs.append((rp.group(1), [table(tb, k) for k in ('cell_rise', 'cell_fall')],
                         [table(tb, k) for k in ('rise_transition', 'fall_transition')]))
        pins[pname] = (float(cap.group(1)) if cap else 0.0, arcs)
    return pins

def interp(t, x, y):
    if t is None:
        return 0.0
    i1, i2, v = t
    def idx(a, q):
        k = bisect.bisect_left(a, q)
        k = min(max(k, 1), len(a) - 1)
        return k - 1, k
    a0, a1 = idx(i1, x); b0, b1 = idx(i2, y)
    fx = (x - i1[a0]) / (i1[a1] - i1[a0]) if i1[a1] != i1[a0] else 0
    fy = (y - i2[b0]) / (i2[b1] - i2[b0]) if i2[b1] != i2[b0] else 0
    v00, v01, v10, v11 = v[a0][b0], v[a0][b1], v[a1][b0], v[a1][b1]
    return (v00 * (1 - fx) * (1 - fy) + v01 * (1 - fx) * fy + v10 * fx * (1 - fy) + v11 * fx * fy)

def main():
    netlist, lib = sys.argv[1], sys.argv[2]
    top_n = int(sys.argv[3]) if len(sys.argv) > 3 else 25
    mods = json.load(open(netlist))['modules']
    top = next(n for n, m in mods.items() if m.get('attributes', {}).get('top'))
    m = mods[top]
    cells = m['cells']
    for c in cells.values():
        g = GATES.get(c['type'])
        if g:
            lib_cell, pm = g
            c['type'] = lib_cell
            c['connections'] = {pm[p]: b for p, b in c['connections'].items()}
            c['port_directions'] = {pm[p]: ('output' if p == 'Y' else 'input') for p in pm}
        elif c['type'] != 'FFBOX' and not c['type'].startswith('sky130'):
            raise SystemExit(f"unmapped cell type {c['type']}")
        if c['type'] == 'FFBOX' and 'port_directions' not in c:
            c['port_directions'] = {'C': 'input', 'D': 'input', 'Q': 'output'}
    used = {c['type'] for c in cells.values() if c['type'].startswith('sky130')} | {BUF}
    L = parse_lib(lib, used)
    # names for nets
    netname = {}
    for n, d in m['netnames'].items():
        hide = d.get('hide_name', 0)
        for i, b in enumerate(d['bits']):
            if isinstance(b, int) and (b not in netname or (not hide and netname[b][1])):
                netname[b] = (f"{n}[{i}]" if len(d['bits']) > 1 else n, hide)
    drivers = {}; loads = defaultdict(float); fanin = {}
    for cn, c in cells.items():
        t = c['type']
        for p, bits in c['connections'].items():
            d = c['port_directions'][p]
            for b in bits:
                if not isinstance(b, int):
                    continue
                if d == 'output':
                    drivers[b] = (cn, p)
                elif t == 'FFBOX':
                    if p == 'D':
                        loads[b] += FF_DCAP
                elif t in L:
                    loads[b] += L[t].get(p, (0.0, []))[0]
    # A flop's Q often has only a $auto name (async2sync puts the RTL name on
    # the reset mux after it): name it after a public net one cell downstream.
    consumers = defaultdict(list)
    for cn, c in cells.items():
        for p, bits in c['connections'].items():
            if c['port_directions'].get(p) == 'input':
                for b in bits:
                    if isinstance(b, int):
                        consumers[b].append(cn)
    def pubname(b):
        n = netname.get(b)
        if n and not n[1] and not n[0].startswith('$'):
            return n[0]
        for cn in consumers.get(b, []):
            c = cells[cn]
            for p, bits in c['connections'].items():
                if c['port_directions'].get(p) == 'output':
                    for ob in bits:
                        n2 = netname.get(ob)
                        if n2 and not n2[1] and not n2[0].startswith('$'):
                            return n2[0]
        return n[0] if n else str(b)
    # arrival propagation (memoized DFS)
    sys.setrecursionlimit(1000000)
    arr = {}
    inbit = {}
    for cn, c in cells.items():
        for p, bits in c['connections'].items():
            if c['port_directions'][p] == 'input':
                inbit[(cn, p)] = bits[0]
    pred = {}
    def at(bit):
        if bit in arr:
            return arr[bit]
        if not isinstance(bit, int) or bit not in drivers:
            arr[bit] = (0.0, IN_SLEW); return arr[bit]
        cn, p = drivers[bit]; c = cells[cn]; t = c['type']
        if t == 'FFBOX':
            arr[bit] = (-1000.0 if os.environ.get('INPUTS_ONLY') else CLKQ, 0.1); pred[bit] = None; return arr[bit]
        load = loads[bit]
        extra, xs = 0.0, None
        if load > CMAX:
            # Buffer tree: fanout-4 stages of buf_4 until each drives <= CMAX.
            bcap = L[BUF]['A'][0]
            _, bdl, bsl = L[BUF]['X'][1][0]
            stages, rem = 0, load
            while rem > CMAX:
                rem /= 4.0; stages += 1
            s_in = 0.1
            for k in range(stages):
                ld = min(load, CMAX) if k == stages - 1 else 4 * bcap
                extra += max(interp(bdl[0], s_in, ld), interp(bdl[1], s_in, ld))
                s_in = max(interp(bsl[0], s_in, ld), interp(bsl[1], s_in, ld))
            xs = s_in
            load = bcap
        if L[t][p][1]:
            best = (-1e9, IN_SLEW)
        else:
            best = (-1000.0 if os.environ.get('INPUTS_ONLY') else 0.0, IN_SLEW)
        bp = None
        for rp, dl, sl in L[t][p][1]:
            ib = c['connections'].get(rp, [None])[0]
            a, s = at(ib)
            d = max(interp(dl[0], s, load), interp(dl[1], s, load))
            so = max(interp(sl[0], s, load), interp(sl[1], s, load))
            if a + d > best[0]:
                best = (a + d, so); bp = ib
        best = (best[0] + extra, xs if xs is not None else best[1])
        arr[bit] = best; pred[bit] = bp
        return best
    # iterative-safe: evaluate in topological order via explicit stack
    def eval_bit(b):
        stack = [b]
        while stack:
            x = stack[-1]
            if x in arr or not isinstance(x, int) or x not in drivers:
                if x not in arr: at(x)
                stack.pop(); continue
            cn, p = drivers[x]; c = cells[cn]
            if c['type'] == 'FFBOX':
                at(x); stack.pop(); continue
            pend = [c['connections'].get(rp, [None])[0] for rp, _, _ in L[c['type']][p][1]]
            pend = [q for q in pend if isinstance(q, int) and q not in arr]
            if pend:
                stack.extend(pend)
            else:
                at(x); stack.pop()
        return arr[b]
    ends = []
    for cn, c in cells.items():
        if c['type'] == 'FFBOX':
            b = c['connections']['D'][0]
            if isinstance(b, int):
                qb = c['connections']['Q'][0]
                ends.append((eval_bit(b)[0] + SETUP, pubname(qb), b))
    for pn, pd in m['ports'].items():
        if pd['direction'] == 'output':
            for i, b in enumerate(pd['bits']):
                if isinstance(b, int):
                    ends.append((eval_bit(b)[0], f"OUT {pn}[{i}]", b))
    ends.sort(reverse=True)
    grp = {}
    for d, name, b in ends:
        g = re.sub(r'\[\d+\]$', '', name)
        if g not in grp:
            grp[g] = (d, b)
    print(f"worst endpoint {ends[0][0]:.3f} ns  ({ends[0][1]})  endpoints {len(ends)}")

    tr = os.environ.get('TRACE')
    if tr:
        for g, (d, b) in grp.items():
            if re.fullmatch(tr, g):
                x = b; print(f"TRACE {g} {d:.3f}")
                last_src = None
                while isinstance(x, int):
                    nm = netname.get(x, ('?', 1))
                    a_ = arr.get(x, (0, 0))[0]
                    drv = cells[drivers[x][0]]['type'] if x in drivers else 'PI'
                    if not nm[1] and not nm[0].startswith('$'):
                        print(f"   {a_:7.3f}  {nm[0]}  ({drv})")
                    # TRACE_SRC=1: the RTL line of each cell on the path
                    # (where it changes), for paths through unnamed nets.
                    if os.environ.get('TRACE_SRC') and x in drivers:
                        src = cells[drivers[x][0]].get('attributes', {}).get('src', '').split('|')[0]
                        src = re.sub(r'\.\d+-\d+\.\d+$', '', src)
                        if src and src != last_src:
                            print(f"   {a_:7.3f}    @ {src}"); last_src = src
                    x = pred.get(x)
    for g, (d, b) in list(grp.items())[:top_n]:
        # start of path
        x = b; path = []
        while isinstance(x, int) and pred.get(x) is not None:
            path.append(x); x = pred[x]
        start = pubname(x) if isinstance(x, int) else '?'
        print(f"  {d:7.3f}  {g:55s} <- {start}  ({len(path)} cells)")

main()
