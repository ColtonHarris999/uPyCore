# On-device driver. Each stage is its own call. The firmware collects
# after the call returns, once this frame and its locals are gone.
import gc

_tree = None
_comp = None
_mod_sid = 0
_max_labels = 0
_is_repl = False
_fname = b"<stdin>"
_busy = False


def _release():
    gc.collect()


from . import qstrs
_release()
from . import tokens
_release()
from . import runtime0
_release()
from . import opcodes
_release()
from . import grammar
_release()
from . import qstr_pool
_release()
from . import parsetree
_release()
from . import floatfmt
_release()
from . import bytecode
_release()
from . import mpy_format
_release()
from . import qstrtable
_release()
from . import scope
_release()
from . import constnode
_release()
from . import lexer
_release()
from . import parser
_release()
from . import emitbc
_release()
from . import compile_defs
_release()
from . import compile_walk
_release()
from . import compile_assign
_release()
from . import compile_defn
_release()
from . import compile_stmt
_release()
from . import compile_block
_release()
from . import compile_expr
_release()
from . import compile as _compile_mod
_release()


def stage_begin():
    global _busy
    if _busy:
        raise ValueError("compile is not re-entrant")
    _busy = True


def stage_end():
    global _busy, _tree, _comp
    _busy = False
    _tree = None
    _comp = None
    _release()


def stage_parse(source, filename, mode):
    global _tree, _is_repl, _fname
    kind_file = parser.PARSE_FILE_INPUT
    kind_eval = parser.PARSE_EVAL_INPUT
    kind_single = parser.PARSE_SINGLE_INPUT
    if mode == "eval":
        kind = kind_eval
        _is_repl = False
    elif mode == "single":
        kind = kind_single
        _is_repl = True
    elif mode == "exec":
        kind = kind_file
        _is_repl = False
    else:
        raise ValueError("bad compile mode")
    if type(filename) is bytes:
        _fname = filename
        shown = filename.decode("utf-8")
    else:
        shown = filename
        _fname = filename.encode("utf-8")
    _tree = parser.parse(source, shown, kind, 0)
    _release()


def stage_scope():
    global _comp, _mod_sid, _max_labels
    comp = _compile_mod.Compiler(_tree, _fname, _is_repl, 0)
    _comp = comp
    _mod_sid = comp.scope_new_and_link(
        scope.SCOPE_MODULE, _tree.root, emitbc.MP_EMIT_OPT_NONE)
    _max_labels = 0
    i = 0
    while i < len(comp.scopes):
        sc = comp.scopes[i]
        comp.compile_scope(sc, emitbc.MP_PASS_SCOPE)
        j = 0
        n = sc.num_ids()
        while j < n:
            if sc.id_kind(j) == scope.ID_INFO_KIND_GLOBAL_IMPLICIT:
                sc.check_to_close_over(j)
            j += 1
        if comp.next_label > _max_labels:
            _max_labels = comp.next_label
        i += 1
    _release()


def stage_layout():
    # Slot numbers only. Stack size, code size and emit share one emitter
    # and have to run back to back for each scope, so they stay in stage_write.
    comp = _comp
    qst = comp.pool.intern(b"__class__")
    for sc in comp.scopes:
        _compile_mod.scope_compute_things(sc, qst)
    comp.emit.set_max_num_labels(_max_labels)
    _release()


def stage_write():
    global _tree
    comp = _comp
    for sc in comp.scopes:
        comp.compile_scope(sc, emitbc.MP_PASS_STACK_SIZE)
        comp.compile_scope(sc, emitbc.MP_PASS_CODE_SIZE)
        while not comp.compile_scope(sc, emitbc.MP_PASS_EMIT):
            pass
        _release()
    comp.tree = None
    _tree = None
    _release()


def stage_encode():
    global _comp, _tree
    comp = _comp
    objs = []
    for value in comp.emit_common.const_objs:
        objs.append(mpy_format.obj_from_value(value))
    mpy = mpy_format.MpyFile(
        compile_defs.SMALL_INT_BITS,
        comp.emit_common.qstr_table.entries(),
        objs,
        _compile_mod.build_raw_code(comp.scopes[_mod_sid]),
    )
    data = mpy_format.encode(mpy)
    _comp = None
    _tree = None
    comp = None
    objs = None
    mpy = None
    _release()
    return data
