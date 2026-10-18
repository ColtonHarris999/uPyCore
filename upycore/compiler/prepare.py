"""Copy the vendored uPy2 compiler and apply the hart's adjustments.

The pin stays byte-identical for the host suite. The on-device copy drops
``struct`` (the hart has no such module) and names float constants by their
binary32 bits.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VENDOR = ROOT / "vendor" / "upy2" / "mpyc"
STAGES = Path(__file__).resolve().parent / "stages.py"

_PARSETREE_IMPORT = """from array import array
from struct import calcsize, pack
"""

_PARSETREE_IMPORT_NEW = '''from array import array


def _f32bits(value):
    """IEEE binary32 bits. ``f32bits`` is a firmware builtin on the hart."""
    try:
        return f32bits(value)
    except NameError:
        import struct
        x = float(value)
        try:
            packed = struct.pack("<f", x)
        except OverflowError:
            packed = struct.pack("<f", float("inf") if x > 0.0 else float("-inf"))
        return struct.unpack("<I", packed)[0]
'''

_FLOAT_MARK = "def float_repr(value):"
_FLOAT_END = "def _is_neg_zero(value):"
_FLOAT_NEW = '''def float_repr(value):
    """Float text for an .mpy const. Binary32 repr round-trips through float()."""
    if value != value:
        return "nan"
    return repr(value)


'''


def _same(path: Path, text: str) -> bool:
    return path.is_file() and path.read_text(encoding="utf-8") == text


def _put(path: Path, text: str) -> None:
    if not _same(path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")


def _require(text: str, needle: str, what: str) -> None:
    if needle not in text:
        raise SystemExit(f"{what}: {needle!r} not found")


def _patched_parsetree(text: str) -> str:
    _require(text, _PARSETREE_IMPORT, "parsetree")
    text = text.replace(_PARSETREE_IMPORT, _PARSETREE_IMPORT_NEW, 1)
    text = text.replace("ITEM_BYTES = calcsize('i')", "ITEM_BYTES = 4", 1)
    text = text.replace(
        'return ("f", pack("<d", value))',
        'return ("f", _f32bits(value))',
        1,
    )
    return text.replace(
        'return ("c", pack("<d", value.real), pack("<d", value.imag))',
        'return ("c", _f32bits(value.real), _f32bits(value.imag))',
        1,
    )


def _patched_floatfmt(text: str) -> str:
    start = text.find(_FLOAT_MARK)
    end = text.find(_FLOAT_END)
    if start < 0 or end < 0:
        raise SystemExit("floatfmt: float_repr not found")
    return text[:start] + _FLOAT_NEW + text[end:]


# The collector does not compact. Parsing a long parameter list interns
# every name and drops short-lived buffers between those qstrs, so the next
# dict growth cannot find a contiguous hole even though a collection would
# free more than the request. Collect while a large tail is still free.
_PARSE_LOOP = """        backtrack = False
        while self.rule_depth() > 0:
"""

_PARSE_LOOP_NEW = """        backtrack = False
        _low_heap = None
        try:
            import gc as _gc_mod
            _low_heap = _gc_mod.mem_free
        except (ImportError, AttributeError):
            _gc_mod = None
        _steps = 0
        while self.rule_depth() > 0:
            if _low_heap is not None:
                _steps += 1
                if _steps == 64:
                    _steps = 0
                    if _low_heap() < 98304:
                        _gc_mod.collect()
"""


def _patched_parser(text: str) -> str:
    _require(text, _PARSE_LOOP, "parser")
    return text.replace(_PARSE_LOOP, _PARSE_LOOP_NEW, 1)


# Naming each argument scans every identifier. On the hart that is a
# Python loop, and a few hundred parameters make it the whole compile.
# One pass records the first parameter in each slot; the bytes match.
_ARG_NAMES = """        n_args = scope.num_pos_args + scope.num_kwonly_args
        for i in range(n_args):
            qst = self.emit_common.pool.intern(b"*")
            for j in range(scope.num_ids()):
                if scope.id_is_param(j) and scope.id_local_num(j) == i:
                    qst = scope.id_qst(j)
                    break
            self._ci_qstr(qst)
"""

_ARG_NAMES_NEW = """        n_args = scope.num_pos_args + scope.num_kwonly_args
        arg_qst = []
        i = 0
        while i < n_args:
            arg_qst.append(None)
            i += 1
        j = 0
        n_ids = scope.num_ids()
        while j < n_ids:
            if scope.id_is_param(j):
                slot = scope.id_local_num(j)
                if slot >= 0 and slot < n_args and arg_qst[slot] is None:
                    arg_qst[slot] = scope.id_qst(j)
            j += 1
        star = self.emit_common.pool.intern(b"*")
        i = 0
        while i < n_args:
            qst = arg_qst[i]
            if qst is None:
                qst = star
            self._ci_qstr(qst)
            i += 1
"""


def _patched_emitbc(text: str) -> str:
    _require(text, _ARG_NAMES, "emitbc")
    return text.replace(_ARG_NAMES, _ARG_NAMES_NEW, 1)


def prepare(dest: Path | None = None) -> Path:
    """Return the patched ``mpyc`` package directory.

    Patches are applied to the vendored text, then written. A dest file that
    is already patched is never used as the input, so two images can prepare
    at the same time.
    """

    if not (VENDOR / "compile.py").is_file():
        raise SystemExit(f"uPy2 pin missing at {VENDOR.parent}")
    out = dest or (ROOT / "build" / "compiler" / "src" / "mpyc")
    out.mkdir(parents=True, exist_ok=True)
    for src in sorted(VENDOR.glob("*.py")):
        text = src.read_text(encoding="utf-8")
        if src.name == "parsetree.py":
            text = _patched_parsetree(text)
        elif src.name == "floatfmt.py":
            text = _patched_floatfmt(text)
        elif src.name == "compile_walk.py":
            text = _patched_walk(text)
        elif src.name == "parser.py":
            text = _patched_parser(text)
        elif src.name == "emitbc.py":
            text = _patched_emitbc(text)
        _put(out / src.name, text)
    _put(out / "stages.py", STAGES.read_text(encoding="utf-8"))
    return out


_WALK_OLD = """        self._emit_fns = tuple(getattr(self.emit, n) for n, _a in
                               _EMIT_METHODS)
        self._emit_arity = tuple(a for _n, a in _EMIT_METHODS)
"""

_WALK_NEW = """        # The hart rejects generator expressions. Build the tuples in a loop.
        _fns = []
        _arity = []
        for _n, _a in _EMIT_METHODS:
            _fns.append(getattr(self.emit, _n))
            _arity.append(_a)
        self._emit_fns = tuple(_fns)
        self._emit_arity = tuple(_arity)
"""


def _patched_walk(text: str) -> str:
    if _WALK_OLD not in text:
        raise SystemExit("compile_walk: generator expressions not found")
    return text.replace(_WALK_OLD, _WALK_NEW, 1)


def module_list(pkg: Path) -> list[tuple[str, Path, bool, str]]:
    """``(dotted name, path, is_package, source name)`` for the freezer."""

    rows = [("mpyc", pkg / "__init__.py", True, "mpyc/__init__.py")]
    for path in sorted(pkg.glob("*.py")):
        if path.name == "__init__.py":
            continue
        stem = path.name[:-3]
        rows.append((f"mpyc.{stem}", path, False, f"mpyc/{path.name}"))
    return rows


if __name__ == "__main__":
    print(prepare())
