#!/usr/bin/env python3
"""Prove numeric helper rewrites against the pre-100MHz converted RTL.

Requires Yosys. Regenerate converted RTL first (convert_rtl.sh). Every proof
is combinational and covers all 2**64 inputs; pipeline handshakes are tested
by unit_tests.py. Logs and generated miters go to build/numeric_equivalence.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
RTL = 'upycore/synth/hammer/converted/mpy_alu.v'
BASE = 'dc64a89d887d343ff1bc64f9e1070a222fb62fc0'


def function(text, name):
    match = re.search(r'function automatic [^;]*\b' + name + r';.*?endfunction', text, re.S)
    if not match:
        raise ValueError(f'missing function {name}; regenerate converted RTL')
    return match.group(0)


def module(text, name):
    start = text.index('module ' + name)
    return text[start:text.index('endmodule', start) + len('endmodule')]


def classification(text, label):
    text = module(text, 'upycore_fpu')
    names = ['upycore_f64_is_zero', 'upycore_f64_is_finite',
             'upycore_f64_is_odd_integer']
    names += ['upycore_f64_floor'] if label == 'gold' else ['upycore_f64_is_integer']
    integral = 'upycore_f64_is_finite(d) && upycore_f64_floor(d)==d' if label == 'gold' else 'upycore_f64_is_integer(d)'
    return f'''module {label}(input [63:0] d, output [1:0] q);
localparam [63:0] UPY_F64_NONE=64'hbff0000000000000, UPY_F64_PZERO=0;
function automatic [5:0] sv2v_cast_6; input [31:0] x; sv2v_cast_6=x[5:0]; endfunction
''' + '\n'.join(function(text, n) for n in names) + f'''
assign q = {{upycore_f64_is_odd_integer(d), ({integral})}};
endmodule
'''


def clz(text, label):
    return f'module {label}(input [63:0] d, output [6:0] q);\n' + function(text, 'upycore_clz64') + '''
function automatic [6:0] sv2v_cast_7_signed; input signed [31:0] x; sv2v_cast_7_signed=x[6:0]; endfunction
assign q=upycore_clz64(d);
endmodule
'''


def exponent_magnitude(text, label):
    text = module(text, 'upycore_fpu')
    if label == 'gold':
        return '''module gold(input [63:0] d, output [64:0] q);
reg [63:0] t;
reg ok;
''' + function(text, 'upycore_float_trunc_int64') + '''
always @* ok=upycore_float_trunc_int64(d,t);
assign q={ok, t[63] ? (~t+64'd1) : t};
endmodule
'''
    assigns = []
    for name in ['b_uexp','b_sig','b_trunc_ok','b_trunc_abs']:
        match = re.search(r'assign\s+' + name + r'\s*=.*?;', text, re.S)
        if not match:
            raise ValueError(f'missing assignment {name}')
        assigns.append(match.group(0).replace('br[','d['))
    return '''module gate(input [63:0] d, output [64:0] q);
wire [10:0] b_uexp;
wire [63:0] b_sig, b_trunc_abs;
wire b_trunc_ok;
''' + '\n'.join(assigns) + '''
assign q={b_trunc_ok,b_trunc_abs};
endmodule
'''



def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--baseline', default=BASE)
    args = ap.parse_args()
    old = subprocess.check_output(['git', 'show', f'{args.baseline}:{RTL}'], cwd=ROOT, text=True)
    new = (ROOT / RTL).read_text()
    work = ROOT / 'build/numeric_equivalence'
    work.mkdir(parents=True, exist_ok=True)
    for name, width, make in [('narrow',32,lambda s,n:module(s,'mpy_f32_narrow').replace('module mpy_f32_narrow','module '+n)),
                             ('classification',2,classification), ('clz64',7,clz),
                             ('exponent_magnitude',65,exponent_magnitude)]:
        src = work / f'{name}.v'
        src.write_text(make(old,'gold') + '\n' + make(new,'gate') + f'''
module miter(input [63:0] d);
wire [{width-1}:0] a,b;
gold g(d,a); gate t(d,b);
always @* assert(a==b);
endmodule
''')
        script = f'read_verilog -formal {src}; prep -top miter -flatten; sat -verify -prove-asserts -show-inputs'
        run = subprocess.run([os.environ.get('YOSYS','yosys'), '-Q','-T','-p',script], cwd=ROOT, capture_output=True, text=True)
        (work / f'{name}.log').write_text(run.stdout + run.stderr)
        if run.returncode or 'no model found: SUCCESS' not in run.stdout:
            raise SystemExit(f'FAIL {name}; see {work / (name + ".log")}')
        print(f'PASS {name}: all 64-bit inputs', flush=True)


if __name__ == '__main__':
    main()
