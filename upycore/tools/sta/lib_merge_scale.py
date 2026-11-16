"""Merge ASAP7 liberty files into one and convert ps/fF to ns/pF (x1e-3)."""
import re, sys
out, srcs = sys.argv[1], sys.argv[2:]
def cells(txt):
    res = []
    for m in re.finditer(r'\n(\s*)cell\s*\(', txt):
        i = txt.index('{', m.end()); depth = 1; j = i + 1
        while depth:
            depth += {'{': 1, '}': -1}.get(txt[j], 0); j += 1
        res.append(txt[m.start():j])
    return res
def scale_nums(s):
    return re.sub(r'-?\d+\.?\d*(?:[eE][-+]?\d+)?', lambda m: repr(float(m.group(0)) * 1e-3), s)
def conv(c):
    c = re.sub(r'(index_[12]\s*\(\s*")([^"]*)(")', lambda m: m.group(1) + scale_nums(m.group(2)) + m.group(3), c)
    c = re.sub(r'(values\s*\()(.*?)(\)\s*;)', lambda m: m.group(1) + scale_nums(m.group(2)) + m.group(3), c, flags=re.S)
    c = re.sub(r'(\b(?:capacitance|rise_capacitance|fall_capacitance|max_capacitance)\s*:\s*)([\d.eE+-]+)',
               lambda m: m.group(1) + repr(float(m.group(2)) * 1e-3), c)
    return c
first = open(srcs[0]).read()
head = first[:first.index('\n', re.search(r'\n\s*cell\s*\(', first).start() - 1)]
head = head[:re.search(r'\n\s*cell\s*\(', first).start()]
head = head.replace('time_unit : "1ps"', 'time_unit : "1ns"').replace('capacitive_load_unit (1,ff)', 'capacitive_load_unit (1,pf)')
# drop the header's lu_table templates' numeric scaling issue: templates hold indices too
head = re.sub(r'(index_[12]\s*\(\s*")([^"]*)(")', lambda m: m.group(1) + scale_nums(m.group(2)) + m.group(3), head)
body = []
for s in srcs:
    body += [conv(c) for c in cells(open(s).read())]
open(out, 'w').write(head + '\n' + '\n'.join(body) + '\n}\n')
print(len(body), 'cells')
