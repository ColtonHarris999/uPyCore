// uPyCore execution core: runs MicroPython v1.29.0 bytecode from a linked
// flash image (upycore/tools/mpy_link.py) against the ABI in mpy_abi.svh.
//
// One frame is live. Locals sit in the frame record in SRAM (up to 255).
// The operand stack is the 16-entry register file, used as a ring of the
// newest values. When 12 slots are resident, the oldest values are copied
// to a packed SRAM block. A stack that has only been growing spills 8 so a
// deep expression walks fewer links. A stack that has been popping spills
// 4, which is cheap to pull back. The block header holds the previous
// chunk address and the count. The slot just after the copied values
// becomes a CONTROL/RF_LINK back to the block. A few hot locals sit in a
// side cache so LOAD_FAST and STORE_FAST do not touch SRAM on every use.
// A call snapshots the resident ring into the caller's frame and a return
// copies it back. The local cache is flushed into the frame first.
//
// The core handles the common shapes of every opcode itself: small and
// long-long ints and binary32 floats, str/qstr equality and hashing, list,
// tuple, dict and set access, attribute lookup through instance dicts and
// type MROs, calls of bytecode functions with plain positional binding,
// bound methods, natives, instance creation, and exception unwinding with
// tracebacks. Anything else is a call into a firmware hook (HOOKS in the ABI):
// the core marshals the operands, calls the hook like any Python function,
// and a return kind (RK) or continuation (CONT) says what to do with the
// result. Firmware frames carry RC_FLAG_FIRMWARE and add no traceback lines.
//
// Subroutines use a small return-state stack (rstk). Raising an exception
// resets it: an exception abandons whatever microcode was in flight.
//
// Every heap value that must survive an allocation sits in rf, ARGBUF, the
// frame header, t[0..7], xc, or the cached exception top. Before a collection
// the core spills the frame, t[], and xc. ARGBUF already sits in the
// collector's root window. The spill flushes the exception top into the frame
// first; the entries under it are already there.
//
// Bulk word copies (the _wcopy native and a list's grow copy) go to the
// container accelerator (mpy_ca) once the core has allocated the
// destination. The core ships the command and moves on; the accelerator's
// scoreboard makes any later access to words still being copied wait at the
// port. The core waits for the accelerator to drain before a collection.

`include "mpy_defs.svh"
`include "mpy_abi.svh"

/* verilator lint_off WIDTH */
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off CASEINCOMPLETE */
/* verilator lint_off BLKSEQ */
module mpy_core
    import mpy_dec::*;
    import mpy_alu_pkg::*;
#(
    parameter int RSTK_DEPTH = 16,
    // Values copied by one spill while the stack has only been growing.
    // MPY_RF_CHUNK_MIN is the shrink chunk. +GROW= and +ADAPT= override these in sim.
    parameter int GROW_CHUNK = 8,
    parameter int GROW_ADAPT = 1,
    // Hot locals kept beside the operand stack. 0 disables the cache.
    // +LC= +LCWB= +LCDM= override these in simulation.
    parameter int LC_N = 8,
    parameter int LC_WB = 1,
    // Ship bulk copies to mpy_ca. 0 keeps them on the core. +CA= overrides in sim.
    parameter int CA_EN = 1
) (
    input  logic        clk_i,
    input  logic        rst_n_i,

    output logic        m_req_o,
    output logic        m_we_o,
    output logic        m_tag_we_o,
    output logic [3:0]  m_be_o,
    output logic [31:0] m_addr_o,
    output logic [31:0] m_wdata_o,
    output logic [3:0]  m_wtag_o,
    input  logic        m_ack_i,
    input  logic [31:0] m_rdata_i,
    input  logic [3:0]  m_rtag_i,
    input  logic        m_fault_i,
    input  logic [3:0]  m_fault_reason_i,

    output logic        gc_alloc_req_o,
    output logic [31:0] gc_alloc_nbytes_o,
    input  logic        gc_alloc_done_i,
    input  logic        gc_alloc_ok_i,
    input  logic [31:0] gc_alloc_addr_i,
    output logic        gc_collect_req_o,
    output logic [31:0] gc_root0_lo_o,
    output logic [31:0] gc_root0_hi_o,
    output logic [31:0] gc_root1_lo_o,
    output logic [31:0] gc_root1_hi_o,
    input  logic        gc_collect_done_i,
    input  logic [31:0] gc_free_i,
    input  logic [31:0] gc_total_i,
    input  logic [31:0] gc_collections_i,

    output logic        ca_valid_o,
    input  logic        ca_ready_i,
    output logic [31:0] ca_dst_o,
    output logic [31:0] ca_src_o,
    output logic [31:0] ca_n_o,
    input  logic        ca_idle_i,
    input  logic        ca_fault_i,
    input  logic [3:0]  ca_fault_reason_i,
    input  logic [31:0] ca_fault_addr_i,

    output logic        halted_o,
    output logic [3:0]  halt_code_o,
    output logic [31:0] halt_value_o,
    output logic [31:0] cycles_o,
    output logic [31:0] ops_o,
    output logic        trace_o,
    output logic [31:0] trace_pc_o,
    output logic [7:0]  trace_op_o,
    output logic [6:0]  trace_sp_o
);
    typedef logic [35:0] val_t;

    localparam val_t VNULL  = {ABI_TAG_CONTROL, ABI_CTL_NULL};
    localparam val_t VNONE  = {ABI_TAG_CONTROL, ABI_CTL_NONE};
    localparam val_t VSTOP  = {ABI_TAG_CONTROL, ABI_CTL_STOP};
    localparam val_t VTOMB  = {ABI_TAG_CONTROL, ABI_CTL_TOMB};
    localparam val_t VFALSE = {ABI_TAG_CONTROL, ABI_CTL_FALSE};
    localparam val_t VTRUE  = {ABI_TAG_CONTROL, ABI_CTL_TRUE};

    localparam logic [31:0] TT = 32'(ABI_TYPE_TABLE);
    localparam logic [31:0] EMERG_ADDR = ABI_SYSROOT_BASE + 4 * ABI_SR_EMERG;
    localparam logic [31:0] HASH_NONE = 32'd6;
    localparam logic [7:0]  FF_FW = 8'h01;
    localparam logic [7:0]  FF_GEN = 8'h02;   // this frame is a generator being bound
    localparam logic [7:0]  FF_YFAST = 8'h04; // YIELD_FROM resumed a generator child directly
    localparam logic [7:0]  FF_NOTB = 8'h80;

    localparam logic [1:0] LK_FIND = 2'd0;
    localparam logic [1:0] LK_ADD = 2'd1;
    localparam logic [1:0] LK_REMOVE = 2'd2;

    // ------------------------------------------------------------------
    // Value helpers
    // ------------------------------------------------------------------
    function automatic logic [3:0] tg(input val_t v); tg = v[35:32]; endfunction
    function automatic logic [31:0] adr(input val_t v); adr = {v[31:2], 2'b00}; endfunction
    function automatic val_t vint(input logic [31:0] x); vint = {ABI_TAG_INT, x}; endfunction
    function automatic val_t vobj(input logic [31:0] x); vobj = {ABI_TAG_OBJECT, x}; endfunction
    function automatic val_t vbool(input logic b); vbool = b ? VTRUE : VFALSE; endfunction
    function automatic val_t vmut(input logic [31:0] a, input logic [1:0] k); vmut = {ABI_TAG_MUT, a[31:2], k}; endfunction
    function automatic logic is_bool(input val_t v); is_bool = (v == VTRUE) || (v == VFALSE); endfunction
    function automatic logic intlike(input val_t v); intlike = (tg(v) == ABI_TAG_INT) || is_bool(v); endfunction
    function automatic logic numlike(input val_t v);
        numlike = intlike(v) || tg(v) == ABI_TAG_INT64 || tg(v) == ABI_TAG_FLOAT;
    endfunction
    function automatic logic [31:0] ival(input val_t v);
        ival = is_bool(v) ? {31'd0, v == VTRUE} : v[31:0];
    endfunction
    function automatic logic strlike(input val_t v);
        strlike = (tg(v) == ABI_TAG_QSTR) || (tg(v) == ABI_TAG_STR);
    endfunction
    function automatic logic is_mut(input val_t v, input logic [1:0] k);
        is_mut = (tg(v) == ABI_TAG_MUT) && (v[1:0] == k);
    endfunction
    function automatic logic [31:0] sx31(input logic [31:0] x); sx31 = {x[30], x[30:0]}; endfunction
    function automatic logic fits31(input logic [63:0] x);
        fits31 = (x[63:30] == {34{1'b0}}) || (x[63:30] == {34{1'b1}});
    endfunction
    function automatic logic fits32(input logic [63:0] x);
        fits32 = (x[63:31] == {33{1'b0}}) || (x[63:31] == {33{1'b1}});
    endfunction
    // Address of a pointer value; an INT is taken as a raw address.
    function automatic logic [31:0] padr(input val_t v);
        padr = (tg(v) == ABI_TAG_INT) ? v[31:0] : adr(v);
    endfunction
    function automatic logic [7:0] byte_of(input logic [31:0] w, input logic [1:0] i);
        byte_of = w[8*i +: 8];
    endfunction

    // MicroPython's mp_map growth sequence (py/map.c).
    function automatic logic [31:0] next_alloc(input logic [31:0] x);
        logic [31:0] t [0:33];
        logic [31:0] r;
        t = '{0, 2, 4, 6, 8, 10, 12, 17, 23, 29, 37, 47, 59, 73, 97, 127, 167, 223, 293, 389,
              521, 691, 919, 1223, 1627, 2161, 3229, 4831, 7243, 10861, 16273, 24407, 36607, 54907};
        r = (x + (x >> 1)) | 32'd1;
        for (int i = 33; i >= 0; i--) if (t[i] >= x) r = t[i];
        next_alloc = r;
    endfunction

    function automatic logic [7:0] msg_type(input logic [7:0] id);
        case (id)
            ABI_MSG_RECURSION: msg_type = ABI_MSGT_RECURSION;
            ABI_MSG_DIV_ZERO: msg_type = ABI_MSGT_DIV_ZERO;
            ABI_MSG_OVERFLOW: msg_type = ABI_MSGT_OVERFLOW;
            ABI_MSG_LIST_INDEX: msg_type = ABI_MSGT_LIST_INDEX;
            ABI_MSG_TUPLE_INDEX: msg_type = ABI_MSGT_TUPLE_INDEX;
            ABI_MSG_STR_INDEX: msg_type = ABI_MSGT_STR_INDEX;
            ABI_MSG_LOCAL_UNBOUND: msg_type = ABI_MSGT_LOCAL_UNBOUND;
            ABI_MSG_NEG_SHIFT: msg_type = ABI_MSGT_NEG_SHIFT;
            ABI_MSG_NO_ACTIVE_EXC: msg_type = ABI_MSGT_NO_ACTIVE_EXC;
            ABI_MSG_ZERO_STEP: msg_type = ABI_MSGT_ZERO_STEP;
            ABI_MSG_STOP_ITER: msg_type = ABI_MSGT_STOP_ITER;
            ABI_MSG_MEMORY: msg_type = ABI_MSGT_MEMORY;
            ABI_MSG_ASSERT: msg_type = ABI_MSGT_ASSERT;
            ABI_MSG_BYTES_INDEX: msg_type = ABI_MSGT_BYTES_INDEX;
            ABI_MSG_RANGE_INDEX: msg_type = ABI_MSGT_RANGE_INDEX;
            ABI_MSG_POP_EMPTY: msg_type = ABI_MSGT_POP_EMPTY;
            ABI_MSG_HEAP_LOCKED: msg_type = ABI_MSGT_HEAP_LOCKED;
            ABI_MSG_SCHED_FULL: msg_type = ABI_MSGT_SCHED_FULL;
            ABI_MSG_KBD: msg_type = ABI_MSGT_KBD;
            ABI_MSG_GEN_SEND: msg_type = ABI_MSGT_GEN_SEND;
            ABI_MSG_GEN_RUNNING: msg_type = ABI_MSGT_GEN_RUNNING;
            ABI_MSG_GEN_IGNORED: msg_type = ABI_MSGT_GEN_IGNORED;
            ABI_MSG_GEN_STOP: msg_type = ABI_MSGT_GEN_STOP;
            default: msg_type = ABI_MSGT_EMPTY;
        endcase
    endfunction

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    typedef enum logic [9:0] {
        S_BOOT,
        S_HALT,
        S_MWAIT,
        S_AL,
        S_AL_OOM,
        S_AL_OOM2,
        S_AL_CLR,
        S_AL_RT,
        S_AL_W,
        S_AT,
        S_AT_ID,
        S_AT_IDR,
        S_AT_K,
        S_AT_M1,
        S_AT_M2,
        S_AT_MD2,
        S_AT_ML,
        S_AT_MOD,
        S_AT_MODR,
        S_AT_MR,
        S_AT_MRO,
        S_AT_MT,
        S_AT_NT,
        S_AT_T1,
        S_AT_VK,
        S_BF,
        S_BF_DEF,
        S_BF_DEF2,
        S_BF_KW,
        S_BF_KW2,
        S_BF_VA,
        S_BF_VA2,
        S_BIN,
        S_BIN_FB,
        S_BL_A,
        S_BL_L,
        S_BM_A,
        S_BOOT1,
        S_BOOT10,
        S_BOOT11,
        S_BOOT12,
        S_BOOT13,
        S_BOOT14,
        S_BOOT15,
        S_BOOT16,
        S_BOOT2,
        S_BOOT2B,
        S_BOOT3,
        S_BOOT4,
        S_BOOT5,
        S_BOOT6,
        S_BOOT7,
        S_BOOT8,
        S_BOOT9,
        S_BS,
        S_BS1,
        S_BS2,
        S_BSET_R,
        S_BSET_H,
        S_BT_R,
        S_CALL,
        S_CALL_BF,
        S_CALL_BS,
        S_CALL_K,
        S_CALL_MN,
        S_CALL_NI,
        S_CALL_TF,
        S_CB_A,
        S_CB_C,
        S_CB_L,
        S_CB_N,
        S_CB_V,
        S_CELLS,
        S_CELL_A,
        S_CELL_I,
        S_CF,
        S_CF1,
        S_CF2,
        S_CF3,
        S_CF4,
        S_CF_ARGS,
        S_CF_C,
        S_CF_CHK,
        S_CF_CLI,
        S_CF_CLN,
        S_CF_CLP,
        S_CF_MD,
        S_CF_PC,
        S_CF_Q,
        S_CF_SIG,
        S_CF_SIG2,
        S_CF_SW,
        S_CNS,
        S_CONT,
        S_CVK_E,
        S_CVK_I,
        S_CVK_L,
        S_CVK_N,
        S_CVK_P,
        S_CVK_V,
        S_DADDR,
        S_DADDR_M,
        S_DADDR_R,
        S_DEC,
        S_DELDEREF,
        S_DELIVER,
        S_DEREF,
        S_DN_R,
        S_EQ,
        S_EQ_S,
        S_EXEC,
        S_EXM,
        S_EXM_R,
        S_EXM_T,
        S_EXM_TI,
        S_EXM_TL,
        S_EXM_TN,
        S_EXM_TR,
        S_FETCH,
        S_FILL,
        S_FI_AT,
        S_FI_DONE,
        S_FI_GK,
        S_FI_LD,
        S_FI_LD2,
        S_FI_R,
        S_FI_W1,
        S_FL_H,
        S_FL_R,
        S_FL_X,
        S_FL_X0,
        S_FW,
        S_GSAVE,
        S_GSAVE1,
        S_GSAVE1B,
        S_GSAVE2,
        S_GN_AL,
        S_GN_AL2,
        S_GN_AL3,
        S_GN_AL4,
        S_GN_AL5,
        S_GN_AL6,
        S_GN_ESC,
        S_GN_ESC1,
        S_GN_ESC2,
        S_GN_ESC3,
        S_GN_ESC4,
        S_GN_ESC5,
        S_GN_RET,
        S_GN_RET1,
        S_GN_RET2,
        S_GN_RET3,
        S_GR0,
        S_GR1,
        S_GR2,
        S_GR3,
        S_GR4,
        S_GR5,
        S_GR6,
        S_GR_CLR,
        S_GR_GO,
        S_GR_INST,
        S_GR_OPB,
        S_GR_OPC,
        S_GR_RUN,
        S_YLD,
        S_YLD2,
        S_YLD3,
        S_YF_F,
        S_YF_K,
        S_YF_V,
        S_YF_GE,
        S_YF_GK,
        S_YF_GT,
        S_YF_GC,
        S_YF_GR,
        S_YF_SI,
        S_YF_SI2,
        S_YF_SV,
        S_YF_SL,
        S_YF_SA,
        S_GC,
        S_GC_1,
        S_GC_AB,
        S_GC_T,
        S_GC_W,
        S_GI,
        S_GI_AT,
        S_GI_FB,
        S_GI_K,
        S_GI_R0,
        S_GI_R1,
        S_GI_R2,
        S_GI_S,
        S_GI_V0,
        S_GI_V1,
        S_HASH,
        S_HASH_I64,
        S_HASH_OBJ,
        S_HASH_W16,
        S_HC1,
        S_HC2,
        S_HCALL,
        S_HOOK,
        S_HOOK1,
        S_IN,
        S_IN_R,
        S_ISSUB,
        S_IS_C,
        S_IS_L,
        S_IS_M,
        S_IS_N,
        S_IT,
        S_IT_BB,
        S_IT_BL,
        S_IT_DA,
        S_IT_DI,
        S_IT_DK,
        S_IT_DL,
        S_IT_DT,
        S_IT_DV,
        S_IT_LI,
        S_IT_SC,
        S_IT_SL,
        S_IT_V,
        S_JT,
        S_KEYEQ,
        S_KE_A0,
        S_KE_A1,
        S_KE_B0,
        S_KE_B1,
        S_KE_OBJ,
        S_KE_S,
        S_LA,
        S_LA_A,
        S_LA_BM,
        S_LA_CP,
        S_LA_CP2,
        S_LA_G,
        S_LA_G2,
        S_LA_G3,
        S_LA_G4,
        S_LA_I,
        S_LA_INC,
        S_LA_N,
        S_LA_R,
        S_LA_RET,
        S_LCO,
        S_LCS,
        S_LK,
        S_LK_AL,
        S_LK_DEC,
        S_LK_FL,
        S_LK_H,
        S_LK_HIT,
        S_LK_INC,
        S_LK_INS,
        S_LK_INS2,
        S_LK_INS3,
        S_LK_K,
        S_LK_KE,
        S_LK_NX,
        S_LK_P,
        S_LK_RET,
        S_LK_RH,
        S_LK_RM,
        S_LK_RM2,
        S_LK_RM3,
        S_LK_RM4,
        S_LK_RV,
        S_LK_TB,
        S_LK_V,
        S_LN_L,
        S_LN_R,
        S_LSUB,
        S_LS_D,
        S_LS_FB,
        S_LS_IT,
        S_LS_LEN,
        S_LS_PUT,
        S_LS_S,
        S_LS_SB,
        S_LS_SC,
        S_MF_A,
        S_MF_C,
        S_MF_CL,
        S_MF_R,
        S_MF_RT,
        S_MF_RT2,
        S_NAT,
        S_NAT_FB,
        S_NAT_FB1,
        S_NAT_FB2,
        S_NEW,
        S_NEW_I,
        S_NEW_INIT,
        S_NEW_IR,
        S_NEW_X,
        S_NEW_XA,
        S_NUM,
        S_NUM_AH,
        S_NUM_AL,
        S_NUM_B,
        S_NUM_BH,
        S_NUM_BL,
        S_NUM_BOX,
        S_NUM_GO,
        S_NUM_PUT,
        S_NUM_W,
        S_N_ALLOC,
        S_N_BC,
        S_N_BC1,
        S_N_BC2,
        S_N_BC3,
        S_N_BCA,
        S_N_BCB,
        S_N_BCL,
        S_N_BCMP1,
        S_N_BCMP2,
        S_N_BEI,
        S_N_DATA,
        S_N_FGET,
        S_N_FTOI,
        S_N_FTOI_B,
        S_N_FTOI_W,
        S_N_HASH,
        S_N_IN_D,
        S_N_IN_LD,
        S_N_IN_LD2,
        S_N_IN_R,
        S_N_IN_W,
        S_N_ISI,
        S_N_ISI2,
        S_N_ISI3,
        S_N_LEN_S,
        S_N_LOOKUP,
        S_N_NONE,
        S_N_OBJ,
        S_N_PEEK8,
        S_N_RANGE,
        S_N_RINT,
        S_N_RV,
        S_N_SF0,
        S_N_SF1,
        S_N_SF2,
        S_N_SFB,
        S_N_SFL,
        S_N_STRNEW,
        S_N_STRNEW2,
        S_N_TYPEOF,
        S_N_WC,
        S_N_WC2,
        S_N_WR,
        S_N_WRB,
        S_N_WRL,
        S_QD,
        S_QOP,
        S_RAISE,
        S_RET,
        S_RET_D,
        S_RH,
        S_RH_A,
        S_RH_A2,
        S_RH_A3,
        S_RH_F1,
        S_RH_F2,
        S_RH_F3,
        S_RH_H,
        S_RH_K,
        S_RH_L,
        S_RH_NX,
        S_RH_P,
        S_RH_PK,
        S_RH_V,
        S_RH_V2,
        S_RMSG,
        S_RMSG1,
        S_RMSG2,
        S_RMSG3,
        S_RMSG4,
        S_ROBJ,
        S_ROBJ_K,
        S_ROBJ_T,
        S_RX_H,
        S_RX_POP,
        S_RX_SI,
        S_RX_SI2,
        S_RX_TB,
        S_RX_TB1,
        S_RX_TB2,
        S_RX_TBA,
        S_RX_TBB,
        S_RX_TBC,
        S_RX_TBL,
        S_RX_TBN,
        S_SA,
        S_SA_D,
        S_SA_FB,
        S_SA_K,
        S_SA_ND,
        S_SA_NL,
        S_SA_NL2,
        S_SA_R,
        S_SA_TF,
        S_SA_TY,
        S_SC_D,
        S_SC_L,
        S_SC_S,
        S_SE1,
        S_SE2,
        S_SEA,
        S_SEB,
        S_SEL,
        S_SINFO,
        S_SI_Q0,
        S_SI_Q1,
        S_SI_S0,
        S_SI_S1,
        S_SI_S2,
        S_SLICE_A,
        S_SN_R,
        S_SPILL,
        S_SP_H,
        S_SP_L,
        S_SP_L2,
        S_SP_R,
        S_SP_X,
        S_SSUB,
        S_SS_D,
        S_SS_FB,
        S_SS_IT,
        S_SS_LEN,
        S_STM_R,
        S_STREQ,
        S_SW_E,
        S_SW_X,
        S_TR,
        S_TR_F,
        S_TR_LEN,
        S_TR_T,
        S_TUP,
        S_TUP_A,
        S_TUP_L,
        S_TYPEOF,
        S_TYPEOF_SET,
        S_TYPEOF_TT,
        S_UJ,
        S_UJ_L,
        S_UN,
        S_UPK_L,
        S_UPK_N,
        S_UPK_V,
        S_UPS_L,
        S_UPS_N,
        S_UPS_P,
        S_UPS_V,
        S_UR,
        S_UR_SLOW,
        S_WB,
        S_WC,
        S_WC_T,
        S_WC_TR,
        S_LCLR,
        S_LCLR2,
        S_LDEL,
        S_LDREF,
        S_LDF,
        S_LC_EV,
        S_LC_FL,
        S_DDREF,
        S_STREF,
        S_BF_P,
        S_BF_P2,
        S_BF_KW3,
        S_CELL_RD,
        S_CELL_B,
        S_RF_SPILL,
        S_RF_SPILL_W,
        S_RF_RELOAD,
        S_RF_RELOAD_R,
        S_RF_RELOAD_G,
        S_SRD,
        S_SRD_T0,
        S_SRD_T1,
        S_SRD_GOT,
        S_CC_FUN,
        S_CC_FUN2,
        S_CC_SELF,
        S_CC_SELF2,
        S_CC_ARG,
        S_CC_ARG2,
        S_CC_DONE,
        S_DROP,
        S_BL_W,
        S_TUP_W,
        S_FL_L,
        S_FL_L2,
        S_FL_S,
        S_FL_S2,
        S_XPUSH,
        S_XPOP,
        S_XFLUSH,
        S_XLOAD,
        S_XS,
        S_XEF,
        S_AB_HW,
        S_CALL_Q,
        S_CALL_BS2,
        S_CALL_MN2,
        S_NEW_IR2,
        S_BS_Q,
        S_BF_PR,
        S_CALL_CP,
        S_CALL_CP2,
        S_AB_31,
        S_WC_W,
        S_WC_SP,
        S_CVK_P2,
        S_CVK_KW,
        S_CVK_PW,
        S_CVK_PF,
        S_CVK_PS,
        S_CVK_P2W,
        S_CVK_PI,
        S_CVK_SW0,
        S_CVK_SW1,
        S_CVK_SWN,
        S_CVK_SWN2,
        S_CVK_SWP,
        S_CVK_SWD,
        S_CVK_RD,
        S_CVK_RD2,
        S_CVK_EV,
        S_CVK_ES,
        S_CVK_KV,
        S_CVK_KV2,
        S_CVK_VC,
        S_CVK_CH,
        S_CVK_CH2,
        S_CVK_CP,
        S_CVK_CPV,
        S_CVK_AP,
        S_CVK_EL,
        S_CVK_ELD,
        S_CVK_NB,
        S_CVK_NBW,
        S_CVK_NBL,
        S_CVK_OVP,
        S_CVK_MIG_A,
        S_CVK_MIG_C,
        S_CVK_MIG_W,
        S_CVK_MIG_D,
        S_CVK_EXT_A,
        S_CVK_EXT_C,
        S_CVK_EXT_W,
        S_CVK_EXT_D,
        S_CVK_PACK,
        S_CVK_PK0,
        S_CVK_PKA,
        S_CVK_PKC,
        S_CVK_PKW,
        S_CVK_W1,
        S_CVK_W4,
        S_CVK_W1B,
        S_CALL_BSC,
        S_CALL_BSC2,
        S_CALL_BSC3,
        S_CALL_BSC4,
        S_CALL_BSC5,
        S_CALL_BSC6,
        S_CALL_BSC7,
        S_CALL_BSC8,
        S_BS_W,
        S_BS_CL,
        S_BS_CL2,
        S_BS_CL3,
        S_BS_CL4,
        S_BS_CLP,
        S_BS_CL5,
        S_BS_CL6,
        S_BS_CL7,
        S_BS_HK,
        S_BS_HK2,
        S_GN_RET4,
        S_TUP_AB,
        S_NAT_A,
        S_NAT_FB0,
        S_NAT_ISI,
        S_NAT_MK,
        S_NAT_LD,
        S_NAT_ST1,
        S_NAT_ST2,
        S_NAT_PEEK,
        S_NAT_POKE1,
        S_NAT_POKE2,
        S_NAT_CNS,
        S_NAT_CALL,
        S_NAT_CALL2,
        S_NAT_WC1,
        S_NAT_WC2,
        S_NAT_WC3,
        S_NAT_WC4,
        S_NAT_WC5,
        S_NAT_BC0,
        S_NAT_LK,
        S_NAT_GR1,
        S_NAT_GR2,
        S_NAT_LA,
        S_NAT_QX,
        S_NAT_RG1,
        S_NAT_RG2,
        S_NAT_RG3,
        S_N_ALLOC1,
        S_N_ALLOC2,
        S_N_BC1A,
        S_N_BC2A,
        S_N_BC2B,
        S_N_BCMP1B,
        S_N_STRNEW_A,
        S_N_STRNEW_B,
        S_SCR,
        S_SCR_CAP,
        S_RH_LKA,
        S_RH_LKB,
        S_RH_F3B,
        S_FI_PRE,
        S_N_SF0B,
        S_SA_K2,
        S_N_BCMP_W,
        S_N_BCMP_W2,
        S_N_BCI,
        S_N_BCF,
        S_NAT_WCA,
        S_LA_CA
    } state_e;

    state_e st, wret;
    state_e rstk [0:RSTK_DEPTH-1];
    logic [4:0] rsp;

    // memory port
    logic        m_req, m_we, m_tag_we;
    logic [3:0]  m_be, m_wtag;
    logic [31:0] m_addr, m_wdata;
    logic [31:0] md;
    logic [3:0]  mt;
    val_t mv;
    assign mv = {mt, md};

    // image constants
    logic [31:0] h_qdesc, h_builtins, h_hooks, h_msgs, h_chars, h_empty;
    // Image qstr count, plus a RAM descriptor table for ids compiled code invents.
    logic [31:0] h_nq, h_qext, h_qextn, qid;
    state_e      qd_nxt;
    val_t ty_fun, ty_bm, ty_cell, ty_obj, ty_stop, ty_mem, ty_slice;

    // live frame
    logic [31:0] fbase, fprev, rc, pc, op_pc, qbase, cbase;
    logic [6:0]  sp;
    logic [7:0]  nloc;
    logic [5:0]  rf_base;
    logic [15:0] spilled_reals;
    logic [31:0] spill_hp;
    logic [4:0]  xsp, nexc;
    logic [7:0]  fflags, fcont;
    logic [3:0]  frk;
    val_t glb, loc, fun, aux, aux2, aux3;
    val_t rf [0:15];
    // Exception stack. Entries [0, xsp-2] live in the frame at
    // fbase + 0x44 + nloc*4 + 12*i (handler, {finally, depth}, xp).
    // Entry xsp-1 is only these registers until a push or a spill flushes it.
    logic [31:0] xh;
    logic [15:0] xv;
    logic        xf;
    val_t        xp;
    logic        noframe;
    logic        rf_pend;
    val_t        rf_pend_v;
    state_e      rf_resume;
    logic [31:0] spill_addr;
    logic [5:0]  spill_n, spill_ntag;
    logic [31:0] spill_words;
    logic        spill_had_link;
    logic [31:0] spill_prev;
    // 1 while the last change to sp was a push. Spill and reload do not count.
    logic        rf_mono, sp_hold, rf_reload_miss;
    logic [6:0]  sp_d;
    logic [5:0]  cfg_grow;
    logic        cfg_adapt;
    logic        spill_to_img;
    // Hot-local cache. Ages are 7 for the newest line. A dirty line is
    // ahead of its SRAM word until the frame is spilled.
    logic        lc_v [0:7];
    logic        lc_dirty [0:7];
    logic [2:0]  lc_age [0:7];
    logic [7:0]  lc_ix [0:7];
    val_t        lc_d [0:7];
    logic [3:0]  cfg_lc_n;
    logic        cfg_lc_wb, cfg_lc_dm;
    logic        cfg_ca;
    logic [2:0]  lc_ev_way;
    logic [7:0]  lc_ev_idx;
    val_t        lc_ev_val;
    logic        lc_ev_dirty;
    logic [3:0]  lc_fi;
    logic        lc_dirty_any;
    state_e      lc_fl_ret;
    always_comb begin
        lc_dirty_any = 1'b0;
        for (int k = 0; k < 8; k++)
            if (k < cfg_lc_n && lc_dirty[k]) lc_dirty_any = 1'b1;
    end
    logic [31:0] exc_base, stack_base;
    logic [15:0] srd_g, srd_off, stk_from;
    logic [31:0] srd_addr;
    val_t        srd_v;
    logic [31:0] srd_p0;
    logic [7:0]  srd_hops;
    logic [15:0] drop_left, ur_target;
    logic        drop_push_en;
    val_t        drop_push_v, ur_val;
    state_e      drop_then;
    val_t        gen;          // this generator, or VNULL
    val_t        inj;          // throw deferred into YIELD_FROM; VNONE if none
    logic        fl_img;       // fill from a heap image; keep fbase and fprev

    // current instruction
    logic [7:0]  op, ext;
    logic [31:0] arg, jt;
    logic [1:0]  ovr;

    // Call staging lives in ARGBUF. Slot 0 is the callable. Positionals
    // start at 32 so a prepended self fits in slot 31. ab_q is the last
    // read. ab_s stages the four words hook() and raise_err() store.
    val_t ab_q;
    val_t ab_s [0:3];
    logic [7:0] ab_lo, ab_pe, ab_nkw;
    // Builtins override dict. Mirrors the sysroot word firmware stores with
    // _sysset(SR_FW7, dict). Not a frame-header field and not an fflags bit.
    val_t bov;
    logic [3:0] crk, d_rk, r_rk;
    val_t cl_loc;
    logic [7:0] hk_id, nid;

    // GC-visible temporaries
    val_t t [0:7];
    val_t xc;

    // halting / counters
    logic        halted;
    logic [3:0]  hcode;
    logic [31:0] hval, cyc, nops;
    logic        trace;

    // fetch window
    logic [95:0] fwin;
    logic [31:0] fw_base;
    logic        fw_ok;
    logic [1:0]  fw_i;

    // scratch
    logic [31:0] x0, x1, x2, x3, x4;
    logic [7:0]  i0, i1, i2;
    logic [6:0]  s0, s1;
    logic        b0, b1;

    // subroutine registers
    val_t        ty_v, ty_t;                       // TYPEOF
    val_t        hk; logic [31:0] hh; logic hok;   // HASH
    val_t        si_v; logic [31:0] si_len, si_hash, si_addr; logic si_na;  // SINFO
    val_t        se_a, se_b; logic se_eq;
    val_t        ke_a, ke_b; logic ke_eq, ke_cx;
    logic [1:0]  lk_mode; logic lk_set, lk_found, lk_cx, lk_ro;
    val_t        lk_res;
    logic        lk_hasav;
    logic [31:0] al_n, al_a; logic al_ok, al_soft, al_gc;
    logic [31:0] sw_i; logic [1:0] sw_k;
    logic [31:0] fl_base, fl_i; logic [1:0] fl_k;
    logic [31:0] gi;
    val_t        is_t, is_c; logic is_r; logic [31:0] is_m, is_n, is_i;
    logic [31:0] at_q; logic [1:0] at_kind; logic at_ty, at_objd;
    val_t        at_v;
    val_t        tr_v; logic tr_r, tr_x;
    logic        tb_src, tb_nz; logic [7:0] tb_from, tb_n, tb_i; logic [31:0] tb_a; val_t tb_v;
    val_t        wb_v [0:7]; logic [31:0] wb_a; logic [3:0] wb_n, wb_i;
    logic it_stop, it_py, it_h; val_t it_val;
    // Resident microcode image. One subsystem at a time; SRAM holds the rest.
    localparam logic [3:0] SCR_NONE = 4'd0;
    localparam logic [3:0] SCR_LK   = 4'd1;
    localparam logic [3:0] SCR_RH   = 4'd2;
    localparam logic [3:0] SCR_SE   = 4'd3;
    localparam logic [3:0] SCR_AT   = 4'd4;
    localparam logic [3:0] SCR_IT   = 4'd5;
    localparam logic [3:0] SCR_LA   = 4'd6;
    localparam logic [3:0] SCR_KE   = 4'd7;
    logic [3:0]  scr_id, scr_cmd, scr_i;
    logic        scr_storing, scr_gosub_p;
    state_e      scr_ret, scr_gt, scr_gb;
    val_t        sV [0:7];
    logic [31:0] sA [0:7];
    // Live names for whichever image scr_id says is resident.
    `define lk_alloc sA[0]
    `define lk_tab   sA[1]
    `define lk_pos   sA[2]
    `define lk_start sA[3]
    `define lk_avail sA[4]
    `define lk_slot  sA[5]
    `define rh_alloc sA[0]
    `define rh_tab   sA[1]
    `define rh_i     sA[2]
    `define rh_p     sA[3]
    `define rh_used  sA[4]
    `define rh_k     sV[7]
    `define se_len   sA[0]
    `define se_hash  sA[1]
    `define se_pa    sA[2]
    `define se_pb    sA[3]
    `define se_i     sA[4]
    `define se_w     sA[5]
    `define at_m     sA[0]
    `define at_n     sA[1]
    `define at_i     sA[2]
    `define at_k     sA[3]
    `define at_t     sV[6]
    `define iv       sV
    `define it_i     sA[4]
    `define it_alloc sA[5]
    `define it_tab   sA[6]
    `define la_len   sA[0]
    `define la_alloc sA[1]
    `define la_items sA[2]
    `define la_new   sA[3]
    `define la_i     sA[4]
    `define ke_w0    sA[0]
    `define ke_w1    sA[1]
    logic [31:0] c_rc, c_md, c_cells, c_tflags;
    val_t        c_clos, c_defs, c_glob;
    logic [7:0]  c_nst, c_nexc, c_scope, c_rcf, c_npos, c_nkwo, c_ndef, c_ncell, c_cn;
    logic        c_fast, c_ismod;
    logic [31:0] c_ci;
    logic        rx_from; logic [3:0] rx_crk; logic [31:0] rx_off;
    logic [7:0]  rm_id;
    logic [31:0] uj;
    logic [7:0]  cv_i, cv_n, cv_j; logic [31:0] cv_bm, cv_items; logic [6:0] cv_base, cv_fidx;
    // Chunked star calls. ab_chunked is not an fflags bit. The directory
    // tuple lives in t[1] after the pointer slots are wiped. ab_lo/ab_pe/ab_nkw
    // stay 8 bits; n_pos is the wide counter.
    logic        ab_chunked, ab_ovf, cv_wide, cv_kw;
    logic [31:0] ab_npos, ab_nitems, ab_nblk, cv_k;
    logic [4:0]  ab_fill;
    logic [7:0]  ab_lo0;
    logic [15:0] cv_g, cv_pos_g, cv_fun_g;
    val_t        ab_blk;
    state_e      cv_ret;

    // ALU
    logic        alu_start, alu_done;
    logic [5:0]  alu_op;
    logic        na_f, nb_f, n_small, n_un;
    logic [63:0] na, nb, alu_res;
    logic [1:0]  alu_kind;
    logic [2:0]  alu_err;
    logic [7:0]  n_o;

    mpy_alu u_alu (
        .clk_i, .rst_n_i, .start_i(alu_start), .op_i(alu_op),
        .a_flt_i(na_f), .b_flt_i(nb_f), .a_i(na), .b_i(nb), .small_i(n_small),
        .done_o(alu_done), .res_o(alu_res), .rkind_o(alu_kind), .err_o(alu_err)
    );

    // decoder over the fetch window
    logic [31:0] f_off;
    logic [63:0] d_bytes;
    logic [3:0]  d_n;
    logic        d_valid, d_illegal, d_trunc, d_ovf, d_argv, d_extv;
    logic [3:0]  d_len;
    logic [7:0]  d_op, d_ext;
    logic [1:0]  d_fmt;
    entry_e      d_entry;
    logic signed [31:0] d_arg;
    logic        in_win;
    assign f_off = pc - fw_base;
    assign in_win = fw_ok && (pc >= fw_base) && (f_off < 32'd12);
    assign d_bytes = 64'(fwin >> {f_off[3:0], 3'b000});
    assign d_n = (f_off[3:0] > 4'd4) ? 4'(4'd12 - f_off[3:0]) : 4'd8;

    mpy_decode u_dec (
        .instr_valid_i(1'b1), .bytes_i(d_bytes), .nbytes_i(d_n),
        .decoded_valid_o(d_valid), .illegal_o(d_illegal), .truncated_o(d_trunc),
        .arg_overflow_o(d_ovf), .len_o(d_len), .opcode_o(d_op), .format_o(d_fmt),
        .entry_o(d_entry), .arg_valid_o(d_argv), .arg_o(d_arg),
        .extra_valid_o(d_extv), .extra_o(d_ext)
    );

    // frame geometry
    logic [31:0] ftop;
    // 17 header words: gen, spill_hp, and the ring metadata sit after the
    // original 14, and locals begin at byte 0x44.
    assign ftop = fbase + ((32'd17 + 32'(nloc) + 32'd3 * {27'd0, nexc}) << 2);

    // A function call in an NBA index trips a Verilator bug, so this is a macro.
    // Logical stack slot -> physical register. Wraps at 16. rf_base[5:4] stay 0.
    `define SX(L) (4'(rf_base[3:0] + 4'(L)))
    function automatic logic [31:0] loc_ptr(input logic [7:0] idx);
        loc_ptr = fbase + 32'h44 + {22'd0, idx, 2'b00};
    endfunction
    // Word 0 of exception slot `slot` in the frame at `base`.
    function automatic logic [31:0] exc_ptr(input logic [31:0] base, input logic [4:0] slot);
        exc_ptr = base + 32'h44 + ({24'd0, nloc} << 2) + (32'd12 * 32'(slot));
    endfunction
    function automatic logic [31:0] exc_words(input logic [31:0] base);
        exc_words = base + 32'h44 + ({24'd0, nloc} << 2);
    endfunction
    function automatic logic [31:0] ab_ptr(input logic [7:0] idx);
        ab_ptr = ABI_ARGBUF_BASE + {22'd0, idx, 2'b00};
    endfunction
    function automatic logic lc_is_hit(input logic [7:0] idx);
        lc_is_hit = 1'b0;
        for (int k = 0; k < 8; k++)
            if (k < cfg_lc_n && lc_v[k] && lc_ix[k] == idx) lc_is_hit = 1'b1;
    endfunction
    function automatic logic [2:0] lc_hit_way(input logic [7:0] idx);
        lc_hit_way = 3'd0;
        for (int k = 0; k < 8; k++)
            if (k < cfg_lc_n && lc_v[k] && lc_ix[k] == idx) lc_hit_way = k[2:0];
    endfunction
    function automatic logic [2:0] lc_pick(input logic [7:0] idx);
        logic [2:0] best;
        logic any_inv;
        best = 3'd0;
        any_inv = 1'b0;
        if (cfg_lc_dm && cfg_lc_n != 4'd0) begin
            lc_pick = idx[2:0] & (cfg_lc_n[2:0] - 3'd1);
        end else begin
            for (int k = 0; k < 8; k++) begin
                if (k < cfg_lc_n && !lc_v[k] && !any_inv) begin
                    best = k[2:0];
                    any_inv = 1'b1;
                end
            end
            if (!any_inv) begin
                for (int k = 1; k < 8; k++)
                    if (k < cfg_lc_n && lc_age[k] < lc_age[best]) best = k[2:0];
            end
            lc_pick = best;
        end
    endfunction
    task automatic lc_note(input logic [2:0] w);
        for (int k = 0; k < 8; k++) begin
            if (k[2:0] == w) lc_age[k] <= 3'd7;
            else if (lc_age[k] > lc_age[w]) lc_age[k] <= lc_age[k] - 3'd1;
        end
    endtask
    task automatic lc_inval();
        for (int k = 0; k < 8; k++) begin
            lc_v[k] <= 1'b0;
            lc_dirty[k] <= 1'b0;
        end
    endtask
    // Install idx=v. A dirty victim is written first and S_LC_EV finishes
    // the install. set_st is clear when the caller already started a memory op.
    task automatic lc_fill(input logic [7:0] idx, input val_t v, input logic dirty,
                           input logic set_st, input state_e done);
        logic [2:0] w;
        logic hit;
        hit = lc_is_hit(idx);
        w = hit ? lc_hit_way(idx) : lc_pick(idx);
        if (cfg_lc_n == 4'd0) begin
            if (set_st) st <= done;
        end else if (hit || !lc_v[w] || !lc_dirty[w] || !cfg_lc_wb || lc_ix[w] == idx) begin
            lc_v[w] <= 1'b1;
            lc_ix[w] <= idx;
            lc_d[w] <= v;
            lc_dirty[w] <= dirty && cfg_lc_wb;
            lc_note(w);
            if (set_st) st <= done;
        end else begin
            lc_ev_way <= w;
            lc_ev_idx <= idx;
            lc_ev_val <= v;
            lc_ev_dirty <= dirty && cfg_lc_wb;
            wr(loc_ptr(lc_ix[w]), lc_d[w], S_LC_EV);
        end
    endtask
`ifndef SYNTHESIS
    initial begin
        int grow_v, adapt_v, lc_n_v, lc_wb_v, lc_dm_v, ca_v;
        grow_v = GROW_CHUNK;
        adapt_v = GROW_ADAPT;
        lc_n_v = LC_N;
        lc_wb_v = LC_WB;
        lc_dm_v = 0;
        if (!$value$plusargs("GROW=%d", grow_v)) grow_v = GROW_CHUNK;
        if (!$value$plusargs("ADAPT=%d", adapt_v)) adapt_v = GROW_ADAPT;
        if (!$value$plusargs("LC=%d", lc_n_v)) lc_n_v = LC_N;
        if (!$value$plusargs("LCWB=%d", lc_wb_v)) lc_wb_v = LC_WB;
        if (!$value$plusargs("LCDM=%d", lc_dm_v)) lc_dm_v = 0;
        if (!$value$plusargs("CA=%d", ca_v)) ca_v = CA_EN;
        if (grow_v < MPY_RF_CHUNK_MIN) grow_v = MPY_RF_CHUNK_MIN;
        if (grow_v > MPY_RF_CHUNK_MAX) grow_v = MPY_RF_CHUNK_MAX;
        if (lc_n_v < 0) lc_n_v = 0;
        if (lc_n_v > 8) lc_n_v = 8;
        cfg_grow = grow_v[5:0];
        cfg_adapt = (adapt_v != 0);
        cfg_lc_n = lc_n_v[3:0];
        cfg_lc_wb = (lc_wb_v != 0);
        cfg_lc_dm = (lc_dm_v != 0);
        cfg_ca = (ca_v != 0);
    end
`else
    initial begin
        cfg_grow = GROW_CHUNK[5:0];
        cfg_adapt = (GROW_ADAPT != 0);
        cfg_lc_n = LC_N[3:0];
        cfg_lc_wb = (LC_WB != 0);
        cfg_lc_dm = 1'b0;
        cfg_ca = (CA_EN != 0);
    end
`endif

    function automatic val_t hdr_word(input logic [31:0] i);
        case (i)
            4'd0: hdr_word = {4'd0, fprev};
            4'd1: hdr_word = {4'd0, rc};
            4'd2: hdr_word = {4'd0, pc};
            4'd3: hdr_word = {4'd0, op_pc};
            4'd4: hdr_word = {4'd0, fflags, 1'b0, nloc[6:0], 3'b000, xsp, 1'b0, sp};
            4'd5: hdr_word = {4'd0, 11'd0, nexc, fcont, 4'd0, frk};
            4'd6: hdr_word = glb;
            4'd7: hdr_word = loc;
            4'd8: hdr_word = fun;
            4'd9: hdr_word = aux;
            4'd10: hdr_word = aux2;
            4'd11: hdr_word = aux3;
            4'd12: hdr_word = {4'd0, qbase};
            4'd13: hdr_word = {4'd0, cbase};
            4'd14: hdr_word = gen;
            4'd15: hdr_word = {4'd0, spill_hp};
            32'd16: hdr_word = {4'd0, 2'b00, spilled_reals, nloc, rf_base};
            default: hdr_word = VNULL;
        endcase
    endfunction

    logic        has_link;
    logic [15:0] resident_reals;
    logic [15:0] stk_depth;
    assign has_link = (sp != 7'd0) && mpy_is_rf_link(rf[`SX(7'd0)]);
    assign resident_reals = has_link ? (16'(sp) - 16'd1) : 16'(sp);
    assign stk_depth = spilled_reals + resident_reals;

    function automatic logic stk_hit(input logic [15:0] g);
        stk_hit = (g >= spilled_reals) && (g < stk_depth);
    endfunction
    function automatic logic [6:0] stk_slot(input logic [15:0] g);
        stk_slot = 7'(g - spilled_reals) + (has_link ? 7'd1 : 7'd0);
    endfunction
    function automatic val_t stk_val(input logic [15:0] g);
        stk_val = rf[`SX(stk_slot(g))];
    endfunction

    assign m_req_o = m_req;
    assign m_we_o = m_we;
    assign m_tag_we_o = m_tag_we;
    assign m_be_o = m_be;
    assign m_addr_o = m_addr;
    assign m_wdata_o = m_wdata;
    assign m_wtag_o = m_wtag;
    assign gc_alloc_nbytes_o = al_n << 2;
    assign gc_root0_lo_o = ABI_FRAME_BASE;
    // The resident ring is snapshotted at ftop before a collection.
    assign gc_root0_hi_o = noframe ? ABI_FRAME_BASE : (ftop + {23'd0, sp, 2'b00});
    assign gc_root1_lo_o = ABI_SCHED_BASE;
    assign gc_root1_hi_o = ABI_GC_POOL_BASE;
    assign halted_o = halted;
    assign halt_code_o = hcode;
    assign halt_value_o = hval;
    assign cycles_o = cyc;
    assign ops_o = nops;
    assign trace_o = trace;
    assign trace_pc_o = op_pc;
    assign trace_op_o = op;
    assign trace_sp_o = sp;

    logic gc_alloc_req, gc_collect_req;
    assign gc_alloc_req_o = gc_alloc_req;
    assign gc_collect_req_o = gc_collect_req;

    // Accelerator command, a one-cycle pulse. A ship still landing counts
    // as a full queue, so two ships one cycle apart cannot overrun it.
    logic        ca_valid;
    logic [31:0] ca_dst, ca_src, ca_n;
    logic        ca_ok;
    assign ca_valid_o = ca_valid;
    assign ca_dst_o = ca_dst;
    assign ca_src_o = ca_src;
    assign ca_n_o = ca_n;
    assign ca_ok = ca_ready_i && !ca_valid;

    // ------------------------------------------------------------------
    // Microcode helpers
    // ------------------------------------------------------------------
    task automatic rd(input logic [31:0] a, input state_e nxt);
        m_addr <= a; m_we <= 1'b0; m_tag_we <= 1'b0; m_be <= 4'hF; m_req <= 1'b1;
        wret <= nxt; st <= S_MWAIT;
    endtask
    task automatic wr(input logic [31:0] a, input val_t v, input state_e nxt);
        m_addr <= a; m_wdata <= v[31:0]; m_wtag <= v[35:32];
        m_we <= 1'b1; m_tag_we <= 1'b1; m_be <= 4'hF; m_req <= 1'b1;
        // The same store that publishes the override dict keeps the probe flop.
        if (a == ABI_SYSROOT_BASE + 4 * ABI_SR_FW7) bov <= v;
        wret <= nxt; st <= S_MWAIT;
    endtask
    task automatic wrb(input logic [31:0] a, input logic [7:0] b, input state_e nxt);
        m_addr <= {a[31:2], 2'b00}; m_wdata <= {4{b}}; m_wtag <= 4'd0;
        m_we <= 1'b1; m_tag_we <= 1'b0; m_be <= 4'b0001 << a[1:0]; m_req <= 1'b1;
        wret <= nxt; st <= S_MWAIT;
    endtask
    function automatic logic [31:0] scr_addr(input logic [3:0] id, input logic [3:0] wi);
        logic [31:0] basew;
        case (id)
            SCR_LK: basew = 32'd0;
            SCR_RH: basew = 32'd8;
            SCR_SE: basew = 32'd16;
            SCR_AT: basew = 32'd24;
            SCR_IT: basew = 32'd32;
            SCR_LA: basew = 32'd40;
            default: basew = 32'd48;
        endcase
        scr_addr = MPY_CORE_SCRATCH_BASE + ((basew + {28'd0, wi}) << 2);
    endfunction
    function automatic logic [3:0] scr_words(input logic [3:0] id);
        scr_words = (id == SCR_KE) ? 4'd4 : 4'd8;
    endfunction
    function automatic logic scr_tag(input logic [3:0] id, input logic [3:0] wi);
        case (id)
            SCR_RH: scr_tag = (wi == 4'd7);
            SCR_AT: scr_tag = (wi == 4'd6);
            SCR_IT: scr_tag = (wi <= 4'd3);
            default: scr_tag = 1'b0;
        endcase
    endfunction
    task automatic gosub(input state_e target, input state_e back);
        rstk[rsp] <= back; rsp <= rsp + 5'd1; st <= target;
    endtask
    task automatic ret();
        st <= rstk[rsp - 5'd1]; rsp <= rsp - 5'd1;
    endtask
    task automatic scr_go_store(input logic [3:0] id, input state_e back);
        scr_cmd <= id; scr_i <= 4'd0; scr_storing <= 1'b1; scr_gosub_p <= 1'b0;
        scr_ret <= back; st <= S_SCR;
    endtask
    task automatic scr_go_load(input logic [3:0] id, input state_e back);
        scr_cmd <= id; scr_i <= 4'd0; scr_storing <= 1'b0; scr_gosub_p <= 1'b0;
        scr_ret <= back; st <= S_SCR;
    endtask
    task automatic scr_go_store_gosub(input logic [3:0] id, input state_e target, input state_e back);
        scr_cmd <= id; scr_i <= 4'd0; scr_storing <= 1'b1; scr_gosub_p <= 1'b1;
        scr_gt <= target; scr_gb <= back; st <= S_SCR;
    endtask
    // Save a different resident image, then load `id`, then re-enter `back`.
    task automatic scr_ensure(input logic [3:0] id, input state_e back);
        if (scr_id != SCR_NONE) scr_go_store(scr_id, back);
        else scr_go_load(id, back);
    endtask
    // Own `id` without reading SRAM. A different resident image is stored
    // first. Callers write every field before reading it.
    task automatic scr_adopt(input logic [3:0] id, input state_e back);
        if (scr_id != SCR_NONE && scr_id != id) scr_go_store(scr_id, back);
        else if (scr_id != id) begin scr_id <= id; st <= back; end
        else st <= back;
    endtask
    // Store the caller before entering a different scratch subsystem.
    task automatic gosub_scr(input logic [3:0] dest, input state_e target, input state_e back);
        if (scr_id != SCR_NONE && scr_id != dest) scr_go_store_gosub(scr_id, target, back);
        else gosub(target, back);
    endtask
    task automatic halt(input logic [3:0] code, input logic [31:0] value);
        halted <= 1'b1; hcode <= code; hval <= value; st <= S_HALT;
    endtask
    task automatic push(input val_t v);
        if (sp >= 7'(MPY_RF_DEPTH)) begin
            rf_pend <= 1'b1;
            rf_pend_v <= v;
        end else begin
            rf[`SX(sp)] <= v;
            sp <= sp + 7'd1;
        end
    endtask
    task automatic raise_msg(input logic [7:0] id);
        rm_id <= id; rsp <= 5'd0; st <= S_RMSG;
    endtask
    task automatic raise_val(input val_t v);
        xc <= v; rx_from <= 1'b0; rsp <= 5'd0; st <= S_RAISE;
    endtask
    task automatic raise_err(input logic [7:0] code, input val_t a, input val_t b);
        ab_s[0] <= vint({24'd0, code}); ab_s[1] <= a; ab_s[2] <= b; ab_s[3] <= VNULL;
        ab_lo <= 8'd32; ab_pe <= 8'd35; ab_nkw <= 8'd0; crk <= ABI_RK_PUSH;
        ab_chunked <= 1'b0;
        hk_id <= ABI_HOOK_RAISE; rsp <= 5'd0; i0 <= 8'd0; st <= S_AB_HW;
    endtask
    // Call hook `id` with n positional args; the result is delivered by rk.
    // All four words are stored into ARGBUF before S_HOOK.
    task automatic hook(input logic [7:0] id, input logic [3:0] rk, input logic [7:0] n,
                        input val_t a, input val_t b, input val_t c, input val_t d);
        ab_s[0] <= a; ab_s[1] <= b; ab_s[2] <= c; ab_s[3] <= d;
        ab_lo <= 8'd32; ab_pe <= 8'd32 + n; ab_nkw <= 8'd0; crk <= rk;
        ab_chunked <= 1'b0;
        hk_id <= id; i0 <= 8'd0; st <= S_AB_HW;
    endtask
    // Call ARGBUF slot 0 with the prepared args; result by rk.
    task automatic deliver(input val_t v, input logic [3:0] rk);
        t[7] <= v; d_rk <= rk; st <= S_DELIVER;
    endtask
    task automatic wblock(input logic [31:0] a, input logic [3:0] n, input state_e back);
        wb_a <= a; wb_n <= n; wb_i <= 4'd0; gosub(S_WB, back);
    endtask
    task automatic lookup(input val_t d, input val_t key, input val_t val, input logic [1:0] mode,
                          input logic set, input state_e back);
        t[4] <= d; t[5] <= key; t[6] <= val; lk_mode <= mode; lk_set <= set;
        gosub_scr(SCR_LK, S_LK, back);
    endtask
    task automatic alloc(input logic [31:0] n, input state_e back);
        al_n <= (n == 32'd0) ? 32'd1 : n; gosub(S_AL, back);
    endtask
    // Copy n words from src to dst on the accelerator. The caller checked ca_ok.
    task automatic ca_ship(input logic [31:0] dst, input logic [31:0] src, input logic [31:0] n);
        ca_valid <= 1'b1; ca_dst <= dst; ca_src <= src; ca_n <= n;
    endtask

    // ------------------------------------------------------------------
    // Main sequencer
    // ------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_n_i) begin : seq
        logic [31:0] v0, v1, v2, v3;
        logic [7:0]  vi;
        logic [6:0]  vs0, vs1;
        logic        vb;
        if (!rst_n_i) begin
            st <= S_BOOT;
            rsp <= 5'd0;
            m_req <= 1'b0; m_we <= 1'b0; m_tag_we <= 1'b0; m_be <= 4'hF;
            m_addr <= 32'd0; m_wdata <= 32'd0; m_wtag <= 4'd0;
            gc_alloc_req <= 1'b0; gc_collect_req <= 1'b0;
            alu_start <= 1'b0;
            ca_valid <= 1'b0; ca_dst <= 32'd0; ca_src <= 32'd0; ca_n <= 32'd0;
            halted <= 1'b0; hcode <= 4'd0; hval <= 32'd0;
            cyc <= 32'd0; nops <= 32'd0; trace <= 1'b0;
            fw_ok <= 1'b0; fw_base <= 32'd0;
            h_nq <= 32'd0; h_qext <= 32'd0; h_qextn <= 32'd0; qd_nxt <= S_BOOT;
            sp <= 7'd0; nloc <= 8'd0; rf_base <= 6'd0; spilled_reals <= 16'd0;
            spill_hp <= MPY_CORE_SCRATCH_BASE; rf_pend <= 1'b0;
            scr_id <= SCR_NONE; scr_i <= 4'd0; scr_storing <= 1'b0; scr_gosub_p <= 1'b0;
            for (int k = 0; k < 8; k++) begin sA[k] <= 32'd0; sV[k] <= VNULL; end
            rf_mono <= 1'b1; sp_hold <= 1'b0; sp_d <= 7'd0; rf_reload_miss <= 1'b0;
            xsp <= 5'd0; nexc <= 5'd0;
            xh <= 32'd0; xv <= 16'd0; xf <= 1'b0; xp <= VNULL;
            noframe <= 1'b1; ovr <= ABI_OVR_NONE;
            cl_loc <= VNULL; al_soft <= 1'b0;
            fflags <= 8'd0; fcont <= 8'd0; frk <= ABI_RK_HALT;
            fbase <= ABI_FRAME_BASE; fprev <= 32'd0;
            gen <= VNULL; inj <= VNONE; fl_img <= 1'b0; spill_to_img <= 1'b0;
            lc_fl_ret <= S_SPILL;
            for (int k = 0; k < 8; k++) t[k] <= VNULL;
            xc <= VNULL;
            bov <= VNULL;
            ab_chunked <= 1'b0; ab_ovf <= 1'b0; cv_wide <= 1'b0; cv_kw <= 1'b0;
            ab_npos <= 32'd0; ab_nitems <= 32'd0; ab_nblk <= 32'd0; ab_fill <= 5'd0;
            ab_lo0 <= 8'd0; ab_blk <= VNULL; cv_k <= 32'd0;
            cv_g <= 16'd0; cv_pos_g <= 16'd0; cv_fun_g <= 16'd0;
            ab_q <= VNULL;
            for (int k = 0; k < 4; k++) ab_s[k] <= VNULL;
            for (int k = 0; k < MPY_RF_DEPTH; k++) rf[k] <= VNULL;
            for (int k = 0; k < 8; k++) begin
                lc_v[k] <= 1'b0;
                lc_dirty[k] <= 1'b0;
                lc_age[k] <= 3'd0;
            end
            lc_fi <= 4'd0;
        end else begin
            m_req <= 1'b0;
            gc_alloc_req <= 1'b0;
            gc_collect_req <= 1'b0;
            alu_start <= 1'b0;
            ca_valid <= 1'b0;
            trace <= 1'b0;
            if (!halted) cyc <= cyc + 32'd1;
            // A spill or a reload moves sp without a push or a pop.
            if (sp_hold) sp_hold <= 1'b0;
            else if (sp < sp_d) rf_mono <= 1'b0;
            else if (sp > sp_d) rf_mono <= 1'b1;
            sp_d <= sp;

            if (rf_pend && st != S_MWAIT && st != S_RF_SPILL && st != S_RF_SPILL_W &&
                st != S_RF_RELOAD && st != S_RF_RELOAD_R && st != S_RF_RELOAD_G) begin
                if (sp >= 7'(MPY_RF_DEPTH)) begin
                    rf_resume <= st;
                    st <= S_RF_SPILL;
                end else begin
                    rf[`SX(sp)] <= rf_pend_v;
                    sp <= sp + 7'd1;
                    rf_pend <= 1'b0;
                end
            end else case (st)
            S_HALT: ;

            S_MWAIT: if (m_ack_i) begin
                md <= m_rdata_i; mt <= m_rtag_i;
                if (m_fault_i) begin
                    case (m_fault_reason_i)
                        MPY_FAULT_UNALIGNED: halt(ABI_HALT_UNALIGNED, m_addr);
                        MPY_FAULT_FLASH_STORE: halt(ABI_HALT_FLASH_STORE, m_addr);
                        default: halt(ABI_HALT_BUS, m_addr);
                    endcase
                end else st <= wret;
            end

            // Move one scratch image between sA/sV and the reservation.
            S_SCR: if (scr_i == scr_words(scr_cmd)) begin
                scr_gosub_p <= 1'b0;
                if (scr_storing) scr_id <= SCR_NONE;
                else scr_id <= scr_cmd;
                if (scr_gosub_p) gosub(scr_gt, scr_gb);
                else st <= scr_ret;
            end else if (scr_storing) begin
                if (scr_tag(scr_cmd, scr_i))
                    wr(scr_addr(scr_cmd, scr_i), sV[scr_i[2:0]], S_SCR);
                else
                    wr(scr_addr(scr_cmd, scr_i), {4'd0, sA[scr_i[2:0]]}, S_SCR);
                scr_i <= scr_i + 4'd1;
            end else rd(scr_addr(scr_cmd, scr_i), S_SCR_CAP);
            S_SCR_CAP: begin
                if (scr_tag(scr_cmd, scr_i)) sV[scr_i[2:0]] <= mv;
                else sA[scr_i[2:0]] <= md;
                scr_i <= scr_i + 4'd1;
                st <= S_SCR;
            end

            // ---------------- boot ----------------
            S_BOOT: rd(32'd0, S_BOOT1);
            S_BOOT1: if (md != ABI_IMAGE_MAGIC) halt(ABI_HALT_BAD_IMAGE, md);
                     else rd(4 * ABI_HDR_QSTR_DESC, S_BOOT2);
            S_BOOT2: begin
                h_qdesc <= md; h_qext <= 32'd0; h_qextn <= 32'd0;
                rd(4 * ABI_HDR_QSTR_COUNT, S_BOOT2B);
            end
            S_BOOT2B: begin h_nq <= md; rd(4 * ABI_HDR_BUILTINS, S_BOOT3); end
            S_BOOT3: begin h_builtins <= md; rd(4 * ABI_HDR_HOOKS, S_BOOT4); end
            S_BOOT4: begin h_hooks <= md; rd(4 * ABI_HDR_MSGS, S_BOOT5); end
            S_BOOT5: begin h_msgs <= md; rd(4 * ABI_HDR_CHARS, S_BOOT6); end
            S_BOOT6: begin h_chars <= md; rd(4 * ABI_HDR_EMPTY_TUPLE, S_BOOT7); end
            S_BOOT7: begin h_empty <= md; rd(TT + 4 * ABI_T_FUNCTION, S_BOOT8); end
            S_BOOT8: begin ty_fun <= mv; rd(TT + 4 * ABI_T_BOUND_METHOD, S_BOOT9); end
            S_BOOT9: begin ty_bm <= mv; rd(TT + 4 * ABI_T_CELL, S_BOOT10); end
            S_BOOT10: begin ty_cell <= mv; rd(TT + 4 * ABI_T_OBJECT, S_BOOT11); end
            S_BOOT11: begin ty_obj <= mv; rd(TT + 4 * ABI_T_STOPITERATION, S_BOOT12); end
            S_BOOT12: begin ty_stop <= mv; rd(TT + 4 * ABI_T_MEMORYERROR, S_BOOT13); end
            S_BOOT13: begin ty_mem <= mv; rd(TT + 4 * ABI_T_SLICE, S_BOOT14); end
            S_BOOT14: begin ty_slice <= mv; rd(h_msgs + 4 * ABI_MSG_MEMORY, S_BOOT15); end
            S_BOOT15: begin
                wb_v[0] <= vint(ABI_OB_EXCEPTION); wb_v[1] <= ty_mem; wb_v[2] <= mv;
                wb_v[3] <= VNULL; wb_v[4] <= VNULL;
                wblock(EMERG_ADDR, 4'd5, S_BOOT16);
            end
            S_BOOT16: begin
                ab_lo <= 8'd32; ab_pe <= 8'd32; ab_nkw <= 8'd0; crk <= ABI_RK_HALT;
                hk_id <= ABI_HOOK_BOOT; st <= S_HOOK;
            end

            // ---------------- hooks and calls ----------------
            // hook/raise_err staged four words; store them, then dispatch.
            S_AB_HW: begin
                wr(ab_ptr(8'd32 + i0), ab_s[i0[1:0]], (i0 == 8'd3) ? S_HOOK : S_AB_HW);
                i0 <= i0 + 8'd1;
            end
            S_HOOK: rd(h_hooks + 4 * hk_id, S_HOOK1);
            S_HOOK1: if (mv == VNULL) halt(ABI_HALT_INTERNAL, {24'd0, hk_id});
                     else wr(ab_ptr(8'd0), mv, S_CALL);

            S_CALL: rd(ab_ptr(8'd0), S_CALL_Q);
            S_CALL_Q: begin
                ab_q <= mv;
                if (tg(mv) != ABI_TAG_OBJECT) st <= S_HCALL;
                else rd(adr(mv), S_CALL_K);
            end
            S_CALL_K: begin
                case (md)
                    ABI_OB_FUNCTION: begin c_ismod <= 1'b0; st <= S_CF; end
                    ABI_OB_BOUND_METHOD: rd(adr(ab_q) + 12, S_CALL_BS);
                    ABI_OB_BUILTIN: rd(adr(ab_q) + 8, S_CALL_NI);
                    ABI_OB_TYPE: rd(adr(ab_q) + 28, S_CALL_TF);
                    default: st <= S_HCALL;
                endcase
            end
            S_CALL_BS: if (ab_chunked) st <= S_CALL_BSC;
                       else if (ab_lo <= 8'd2) raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
                       else begin
                           wr(ab_ptr(ab_lo - 8'd1), mv, S_CALL_BS2);
                           ab_lo <= ab_lo - 8'd1;
                       end
            S_CALL_BS2: rd(adr(ab_q) + 8, S_CALL_BF);
            S_CALL_BF: wr(ab_ptr(8'd0), mv, S_CALL);
            S_CALL_NI: begin nid <= md[7:0]; st <= S_NAT; end
            S_CALL_TF: begin
                c_tflags <= md;
                if (md & ABI_TF_INST) st <= S_NEW;
                else rd(adr(ab_q) + 32, S_CALL_MN);
            end
            S_CALL_MN: if (mv == VNULL) raise_err(ABI_ERR_CANT_CREATE, ab_q, VNULL);
                       else if (ab_lo <= 8'd2) raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
                       else begin
                           ab_s[0] <= mv;
                           wr(ab_ptr(ab_lo - 8'd1), ab_q, S_CALL_MN2);
                           ab_lo <= ab_lo - 8'd1;
                       end
            S_CALL_MN2: wr(ab_ptr(8'd0), ab_s[0], S_CALL);

            // Anything else callable goes through _call(obj, args, kw).
            S_HCALL: begin
                tb_src <= 1'b0; tb_nz <= 1'b0; tb_from <= ab_lo; tb_n <= ab_pe - ab_lo;
                gosub(S_TUP, S_HC1);
            end
            S_HC1: begin
                t[0] <= tb_v; tb_src <= 1'b0; tb_nz <= 1'b1; tb_from <= ab_pe; tb_n <= {ab_nkw[6:0], 1'b0};
                gosub(S_TUP, S_HC2);
            end
            S_HC2: hook(ABI_HOOK_CALL, crk, 8'd3, ab_q, t[0], tb_v, VNULL);

            // Instance of a class with TF_INST.
            S_NEW: if (c_tflags & ABI_TF_EXC) begin
                       tb_src <= 1'b0; tb_nz <= 1'b0; tb_from <= ab_lo; tb_n <= ab_pe - ab_lo;
                       gosub(S_TUP, S_NEW_X);
                   end else alloc(32'd3, S_NEW_I);
            S_NEW_X: begin t[0] <= tb_v; alloc(32'd5, S_NEW_XA); end
            S_NEW_XA: begin
                wb_v[0] <= vint(ABI_OB_EXCEPTION); wb_v[1] <= ab_q; wb_v[2] <= t[0];
                wb_v[3] <= VNULL; wb_v[4] <= VNULL;
                t[1] <= vobj(al_a);
                wblock(al_a, 4'd5, S_NEW_INIT);
            end
            S_NEW_I: begin
                wb_v[0] <= vint(ABI_OB_INSTANCE); wb_v[1] <= ab_q; wb_v[2] <= VNULL;
                t[1] <= vobj(al_a);
                wblock(al_a, 4'd3, S_NEW_INIT);
            end
            S_NEW_INIT: if (scr_id != SCR_AT) scr_ensure(SCR_AT, S_NEW_INIT);
                        else begin
                            `at_t <= ab_q; at_ty <= 1'b1; at_objd <= 1'b0; at_q <= ABI_Q_INIT_D;
                            gosub(S_AT_MRO, S_NEW_IR);
                        end
            S_NEW_IR: if (at_kind == 2'd1) begin
                    wr(ab_ptr(ab_lo - 8'd1), t[1], S_NEW_IR2);
                    ab_lo <= ab_lo - 8'd1;
                    aux <= t[1]; aux2 <= vint({28'd0, crk}); aux3 <= vint({24'd0, fcont});
                    fcont <= ABI_CONT_INIT; crk <= ABI_RK_CONT;
                end else deliver(t[1], crk);
            S_NEW_IR2: wr(ab_ptr(8'd0), at_v, S_CALL);

            // ---- bytecode function call ----
            S_CF: begin ab_lo0 <= ab_lo; rd(adr(ab_q) + 8, S_CF1); end
            S_CF1: begin c_rc <= md; rd(adr(ab_q) + 12, S_CF2); end
            S_CF2: begin c_clos <= mv; rd(adr(ab_q) + 16, S_CF3); end
            S_CF3: begin c_defs <= mv; rd(adr(ab_q) + 24, S_CF4); end
            S_CF4: begin
                c_glob <= mv;
                if (c_clos != VNULL) rd(adr(c_clos), S_CF_CLN);
                else st <= S_CF_SIG;
            end
            S_CF_CLN: begin c_cn <= md[7:0]; st <= S_CF_CLI; end
            S_CF_CLI: if (c_cn == 8'd0) st <= S_CF_SIG;
                      else if (ab_lo <= 8'd2) raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
                      else rd(adr(c_clos) + 4 * c_cn, S_CF_CLP);
            S_CF_CLP: begin
                wr(ab_ptr(ab_lo - 8'd1), mv, S_CF_CLI);
                ab_lo <= ab_lo - 8'd1; c_cn <= c_cn - 8'd1;
            end
            S_CF_SIG: rd(c_rc + 4 * ABI_RC_SIG, S_CF_SIG2);
            S_CF_SIG2: begin
                c_nst <= md[7:0]; c_nexc <= md[15:8]; c_scope <= md[23:16]; c_rcf <= md[31:24];
                rd(c_rc + 4 * ABI_RC_ARGS, S_CF_ARGS);
            end
            S_CF_ARGS: begin
                c_npos <= md[7:0]; c_nkwo <= md[15:8]; c_ndef <= md[23:16]; c_ncell <= md[31:24];
                rd(c_rc + 4 * ABI_RC_CELLS, S_CF_CHK);
            end
            S_CF_CHK: begin
                c_cells <= md;
                v0 = noframe ? ABI_FRAME_BASE : (ftop + {23'd0, sp, 2'b00});
                v1 = v0 + ((32'd17 + c_nst + 32'd3 * c_nexc) << 2);
                v2 = ab_pe - ab_lo;
                c_fast <= !ab_chunked && (ab_nkw == 8'd0) && (c_nkwo == 8'd0) &&
                          (v2 + c_ndef >= c_npos) &&
                          ((v2 <= c_npos) || (c_scope & ABI_SCOPE_VARARGS));
                x3 <= v0;
                if (v1 > spill_hp)
                    raise_msg(ABI_MSG_RECURSION);
                else if (noframe) st <= S_CF_SW;
                else gosub(S_SPILL, S_CF_SW);
            end
            S_CF_SW: begin
                fprev <= noframe ? 32'd0 : fbase;
                fbase <= x3; noframe <= 1'b0;
                rc <= c_rc; nloc <= c_nst; nexc <= c_nexc[4:0];
                sp <= 7'd0; rf_base <= 6'd0; spilled_reals <= 16'd0; rf_pend <= 1'b0;
                xsp <= 5'd0; i0 <= 8'd0;
                fflags <= ((c_rcf & ABI_RC_FLAG_FIRMWARE) ? FF_FW : 8'd0) |
                          ((c_rcf & ABI_RC_FLAG_GENERATOR) ? FF_GEN : 8'd0);
                frk <= crk; fcont <= 8'd0;
                gen <= VNULL;
                glb <= c_ismod ? cl_loc : c_glob;
                loc <= cl_loc; cl_loc <= VNULL;
                fun <= c_ismod ? VNULL : ab_q;
                aux <= VNULL; aux2 <= VNULL; aux3 <= VNULL;
                for (int k = 0; k < MPY_RF_DEPTH; k++) rf[k] <= VNULL;
                lc_inval();
                st <= S_LCLR;
            end
            S_LCLR: if (i0 == nloc) rd(c_rc + 4 * ABI_RC_OP_START, S_CF_PC);
                    else wr(loc_ptr(i0), VNULL, S_LCLR2);
            S_LCLR2: begin i0 <= i0 + 8'd1; st <= S_LCLR; end
            S_CF_PC: begin pc <= md; op_pc <= md; rd(c_rc + 4 * ABI_RC_MODULE, S_CF_MD); end
            S_CF_MD: begin c_md <= md; rd(md + 4 * ABI_MD_QSTRS, S_CF_Q); end
            S_CF_Q: begin qbase <= md; rd(c_md + 4 * ABI_MD_CONSTS, S_CF_C); end
            S_CF_C: begin
                cbase <= md;
                if (c_fast) st <= S_BF;
                else st <= S_BS;
            end
            // fast positional binding
            S_BF: begin
                i0 <= 8'(ab_pe - ab_lo);
                i1 <= 8'd0;
                st <= S_BF_P;
            end
            S_BF_P: if (i1 >= c_npos || i1 >= i0) st <= S_BF_DEF;
                    else rd(ab_ptr(ab_lo + i1), S_BF_PR);
            S_BF_PR: wr(loc_ptr(i1), mv, S_BF_P2);
            S_BF_P2: begin i1 <= i1 + 8'd1; st <= S_BF_P; end
            S_BF_DEF: if (i0 >= c_npos) st <= S_BF_VA;
                      else rd(adr(c_defs) + 4 + 4 * (i0 - (c_npos - c_ndef)), S_BF_DEF2);
            S_BF_DEF2: begin wr(loc_ptr(i0), mv, S_BF_DEF); i0 <= i0 + 8'd1; end
            S_BF_VA: if (c_scope & ABI_SCOPE_VARARGS) begin
                    tb_src <= 1'b0; tb_nz <= 1'b0;
                    tb_from <= ab_lo + c_npos;
                    tb_n <= (ab_pe - ab_lo > c_npos) ? (ab_pe - ab_lo - c_npos) : 8'd0;
                    gosub(S_TUP, S_BF_VA2);
                end else st <= S_BF_KW;
            S_BF_VA2: begin wr(loc_ptr(c_npos + c_nkwo), tb_v, S_BF_KW); end
            // **kwargs of a call without keywords: a fresh empty dict
            S_BF_KW: begin
                c_ci <= 32'd0;
                if (c_scope & ABI_SCOPE_VARKEYWORDS) alloc(32'd4, S_BF_KW2);
                else st <= S_CELLS;
            end
            S_BF_KW2: begin
                wb_v[0] <= vint(32'd0); wb_v[1] <= vint(32'd0); wb_v[2] <= VNULL; wb_v[3] <= vint(32'd0);
                i1 <= c_npos + c_nkwo + ((c_scope & ABI_SCOPE_VARARGS) ? 8'd1 : 8'd0);
                wblock(al_a, 4'd4, S_BF_KW3);
            end
            S_BF_KW3: wr(loc_ptr(i1), vmut(al_a, ABI_MUT_DICT), S_CELLS);
            S_CELLS: if (c_ci == c_ncell) begin
                    fflags <= fflags & ~FF_NOTB;
                    if (fflags & FF_GEN) st <= S_GN_AL;
                    else st <= S_FETCH;
                end else rd(c_cells + 4 * c_ci, S_CELL_I);
            S_CELL_I: begin i1 <= md[7:0]; rd(loc_ptr(md[7:0]), S_CELL_RD); end
            S_CELL_RD: begin t[3] <= mv; alloc(32'd3, S_CELL_A); end
            S_CELL_A: begin
                wb_v[0] <= vint(ABI_OB_CELL); wb_v[1] <= ty_cell; wb_v[2] <= t[3];
                c_ci <= c_ci + 32'd1;
                wblock(al_a, 4'd3, S_CELL_B);
            end
            S_CELL_B: wr(loc_ptr(i1), vobj(al_a), S_CELLS);
            // firmware binding: _bind(fun, args, kw) returns the locals
            S_BS: if (ab_chunked) st <= S_BS_W;
                  else rd(ab_ptr(8'd0), S_BS_Q);
            S_BS_Q: begin
                fflags <= fflags | FF_NOTB; fcont <= ABI_CONT_BIND;
                t[2] <= mv;
                tb_src <= 1'b0; tb_nz <= 1'b0; tb_from <= ab_lo; tb_n <= ab_pe - ab_lo;
                gosub(S_TUP, S_BS1);
            end
            S_BS1: begin
                t[0] <= tb_v; tb_src <= 1'b0; tb_nz <= 1'b1; tb_from <= ab_pe; tb_n <= {ab_nkw[6:0], 1'b0};
                gosub(S_TUP, S_BS2);
            end
            S_BS2: hook(ABI_HOOK_BIND, ABI_RK_CONT, 8'd3, t[2], t[0], tb_v, VNULL);

            // _callns(code, ns) when code is a module descriptor
            S_CNS: begin c_rc <= md; c_defs <= VNULL; c_clos <= VNULL; st <= S_CF_SIG; end

            // ---------------- frames ----------------
            // Flush the cached exception top before the header, the image
            // copy, or the register snapshot. A collection reaches GC roots
            // through this spill, so xp has to be in the frame.
            S_SPILL: if (lc_dirty_any) begin lc_fi <= 4'd0; lc_fl_ret <= S_SPILL; st <= S_LC_FL; end
                     else begin sw_i <= 32'd0; sw_k <= 2'd0; gosub(S_XFLUSH, S_SP_H); end
            S_SP_H: if (sw_i == 32'd17) begin
                        sw_i <= 32'd0; sw_k <= 2'd0;
                        st <= spill_to_img ? S_SP_L : S_SP_R;
                    end
                    else begin wr(fbase + (sw_i << 2), hdr_word(sw_i), S_SP_H); sw_i <= sw_i + 32'd1; end
            // Generator image: locals still sit in the reserve frame at x4.
            S_SP_L: if (sw_i == nloc) begin sw_i <= 32'd0; sw_k <= 2'd0; st <= S_SP_X; end
                    else rd(x4 + 32'h44 + (sw_i << 2), S_SP_L2);
            S_SP_L2: begin wr(fbase + 32'h44 + (sw_i << 2), mv, S_SP_L); sw_i <= sw_i + 32'd1; end
            // 3*xsp exception words, one read/write pair each. The flush
            // already put the top into the old frame, so this is a copy.
            S_SP_X: if (sw_i == 32'(xsp) * 32'd3) begin sw_i <= 32'd0; st <= S_SP_R; end
                    else if (sw_k == 2'd0) begin
                        rd(exc_words(x4) + (sw_i << 2), S_SP_X);
                        sw_k <= 2'd1;
                    end else begin
                        wr(exc_words(fbase) + (sw_i << 2), mv, S_SP_X);
                        sw_k <= 2'd0;
                        sw_i <= sw_i + 32'd1;
                    end
            S_SP_R: if (sw_i == sp) ret();
                    else begin
                        wr(ftop + (sw_i << 2), rf[`SX(sw_i[6:0])], S_SP_R);
                        sw_i <= sw_i + 32'd1;
                    end

            S_FILL: begin
                fl_i <= 32'd0; fw_ok <= 1'b0; lc_inval();
                if (!fl_img) fbase <= fl_base;
                rd(fl_base, S_FL_H);
            end
            S_FL_H: begin
                case (fl_i)
                    4'd0: if (!fl_img) fprev <= md;
                    4'd1: rc <= md;
                    4'd2: pc <= md;
                    4'd3: op_pc <= md;
                    4'd4: begin sp <= md[6:0]; xsp <= md[12:8]; fflags <= md[31:24]; end
                    4'd5: begin frk <= md[3:0]; fcont <= md[15:8]; nexc <= md[20:16]; end
                    4'd6: glb <= mv;
                    4'd7: loc <= mv;
                    4'd8: fun <= mv;
                    4'd9: aux <= mv;
                    4'd10: aux2 <= mv;
                    4'd11: aux3 <= mv;
                    4'd12: qbase <= md;
                    4'd13: cbase <= md;
                    4'd14: gen <= mv;
                    4'd15: spill_hp <= md;
                    default: if (fl_i == 32'd16) begin
                        rf_base <= md[5:0];
                        nloc <= md[13:6];
                        spilled_reals <= md[29:14];
                        exc_base <= fl_base + 32'h44 + ({24'd0, md[13:6]} << 2);
                        stack_base <= fl_base + ((32'd17 + {24'd0, md[13:6]} + 32'd3 * {27'd0, nexc}) << 2);
                    end
                endcase
                if (fl_i == 32'd16) begin
                    fl_i <= 32'd0; fl_k <= 2'd0;
                    if (fl_img) st <= S_FL_L;
                    else begin sw_k <= 2'd0; gosub(S_XLOAD, S_FL_S); end
                end else begin
                    fl_i <= fl_i + 32'd1;
                    rd(fl_base + ((fl_i + 32'd1) << 2), S_FL_H);
                end
            end
            S_FL_L: if (fl_i == nloc) begin fl_i <= 32'd0; fl_k <= 2'd0; st <= S_FL_X0; end
                    else rd(fl_base + 32'h44 + (fl_i << 2), S_FL_L2);
            S_FL_L2: begin wr(fbase + 32'h44 + (fl_i << 2), mv, S_FL_L); fl_i <= fl_i + 32'd1; end
            // fl_img: copy every exception word into the reserve frame, then
            // load the top. A plain fill never reaches here.
            S_FL_X0: if (fl_i == 32'(xsp) * 32'd3) begin
                         fl_i <= 32'd0; fl_img <= 1'b0; sw_k <= 2'd0;
                         gosub(S_XLOAD, S_FL_S);
                     end else rd(exc_base + (fl_i << 2), S_FL_X);
            S_FL_X: begin
                wr(exc_words(fbase) + (fl_i << 2), mv, S_FL_X0);
                fl_i <= fl_i + 32'd1;
            end
            S_FL_S: if (fl_i == sp) ret();
                    else rd(stack_base + (fl_i << 2), S_FL_S2);
            S_FL_S2: begin
                rf[`SX(fl_i[6:0])] <= mv;
                fl_i <= fl_i + 32'd1;
                st <= S_FL_S;
            end

            S_RET: if (frk == ABI_RK_HALT) halt(ABI_HALT_CLEAN, 32'd0);
                   else begin r_rk <= frk; fl_base <= fprev; gosub(S_FILL, S_RET_D); end
            S_RET_D: begin d_rk <= r_rk; st <= S_DELIVER; end

            S_DELIVER: case (d_rk)
                ABI_RK_PUSH: begin push(t[7]); st <= S_FETCH; end
                ABI_RK_DISCARD: st <= S_FETCH;
                ABI_RK_PUSH_NULL: begin
                    rf[`SX(sp)] <= t[7]; rf[`SX(6'(sp + 7'd1))] <= VNULL; sp <= sp + 7'd2; st <= S_FETCH;
                end
                ABI_RK_CONT: st <= S_CONT;
                default: halt(ABI_HALT_CLEAN, 32'd0);
            endcase

            S_CONT: case (fcont)
                ABI_CONT_REDISPATCH: begin op <= aux[7:0]; st <= S_EXEC; end
                ABI_CONT_REPLACE: begin rf[`SX(aux[6:0])] <= t[7]; pc <= op_pc; st <= S_FETCH; end
                ABI_CONT_INIT: if (t[7] != VNONE) raise_err(ABI_ERR_INIT_NONE, t[7], VNULL);
                               else begin fcont <= aux3[7:0]; deliver(aux, aux2[3:0]); end
                ABI_CONT_WITH_ENTER: begin
                    x0 <= aux[31:0]; b0 <= 1'b1; x1 <= {16'd0, stk_depth}; sw_k <= 2'd0;
                    push(t[7]);
                    gosub(S_XPUSH, S_FETCH);
                end
                ABI_CONT_WITH_NONE: begin push(VNONE); st <= S_FETCH; end
                ABI_CONT_WITH_UNWIND: begin
                    rf[`SX(sp)] <= aux; rf[`SX(6'(sp + 7'd1))] <= aux2; sp <= sp + 7'd2; st <= S_FETCH;
                end
                ABI_CONT_WITH_EXC: begin tr_v <= t[7]; gosub(S_TR, S_WC_TR); end
                ABI_CONT_UNPACK: rd(adr(t[7]), S_UPK_N);
                ABI_CONT_RAISE: raise_val(t[7]);
                ABI_CONT_TRUTH: begin
                    ovr <= (t[7] == VTRUE) ? ABI_OVR_TRUE : ABI_OVR_FALSE;
                    pc <= op_pc; st <= S_FETCH;
                end
                // __exit__'s result was not decided in S_TR. None swallows.
                ABI_CONT_WITH_TRUTH: begin
                    push((t[7] == VTRUE) ? VNONE : aux);
                    st <= S_FETCH;
                end
                // Kind-3 __exit__ (aux2 == 0) still looks up __enter__.
                // Kind-3 __enter__ (aux2 != 0) is already bound; call it as kind 1.
                ABI_CONT_WITH_ATTR: begin
                    t[0] <= aux3;
                    jt <= aux[31:0];
                    if (aux2 == vint(32'd0)) begin
                        rf[`SX(6'(sp - 7'd1))] <= t[7];
                        rf[`SX(sp)] <= VNULL;
                        sp <= sp + 7'd1;
                        at_q <= ABI_Q_ENTER_D;
                        gosub_scr(SCR_AT, S_AT, S_SW_E);
                    end else begin
                        at_v <= t[7];
                        at_kind <= 2'd1;
                        st <= S_SW_E;
                    end
                end
                ABI_CONT_FOR_NEXT: if (t[7] == VSTOP) begin sp <= sp - 7'd4; pc <= aux[31:0]; st <= S_FETCH; end
                                   else begin push(t[7]); st <= S_FETCH; end
                ABI_CONT_GETITER: begin
                    rf[`SX(6'(sp - 7'd1))] <= t[7]; ovr <= ABI_OVR_PYOBJ; pc <= op_pc; st <= S_FETCH;
                end
                ABI_CONT_BIND: rd(adr(t[7]), S_CB_N);
                // Fast path: t[7] is the bare yielded value. The tuple arm stays
                // for a firmware _yfrom result (FF_YFAST clear).
                ABI_CONT_YFROM: if (fflags & FF_YFAST) begin
                                    fflags <= fflags & ~FF_YFAST;
                                    push(t[7]);
                                    pc <= op_pc;
                                    st <= S_YLD;
                                end else rd(adr(t[7]) + 4, S_YF_F);
                // A spilled star is not a resident register. REPLACE would
                // write rf[0] and leave the iterator in the chunk.
                ABI_CONT_SPILL_REPLACE: begin
                    if (!has_link) halt(ABI_HALT_INTERNAL, 32'h0000_C0C0);
                    else begin
                        srd_g <= aux[15:0];
                        srd_addr <= mpy_rf_link_addr(rf[`SX(7'd0)]);
                        srd_off <= spilled_reals - 16'd1 - aux[15:0];
                        srd_hops <= 8'd0;
                        st <= S_CVK_SW0;
                    end
                end
                default: halt(ABI_HALT_INTERNAL, {24'd0, fcont});
            endcase
            S_WC_TR: begin
                if (tr_x) begin
                    fcont <= ABI_CONT_WITH_TRUTH;
                    hook(ABI_HOOK_TRUTH, ABI_RK_CONT, 8'd1, tr_v, VNULL, VNULL, VNULL);
                end else begin
                    push(tr_r ? VNONE : aux);
                    st <= S_FETCH;
                end
            end
            S_UPK_N: begin x1 <= md; st <= S_UPK_L; end
            S_UPK_L: if (x1 == 32'd0) st <= S_FETCH;
                     else rd(adr(t[7]) + (x1 << 2), S_UPK_V);
            S_UPK_V: begin x1 <= x1 - 32'd1; push(mv); st <= S_UPK_L; end
            S_CB_N: begin x1 <= md; i0 <= 8'd0; st <= S_CB_L; end
            S_CB_L: if (i0 == x1[7:0]) rd(rc + 4 * ABI_RC_ARGS, S_CB_A);
                    else rd(adr(t[7]) + 4 + 4 * i0, S_CB_V);
            S_CB_V: begin wr(loc_ptr(i0), mv, S_CB_L); i0 <= i0 + 8'd1; end
            S_CB_A: begin c_ncell <= md[31:24]; rd(rc + 4 * ABI_RC_CELLS, S_CB_C); end
            S_CB_C: begin c_cells <= md; c_ci <= 32'd0; fcont <= 8'd0; st <= S_CELLS; end

            // ---------------- exceptions ----------------
            S_RMSG: alloc(32'd5, S_RMSG1);
            S_RMSG1: rd(h_msgs + 4 * rm_id, S_RMSG2);
            S_RMSG2: begin t[0] <= mv; rd(TT + 4 * msg_type(rm_id), S_RMSG3); end
            S_RMSG3: begin
                wb_v[0] <= vint(ABI_OB_EXCEPTION); wb_v[1] <= mv; wb_v[2] <= t[0];
                wb_v[3] <= VNULL; wb_v[4] <= VNULL;
                xc <= vobj(al_a);
                wblock(al_a, 4'd5, S_RMSG4);
            end
            S_RMSG4: begin rx_from <= 1'b0; rsp <= 5'd0; st <= S_RAISE; end

            S_RAISE: if ((rx_from && rx_crk == ABI_RK_CONT && fcont == ABI_CONT_FOR_NEXT) ||
                         (!rx_from && op == 8'h4b))
                         rd(adr(xc) + 4, S_RX_SI);
                     else if (rx_from && rx_crk == ABI_RK_CONT && fcont == ABI_CONT_YFROM)
                         rd(adr(xc) + 4, S_YF_SI);
                     else st <= S_RX_TB;
            S_RX_SI: begin is_t <= mv; is_c <= ty_stop; gosub(S_ISSUB, S_RX_SI2); end
            S_RX_SI2: if (is_r) begin sp <= sp - 7'd4; pc <= aux[31:0]; st <= S_FETCH; end
                      else st <= S_RX_TB;
            S_RX_TB: if ((fflags & (FF_NOTB | FF_FW)) ||
                         (!rx_from && (op == 8'h5d || op == 8'h64)))
                         st <= S_RX_H;
                     else rd(rc + 4 * ABI_RC_OP_START, S_RX_TB1);
            S_RX_TB1: begin rx_off <= op_pc - md; rd(adr(xc) + 12, S_RX_TB2); end
            S_RX_TB2: if (mv == VNULL) begin al_soft <= 1'b1; alloc(32'd7, S_RX_TBN); end
                      else begin t[2] <= mv; st <= S_RX_TBA; end
            S_RX_TBN: if (!al_ok) begin al_soft <= 1'b0; st <= S_RX_H; end
                      else begin
                          wb_v[0] <= vint(32'd0); wb_v[1] <= vint(32'd4); wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
                          t[2] <= vmut(al_a, ABI_MUT_LIST);
                          wblock(al_a, 4'd3, S_RX_TBL);
                      end
            S_RX_TBL: wr(adr(xc) + 12, t[2], S_RX_TBA);
            S_RX_TBA: begin t[3] <= vint(rc); al_soft <= 1'b1; gosub_scr(SCR_LA, S_LA, S_RX_TBB); end
            S_RX_TBB: begin t[3] <= vint(rx_off); gosub_scr(SCR_LA, S_LA, S_RX_TBC); end
            S_RX_TBC: begin al_soft <= 1'b0; st <= S_RX_H; end
            // One pop per visit. S_XPOP loads the new top before the next test.
            S_RX_H: if (xsp != 5'd0 && xh <= op_pc) begin
                        sw_k <= 2'd0; gosub(S_XPOP, S_RX_H);
                    end else if (xsp != 5'd0) begin
                        pc <= xh;
                        xp <= xc;
                        drop_left <= (stk_depth > xv) ? (stk_depth - xv) : 16'd0;
                        drop_push_en <= 1'b1;
                        drop_push_v <= xc;
                        drop_then <= S_FETCH;
                        st <= S_DROP;
                    end else if (gen != VNULL && fprev != 32'd0) begin
                        pc <= 32'd0;
                        st <= S_GN_ESC;
                    end else if (fprev == 32'd0) begin
                        halt(ABI_HALT_UNCAUGHT, xc[31:0]);
                    end else begin
                        rx_crk <= frk; fl_base <= fprev; gosub(S_FILL, S_RX_POP);
                    end
            S_RX_POP: begin rx_from <= 1'b1; st <= S_RAISE; end

            // ---------------- fetch / decode ----------------
            S_FETCH: if (ca_fault_i) begin
                         case (ca_fault_reason_i)
                             MPY_FAULT_UNALIGNED: halt(ABI_HALT_UNALIGNED, ca_fault_addr_i);
                             MPY_FAULT_FLASH_STORE: halt(ABI_HALT_FLASH_STORE, ca_fault_addr_i);
                             default: halt(ABI_HALT_BUS, ca_fault_addr_i);
                         endcase
                     end else if (sp >= 7'(RF_SPILL_AT)) begin
                         rf_resume <= S_FETCH; st <= S_RF_SPILL;
                     end else if (has_link && sp <= 7'(RF_RELOAD_AT)) begin
                         rf_resume <= S_FETCH; st <= S_RF_RELOAD;
                     end else if (in_win) st <= S_DEC;
                     else begin
                         fw_base <= {pc[31:2], 2'b00}; fw_i <= 2'd0; fw_ok <= 1'b0;
                         rd({pc[31:2], 2'b00}, S_FW);
                     end
            S_FW: begin
                fwin[32 * fw_i +: 32] <= md;
                if (fw_i == 2'd2) begin fw_ok <= 1'b1; st <= S_DEC; end
                else begin fw_i <= fw_i + 2'd1; rd(fw_base + 4 * (fw_i + 2'd1), S_FW); end
            end
            S_DEC: if (d_trunc) begin
                       if (fw_base == {pc[31:2], 2'b00}) halt(ABI_HALT_BAD_OPCODE, pc);
                       else begin fw_ok <= 1'b0; st <= S_FETCH; end
                   end else if (d_illegal || !d_valid) halt(ABI_HALT_BAD_OPCODE, pc);
                   else begin
                       op <= d_op; arg <= d_arg; ext <= d_ext;
                       op_pc <= pc; pc <= pc + d_len;
                       jt <= pc + d_len - (d_extv ? 32'd1 : 32'd0) + d_arg;
                       nops <= nops + 32'd1; trace <= 1'b1;
                       st <= S_EXEC;
                   end

            // ---------------- execute ----------------
            S_EXEC: begin
                if ((op >= 8'hb0 && op < 8'hc0) || op == 8'h24) begin
                    vi = (op == 8'h24) ? arg[7:0] : (op - 8'hb0);
                    if (lc_is_hit(vi)) begin
                        vs0 = {4'd0, lc_hit_way(vi)};
                        if (lc_d[vs0[2:0]] == VNULL && !(fflags & FF_FW)) raise_msg(ABI_MSG_LOCAL_UNBOUND);
                        else begin push(lc_d[vs0[2:0]]); lc_note(vs0[2:0]); st <= S_FETCH; end
                    end else begin
                        i0 <= vi; rd(loc_ptr(vi), S_LDF);
                    end
                end else if ((op >= 8'hc0 && op < 8'hd0) || op == 8'h26) begin
                    vi = (op == 8'h26) ? arg[7:0] : (op - 8'hc0);
                    if (cfg_lc_n != 4'd0 && cfg_lc_wb) begin
                        sp <= sp - 7'd1;
                        lc_fill(vi, rf[`SX(6'(sp - 7'd1))], 1'b1, 1'b1, S_FETCH);
                    end else begin
                        wr(loc_ptr(vi), rf[`SX(6'(sp - 7'd1))], S_FETCH);
                        sp <= sp - 7'd1;
                        if (cfg_lc_n != 4'd0) lc_fill(vi, rf[`SX(6'(sp - 7'd1))], 1'b0, 1'b0, S_FETCH);
                    end
                end else if (op == 8'h25 || op == 8'h27 || op == 8'h29 || op == 8'h28) begin
                    vi = arg[7:0];
                    if (lc_is_hit(vi)) begin
                        vs0 = {4'd0, lc_hit_way(vi)};
                        lc_note(vs0[2:0]);
                        if (lc_d[vs0[2:0]] == VNULL && (op == 8'h28 || !(fflags & FF_FW)))
                            raise_msg(ABI_MSG_LOCAL_UNBOUND);
                        else if (op == 8'h25) rd(adr(lc_d[vs0[2:0]]) + 8, S_DEREF);
                        else if (op == 8'h27) begin
                            wr(adr(lc_d[vs0[2:0]]) + 8, rf[`SX(6'(sp - 7'd1))], S_FETCH);
                            sp <= sp - 7'd1;
                        end else if (op == 8'h29) rd(adr(lc_d[vs0[2:0]]) + 8, S_DELDEREF);
                        else begin
                            wr(loc_ptr(vi), VNULL, S_FETCH);
                            lc_v[vs0[2:0]] <= 1'b0;
                            lc_dirty[vs0[2:0]] <= 1'b0;
                        end
                    end else begin
                        i0 <= vi;
                        if (op == 8'h25) rd(loc_ptr(vi), S_LDREF);
                        else if (op == 8'h27) rd(loc_ptr(vi), S_STREF);
                        else if (op == 8'h29) rd(loc_ptr(vi), S_DDREF);
                        else rd(loc_ptr(vi), S_LDEL);
                    end
                end else if (op >= 8'h70 && op < 8'hb0) begin push(vint(32'(op) - 32'h80)); st <= S_FETCH; end
                else if (op >= 8'hd0 && op < 8'hd7) begin
                    n_o <= op - 8'hd0; st <= S_UN;
                end else if (op >= 8'hd7 && op < 8'hfa) begin
                    n_o <= op - 8'hd7; st <= S_BIN;
                end else case (op)
                8'h10: rd(qbase + 4 * arg, S_LCS);
                8'h22: begin push(vint(arg)); st <= S_FETCH; end
                8'h23: rd(cbase + 4 * arg, S_LCO);
                8'h50: begin push(VFALSE); st <= S_FETCH; end
                8'h51: begin push(VNONE); st <= S_FETCH; end
                8'h52: begin push(VTRUE); st <= S_FETCH; end
                8'h53: begin push(VNULL); st <= S_FETCH; end
                8'h24, 8'h25, 8'h26, 8'h27, 8'h28, 8'h29: halt(ABI_HALT_INTERNAL, 32'h0000_10CA);
                8'h11, 8'h12, 8'h16, 8'h17, 8'h19, 8'h1a, 8'h13, 8'h14, 8'h18, 8'h15,
                8'h1b, 8'h1c:
                    rd(qbase + 4 * arg, S_QOP);
                8'h54: rd(h_hooks + 4 * ABI_HOOK_BUILD_CLASS, S_LCO);
                8'h55: begin t[0] <= rf[`SX(6'(sp - 7'd2))]; t[1] <= rf[`SX(6'(sp - 7'd1))]; st <= S_LSUB; end
                8'h56: begin
                    t[0] <= rf[`SX(6'(sp - 7'd2))]; t[1] <= rf[`SX(6'(sp - 7'd1))]; t[6] <= rf[`SX(6'(sp - 7'd3))];
                    st <= S_SSUB;
                end
                8'h57: begin push(rf[`SX(6'(sp - 7'd1))]); st <= S_FETCH; end
                8'h58: begin
                    rf[`SX(sp)] <= rf[`SX(6'(sp - 7'd2))]; rf[`SX(6'(sp + 7'd1))] <= rf[`SX(6'(sp - 7'd1))];
                    sp <= sp + 7'd2; st <= S_FETCH;
                end
                8'h59: begin sp <= sp - 7'd1; st <= S_FETCH; end
                8'h5a: begin
                    rf[`SX(6'(sp - 7'd1))] <= rf[`SX(6'(sp - 7'd2))]; rf[`SX(6'(sp - 7'd2))] <= rf[`SX(6'(sp - 7'd1))];
                    st <= S_FETCH;
                end
                8'h5b: begin
                    rf[`SX(6'(sp - 7'd3))] <= rf[`SX(6'(sp - 7'd1))];
                    rf[`SX(6'(sp - 7'd2))] <= rf[`SX(6'(sp - 7'd3))];
                    rf[`SX(6'(sp - 7'd1))] <= rf[`SX(6'(sp - 7'd2))];
                    st <= S_FETCH;
                end
                8'h42: begin pc <= jt; st <= S_FETCH; end
                8'h43, 8'h44, 8'h45, 8'h46: begin tr_v <= rf[`SX(6'(sp - 7'd1))]; gosub(S_TR, S_JT); end
                8'h47: begin t[0] <= rf[`SX(6'(sp - 7'd1))]; at_q <= ABI_Q_EXIT_D; gosub_scr(SCR_AT, S_AT, S_SW_X); end
                8'h48, 8'h49: begin
                    if (xsp >= nexc) halt(ABI_HALT_INTERNAL, op_pc);
                    else begin
                        x0 <= jt; b0 <= (op == 8'h49); x1 <= {16'd0, stk_depth}; sw_k <= 2'd0;
                        gosub(S_XPUSH, S_FETCH);
                    end
                end
                8'h4a: begin pc <= jt; sw_k <= 2'd0; gosub(S_XPOP, S_FETCH); end
                8'h40: begin
                    rf[`SX(sp)] <= vint(jt); rf[`SX(6'(sp + 7'd1))] <= vint({24'd0, ext});
                    sp <= sp + 7'd2; st <= S_UJ;
                end
                8'h5c: st <= S_WC;
                8'h5d: begin sw_k <= 2'd0; gosub(S_XPOP, S_XEF); end
                8'h63: st <= S_UR;
                // Highest non-null xp wins. The top register is that entry
                // when it is live; older slots are word 2, from xsp-2 down.
                8'h64: begin
                    if (xsp != 5'd0 && xp != VNULL) begin
                        xc <= xp; rx_from <= 1'b0; rsp <= 5'd0; st <= S_RAISE;
                    end else if (xsp < 5'd2) raise_msg(ABI_MSG_NO_ACTIVE_EXC);
                    else begin sw_i <= 32'(xsp - 5'd2); sw_k <= 2'd0; st <= S_XS; end
                end
                8'h65: begin t[0] <= rf[`SX(6'(sp - 7'd1))]; sp <= sp - 7'd1; st <= S_ROBJ; end
                8'h66: if (rf[`SX(6'(sp - 7'd1))] != VNONE) begin
                           sp <= sp - 7'd1; aux <= vint(32'h65); fcont <= ABI_CONT_REDISPATCH;
                           hook(ABI_HOOK_WARN, ABI_RK_CONT, 8'd1, vint(32'd0), VNULL, VNULL, VNULL);
                       end else begin op <= 8'h65; sp <= sp - 7'd1; end
                8'h5e: begin sp <= sp - 7'd1; hook(ABI_HOOK_GETITER, ABI_RK_PUSH, 8'd1, rf[`SX(6'(sp - 7'd1))], VNULL, VNULL, VNULL); end
                8'h5f: begin t[0] <= rf[`SX(6'(sp - 7'd1))]; b1 <= (ovr == ABI_OVR_PYOBJ); ovr <= ABI_OVR_NONE; st <= S_GI; end
                8'h4b: st <= S_FI_PRE;
                8'h2a: begin
                    tb_src <= 1'b1; tb_nz <= 1'b0; tb_from <= 8'(sp - 7'(arg));
                    stk_from <= stk_depth - 16'(arg); tb_n <= arg[7:0];
                    gosub(S_TUP, S_BT_R);
                end
                8'h2b: alloc(32'd3 + ((arg < 32'd4) ? 32'd4 : arg), S_BL_A);
                8'h2c: alloc(32'd4 + 2 * arg, S_BM_A);
                8'h2d: begin
                    tb_src <= 1'b1; tb_nz <= 1'b0; tb_from <= 8'(sp - 7'(arg));
                    stk_from <= stk_depth - 16'(arg); tb_n <= arg[7:0];
                    gosub(S_TUP, S_BSET_R);
                end
                8'h2e: alloc(32'd5, S_SLICE_A);
                8'h2f: begin
                    vs0 = 7'(sp - 7'd1 - 7'(arg >> 2));
                    case (arg[1:0])
                        2'd0: begin t[2] <= rf[`SX(vs0)]; t[3] <= rf[`SX(6'(sp - 7'd1))]; gosub_scr(SCR_LA, S_LA, S_SC_L); end
                        2'd1: lookup(rf[`SX(vs0)], rf[`SX(6'(sp - 7'd1))], rf[`SX(6'(sp - 7'd2))], LK_ADD, 1'b0, S_SC_D);
                        default: lookup(rf[`SX(vs0)], rf[`SX(6'(sp - 7'd1))], VNULL, LK_ADD, 1'b1, S_SC_S);
                    endcase
                end
                8'h62: lookup(rf[`SX(6'(sp - 7'd3))], rf[`SX(6'(sp - 7'd1))], rf[`SX(6'(sp - 7'd2))], LK_ADD, 1'b0, S_STM_R);
                8'h30: begin
                    t[0] <= rf[`SX(6'(sp - 7'd1))];
                    if (tg(rf[`SX(6'(sp - 7'd1))]) == ABI_TAG_TUPLE || is_mut(rf[`SX(6'(sp - 7'd1))], ABI_MUT_LIST))
                        rd(adr(rf[`SX(6'(sp - 7'd1))]), S_UPS_N);
                    else begin
                        sp <= sp - 7'd1; fcont <= ABI_CONT_UNPACK;
                        hook(ABI_HOOK_UNPACK, ABI_RK_CONT, 8'd3, rf[`SX(6'(sp - 7'd1))], vint(arg), vint(32'd0), VNULL);
                    end
                end
                8'h31: begin
                    sp <= sp - 7'd1; fcont <= ABI_CONT_UNPACK;
                    hook(ABI_HOOK_UNPACK, ABI_RK_CONT, 8'd3, rf[`SX(6'(sp - 7'd1))], vint(arg), vint(32'd1), VNULL);
                end
                8'h32, 8'h33, 8'h20, 8'h21: rd(rc + 4 * ABI_RC_CHILDREN, S_MF_C);
                8'h34, 8'h36: begin
                    ab_chunked <= 1'b0;
                    v0 = {24'd0, arg[7:0]};
                    v1 = {24'd0, arg[15:8]};
                    // need = positional words + keyword pairs + callable (+ self)
                    v2 = v0 + (v1 << 1) + ((op == 8'h36) ? 32'd2 : 32'd1);
                    if (v2 <= 32'(resident_reals)) begin
                        rf_reload_miss <= 1'b0;
                        vs0 = 7'(sp - 7'(v0) - 7'(2 * v1));      // first argument
                        vs1 = 7'(vs0 - ((op == 8'h36) ? 7'd2 : 7'd1));  // callable
                        s0 <= vs0; s1 <= vs1;
                        x1 <= v0 + (v1 << 1);
                        i0 <= 8'd0;
                        if (op == 8'h36 && rf[`SX(6'(vs1 + 7'd1))] != VNULL) begin
                            b1 <= 1'b1; ab_lo <= 8'd31;
                        end else begin
                            b1 <= 1'b0; ab_lo <= 8'd32;
                        end
                        ab_pe <= 8'd32 + v0[7:0]; ab_nkw <= v1[7:0];
                        sp <= vs1; crk <= ABI_RK_PUSH;
                        wr(ab_ptr(8'd0), rf[`SX(vs1)], S_CALL_CP);
                    end else if (has_link && !rf_reload_miss && (v2 <= 32'(MPY_RF_DEPTH))) begin
                        // The window fits in the ring. Pull chunks back and retry.
                        // A chunk that does not fit sets rf_reload_miss and comes back here.
                        rf_resume <= S_EXEC;
                        st <= S_RF_RELOAD;
                    end else if (v0 + (v1 << 1) > 32'd224) begin
                        raise_err(ABI_ERR_STAR_ARGS, VNULL, VNULL);
                    end else begin
                        rf_reload_miss <= 1'b0;
                        // Wider than the ring: copy one stack value at a time.
                        b0 <= (op == 8'h36);
                        x4 <= v0;
                        x1 <= v0 + (v1 << 1);
                        ab_nkw <= v1[7:0];
                        x0 <= 32'(stk_depth) - v2;
                        x2 <= 32'(stk_depth) - v2 + ((op == 8'h36) ? 32'd2 : 32'd1);
                        x3 <= v2;
                        gi <= 32'd0;
                        st <= S_CC_FUN;
                    end
                end
                8'h35, 8'h37: begin
                    v0 = {24'd0, arg[7:0]};
                    v1 = {24'd0, arg[15:8]};
                    // fun + positionals + keyword words + bitmap (+ self)
                    v2 = v0 + (v1 << 1) + 32'd2 + ((op == 8'h37) ? 32'd1 : 32'd0);
                    ab_chunked <= 1'b0;
                    cv_wide <= v2 > 32'(resident_reals);
                    cv_pos_g <= stk_depth - 16'd1 - v0[15:0] - {v1[14:0], 1'b0};
                    cv_fun_g <= stk_depth - 16'd1 - v0[15:0] - {v1[14:0], 1'b0}
                                - ((op == 8'h37) ? 16'd2 : 16'd1);
                    cv_base <= 7'(sp - 7'd1 - 7'(v0) - 7'(2 * v1));
                    cv_fidx <= 7'(sp - 7'd1 - 7'(v0) - 7'(2 * v1) - ((op == 8'h37) ? 7'd2 : 7'd1));
                    cv_bm <= rf[`SX(6'(sp - 7'd1))][31:0];
                    cv_n <= v0[7:0]; cv_j <= v1[7:0]; cv_i <= 8'd0;
                    st <= S_CVK_P;
                end
                8'h67: if (gen == VNULL) raise_err(ABI_ERR_GENERATOR, VNULL, VNULL);
                       else st <= S_YLD;
                8'h68: begin
                    // Drop a stale fast bit before the kind check so a resume
                    // that takes the hook cannot later treat a tuple as a value.
                    // Pop the send value only on the path that runs. The
                    // sub-iterator stays. inj is a throw this resume deferred;
                    // VNONE means use the popped send.
                    fflags <= fflags & ~FF_YFAST;
                    if (inj == VNONE && rf[`SX(6'(sp - 7'd1))] == VNONE &&
                        tg(rf[`SX(6'(sp - 7'd2))]) == ABI_TAG_OBJECT)
                        rd(adr(rf[`SX(6'(sp - 7'd2))]), S_YF_K);
                    else begin
                        aux <= inj;
                        fcont <= ABI_CONT_YFROM;
                        hook(ABI_HOOK_YFROM, ABI_RK_CONT, 8'd3, rf[`SX(6'(sp - 7'd2))],
                             (inj != VNONE) ? VNONE : rf[`SX(6'(sp - 7'd1))],
                             (inj != VNONE) ? inj : VNONE, VNULL);
                        inj <= VNONE;
                        sp <= sp - 7'd1;
                    end
                end
                8'h69: begin
                    sp <= sp - 7'd1;
                    hook(ABI_HOOK_IMPORT_STAR, ABI_RK_DISCARD, 8'd2, rf[`SX(6'(sp - 7'd1))],
                         (loc == VNULL) ? glb : loc, VNULL, VNULL);
                end
                default: halt(ABI_HALT_BAD_OPCODE, op_pc);
                endcase
            end

            S_LCS: begin push({ABI_TAG_QSTR, md}); st <= S_FETCH; end
            S_LCO: begin push(mv); st <= S_FETCH; end
            S_LDF: if (mv == VNULL && !(fflags & FF_FW)) raise_msg(ABI_MSG_LOCAL_UNBOUND);
                   else begin push(mv); lc_fill(i0, mv, 1'b0, 1'b1, S_FETCH); end
            S_LC_EV: begin
                lc_v[lc_ev_way] <= 1'b1;
                lc_ix[lc_ev_way] <= lc_ev_idx;
                lc_d[lc_ev_way] <= lc_ev_val;
                lc_dirty[lc_ev_way] <= lc_ev_dirty;
                lc_note(lc_ev_way);
                st <= S_FETCH;
            end
            S_LC_FL: if (lc_fi >= cfg_lc_n) begin
                    lc_fi <= 4'd0; st <= lc_fl_ret;
                end else if (lc_v[lc_fi[2:0]] && lc_dirty[lc_fi[2:0]]) begin
                    lc_dirty[lc_fi[2:0]] <= 1'b0;
                    wr(loc_ptr(lc_ix[lc_fi[2:0]]), lc_d[lc_fi[2:0]], S_LC_FL);
                    lc_fi <= lc_fi + 4'd1;
                end else lc_fi <= lc_fi + 4'd1;
            S_LDEL: if (mv == VNULL) raise_msg(ABI_MSG_LOCAL_UNBOUND);
                    else wr(loc_ptr(i0), VNULL, S_FETCH);
            S_LDREF: if (mv == VNULL && !(fflags & FF_FW)) raise_msg(ABI_MSG_LOCAL_UNBOUND);
                     else begin
                         rd(adr(mv) + 8, S_DEREF);
                         if (cfg_lc_n != 4'd0) begin
                             vs0 = {4'd0, lc_pick(i0)};
                             if (!lc_v[vs0[2:0]] || !lc_dirty[vs0[2:0]])
                                 lc_fill(i0, mv, 1'b0, 1'b0, S_DEREF);
                         end
                     end
            S_STREF: if (mv == VNULL) raise_msg(ABI_MSG_LOCAL_UNBOUND);
                     else begin wr(adr(mv) + 8, rf[`SX(6'(sp - 7'd1))], S_FETCH); sp <= sp - 7'd1; end
            S_DDREF: if (mv == VNULL) raise_msg(ABI_MSG_LOCAL_UNBOUND);
                     else rd(adr(mv) + 8, S_DELDEREF);
            S_DEREF: if (mv == VNULL) raise_msg(ABI_MSG_LOCAL_UNBOUND);
                     else begin push(mv); st <= S_FETCH; end
            S_DELDEREF: if (mv == VNULL) raise_msg(ABI_MSG_LOCAL_UNBOUND);
                        else wr(m_addr, VNULL, S_FETCH);

            // ---- qstr-operand opcodes ----
            S_QOP: begin
                at_q <= md;
                case (op)
                    8'h11, 8'h12: begin
                        b0 <= (op == 8'h11 && loc != VNULL) ? 1'b0 : 1'b1;
                        i2 <= (op == 8'h11 && loc != VNULL) ? 8'd0 : 8'd1;
                        st <= S_LN_L;
                    end
                    8'h16, 8'h17:
                        lookup((op == 8'h16 && loc != VNULL) ? loc : glb, {ABI_TAG_QSTR, md},
                               rf[`SX(6'(sp - 7'd1))], LK_ADD, 1'b0, S_SN_R);
                    8'h19, 8'h1a:
                        lookup((op == 8'h19 && loc != VNULL) ? loc : glb, {ABI_TAG_QSTR, md},
                               VNULL, LK_REMOVE, 1'b0, S_DN_R);
                    8'h13, 8'h14: begin t[0] <= rf[`SX(6'(sp - 7'd1))]; gosub_scr(SCR_AT, S_AT, S_LA_R); end
                    8'h18: begin t[0] <= rf[`SX(6'(sp - 7'd1))]; t[6] <= rf[`SX(6'(sp - 7'd2))]; st <= S_SA; end
                    8'h15: begin
                        sp <= sp - 7'd3;
                        hook(ABI_HOOK_SUPER_METHOD, ABI_RK_PUSH_NULL, 8'd3, rf[`SX(6'(sp - 7'd2))], rf[`SX(6'(sp - 7'd1))],
                             {ABI_TAG_QSTR, md}, VNULL);
                    end
                    8'h1b: begin
                        sp <= sp - 7'd2;
                        hook(ABI_HOOK_IMPORT, ABI_RK_PUSH, 8'd4, {ABI_TAG_QSTR, md}, rf[`SX(6'(sp - 7'd1))],
                             rf[`SX(6'(sp - 7'd2))], glb);
                    end
                    8'h1c: hook(ABI_HOOK_IMPORT_FROM, ABI_RK_PUSH, 8'd2, rf[`SX(6'(sp - 7'd1))], {ABI_TAG_QSTR, md},
                                VNULL, VNULL);
                    default: halt(ABI_HALT_BAD_OPCODE, op_pc);
                endcase
            end
            S_LN_L: if (i2 == 8'd2 && bov != VNULL)
                        lookup(bov, {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, S_LN_R);
                    else lookup((i2 == 8'd0) ? loc : (i2 == 8'd1) ? glb : vmut(h_builtins, ABI_MUT_DICT),
                                {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, S_LN_R);
            S_LN_R: if (lk_found) begin push(lk_res); st <= S_FETCH; end
                    else if (i2 == 8'd2 && bov != VNULL) begin
                        i2 <= 8'd3;
                        lookup(vmut(h_builtins, ABI_MUT_DICT), {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, S_LN_R);
                    end else if (i2 >= 8'd2) raise_err(ABI_ERR_NAME, {ABI_TAG_QSTR, at_q}, VNULL);
                    else begin i2 <= i2 + 8'd1; st <= S_LN_L; end
            S_SN_R: if (lk_ro || lk_cx) raise_err(ABI_ERR_INTERNAL, t[4], VNULL);
                    else begin sp <= sp - 7'd1; st <= S_FETCH; end
            S_DN_R: if (!lk_found) raise_err(ABI_ERR_NAME, {ABI_TAG_QSTR, at_q}, VNULL);
                    else st <= S_FETCH;

            // ---- LOAD_ATTR / LOAD_METHOD ----
            S_LA_R: case (at_kind)
                2'd1: begin
                    rf[`SX(6'(sp - 7'd1))] <= at_v;
                    if (op == 8'h14) push(VNULL);
                    st <= S_FETCH;
                end
                2'd2: if (op == 8'h14) begin
                        rf[`SX(6'(sp - 7'd1))] <= at_v; push(t[0]); st <= S_FETCH;
                    end else begin t[1] <= at_v; alloc(32'd4, S_LA_BM); end
                default: begin
                    sp <= sp - 7'd1;
                    hook(ABI_HOOK_GETATTR, (op == 8'h14) ? ABI_RK_PUSH_NULL : ABI_RK_PUSH, 8'd2,
                         t[0], {ABI_TAG_QSTR, at_q}, VNULL, VNULL);
                end
            endcase
            S_LA_BM: begin
                wb_v[0] <= vint(ABI_OB_BOUND_METHOD); wb_v[1] <= ty_bm; wb_v[2] <= t[1]; wb_v[3] <= t[0];
                rf[`SX(6'(sp - 7'd1))] <= vobj(al_a);
                wblock(al_a, 4'd4, S_FETCH);
            end

            // ---- STORE_ATTR ----
            S_SA: if (tg(t[0]) == ABI_TAG_OBJECT) rd(adr(t[0]), S_SA_K);
                  else st <= S_SA_FB;
            S_SA_K: begin
                if (scr_id == SCR_NONE || scr_id == SCR_AT) begin
                    scr_id <= SCR_AT;
                    `at_k <= md;
                    if (md == ABI_OB_INSTANCE || md == ABI_OB_EXCEPTION) rd(adr(t[0]) + 4, S_SA_TY);
                    else if (md == ABI_OB_TYPE || md == ABI_OB_MODULE) rd(adr(t[0]) + 8, S_SA_D);
                    else st <= S_SA_FB;
                end else wr(scr_addr(SCR_AT, 4'd3), {4'd0, md}, S_SA_K2);
            end
            S_SA_K2: if (scr_id != SCR_AT) scr_ensure(SCR_AT, S_SA_K2);
                     else if (`at_k == ABI_OB_INSTANCE || `at_k == ABI_OB_EXCEPTION) rd(adr(t[0]) + 4, S_SA_TY);
                     else if (`at_k == ABI_OB_TYPE || `at_k == ABI_OB_MODULE) rd(adr(t[0]) + 8, S_SA_D);
                     else st <= S_SA_FB;
            S_SA_TY: rd(adr(mv) + 28, S_SA_TF);
            S_SA_TF: if (md & (ABI_TF_SETATTR | ABI_TF_DESC)) st <= S_SA_FB;
                     else rd(adr(t[0]) + ((`at_k == ABI_OB_EXCEPTION) ? 16 : 8), S_SA_D);
            S_SA_D: if (mv == VNULL) begin
                        if (t[6] == VNULL || !(`at_k == ABI_OB_INSTANCE || `at_k == ABI_OB_EXCEPTION)) st <= S_SA_FB;
                        else alloc(32'd4, S_SA_ND);
                    end else lookup(mv, {ABI_TAG_QSTR, at_q}, t[6], (t[6] == VNULL) ? LK_REMOVE : LK_ADD, 1'b0, S_SA_R);
            S_SA_ND: begin
                wb_v[0] <= vint(32'd0); wb_v[1] <= vint(32'd0); wb_v[2] <= VNULL; wb_v[3] <= vint(32'd0);
                t[4] <= vmut(al_a, ABI_MUT_DICT);
                wblock(al_a, 4'd4, S_SA_NL);
            end
            S_SA_NL: wr(adr(t[0]) + ((`at_k == ABI_OB_EXCEPTION) ? 16 : 8), t[4], S_SA_NL2);
            S_SA_NL2: lookup(t[4], {ABI_TAG_QSTR, at_q}, t[6], LK_ADD, 1'b0, S_SA_R);
            S_SA_R: if (lk_ro || lk_cx || (lk_mode == LK_REMOVE && !lk_found)) st <= S_SA_FB;
                    else begin sp <= sp - 7'd2; st <= S_FETCH; end
            S_SA_FB: begin
                sp <= sp - 7'd2;
                hook(ABI_HOOK_SETATTR, ABI_RK_DISCARD, 8'd3, t[0], {ABI_TAG_QSTR, at_q}, t[6], VNULL);
            end

            // ---- LOAD_SUBSCR ----
            S_LSUB: if ((is_mut(t[0], ABI_MUT_LIST) || tg(t[0]) == ABI_TAG_TUPLE) && intlike(t[1]))
                        rd(adr(t[0]), S_LS_LEN);
                    else if (is_mut(t[0], ABI_MUT_DICT))
                        lookup(t[0], t[1], VNULL, LK_FIND, 1'b0, S_LS_D);
                    else if ((strlike(t[0]) || tg(t[0]) == ABI_TAG_BYTES) && intlike(t[1])) begin
                        si_v <= t[0]; gosub(S_SINFO, S_LS_S);
                    end else st <= S_LS_FB;
            S_LS_LEN: begin
                v0 = ival(t[1]);
                if (v0[31]) v0 = v0 + md;
                x1 <= v0;
                if (v0[31] || v0 >= md)
                    raise_msg((tg(t[0]) == ABI_TAG_TUPLE) ? ABI_MSG_TUPLE_INDEX : ABI_MSG_LIST_INDEX);
                else if (tg(t[0]) == ABI_TAG_TUPLE) rd(adr(t[0]) + 4 + (v0 << 2), S_LS_PUT);
                else rd(adr(t[0]) + 8, S_LS_IT);
            end
            S_LS_IT: rd(md + (x1 << 2), S_LS_PUT);
            S_LS_PUT: begin rf[`SX(6'(sp - 7'd2))] <= mv; sp <= sp - 7'd1; st <= S_FETCH; end
            S_LS_D: if (lk_cx) st <= S_LS_FB;
                    else if (lk_found) begin rf[`SX(6'(sp - 7'd2))] <= lk_res; sp <= sp - 7'd1; st <= S_FETCH; end
                    else raise_err(ABI_ERR_KEY, t[1], VNULL);
            S_LS_S: begin
                v0 = ival(t[1]);
                if (v0[31]) v0 = v0 + si_len;
                x1 <= v0;
                if (si_na) st <= S_LS_FB;
                else if (v0[31] || v0 >= si_len)
                    raise_msg((tg(t[0]) == ABI_TAG_BYTES) ? ABI_MSG_BYTES_INDEX : ABI_MSG_STR_INDEX);
                else rd(si_addr + {v0[31:2], 2'b00}, S_LS_SB);
            end
            S_LS_SB: if (tg(t[0]) == ABI_TAG_BYTES) begin
                         rf[`SX(6'(sp - 7'd2))] <= vint({24'd0, byte_of(md, x1[1:0])}); sp <= sp - 7'd1; st <= S_FETCH;
                     end else rd(h_chars + 4 * byte_of(md, x1[1:0]), S_LS_SC);
            S_LS_SC: begin rf[`SX(6'(sp - 7'd2))] <= {ABI_TAG_QSTR, md}; sp <= sp - 7'd1; st <= S_FETCH; end
            S_LS_FB: begin
                sp <= sp - 7'd2;
                hook(ABI_HOOK_SUBSCR, ABI_RK_PUSH, 8'd2, t[0], t[1], VNULL, VNULL);
            end

            // ---- STORE_SUBSCR ----
            S_SSUB: if (t[6] == VNULL) st <= S_SS_FB;
                    else if (is_mut(t[0], ABI_MUT_LIST) && intlike(t[1])) rd(adr(t[0]), S_SS_LEN);
                    else if (is_mut(t[0], ABI_MUT_DICT)) lookup(t[0], t[1], t[6], LK_ADD, 1'b0, S_SS_D);
                    else st <= S_SS_FB;
            S_SS_LEN: begin
                v0 = ival(t[1]);
                if (v0[31]) v0 = v0 + md;
                x1 <= v0;
                if (v0[31] || v0 >= md) raise_msg(ABI_MSG_LIST_INDEX);
                else rd(adr(t[0]) + 8, S_SS_IT);
            end
            S_SS_IT: begin wr(md + (x1 << 2), t[6], S_FETCH); sp <= sp - 7'd3; end
            S_SS_D: if (lk_cx || lk_ro) st <= S_SS_FB;
                    else begin sp <= sp - 7'd3; st <= S_FETCH; end
            S_SS_FB: begin
                sp <= sp - 7'd3;
                hook(ABI_HOOK_SETSUBSCR, ABI_RK_DISCARD, 8'd3, t[0], t[1], t[6], VNULL);
            end

            // ---- conditional jumps ----
            S_JT: if (tr_x) begin
                    fcont <= ABI_CONT_TRUTH; pc <= op_pc;
                    hook(ABI_HOOK_TRUTH, ABI_RK_CONT, 8'd1, rf[`SX(6'(sp - 7'd1))], VNULL, VNULL, VNULL);
                end else begin
                    case (op)
                        8'h43: begin sp <= sp - 7'd1; if (tr_r) pc <= jt; end
                        8'h44: begin sp <= sp - 7'd1; if (!tr_r) pc <= jt; end
                        8'h45: if (tr_r) pc <= jt; else sp <= sp - 7'd1;
                        8'h46: if (!tr_r) pc <= jt; else sp <= sp - 7'd1;
                        default: rf[`SX(6'(sp - 7'd1))] <= vbool(!tr_r);   // UNARY_OP NOT
                    endcase
                    st <= S_FETCH;
                end

            // ---- with ----
            S_SW_X: begin
                if (at_kind == 2'd2) begin rf[`SX(6'(sp - 7'd1))] <= at_v; rf[`SX(sp)] <= t[0]; sp <= sp + 7'd1; end
                else if (at_kind == 2'd1) begin rf[`SX(6'(sp - 7'd1))] <= at_v; rf[`SX(sp)] <= VNULL; sp <= sp + 7'd1; end
                if (at_kind == 2'd1 || at_kind == 2'd2) begin
                    at_q <= ABI_Q_ENTER_D; gosub_scr(SCR_AT, S_AT, S_SW_E);
                end else if (at_kind == 2'd3) begin
                    aux <= vint(jt); aux2 <= vint(32'd0); aux3 <= t[0];
                    fcont <= ABI_CONT_WITH_ATTR;
                    hook(ABI_HOOK_GETATTR, ABI_RK_CONT, 8'd2, t[0], {ABI_TAG_QSTR, ABI_Q_EXIT_D}, VNULL, VNULL);
                end else raise_err(ABI_ERR_ATTR, t[0], {ABI_TAG_QSTR, ABI_Q_EXIT_D});
            end
            S_SW_E: if (at_kind == 2'd2 || at_kind == 2'd1) begin
                    ab_lo <= (at_kind == 2'd2) ? 8'd31 : 8'd32; ab_pe <= 8'd32; ab_nkw <= 8'd0;
                    crk <= ABI_RK_CONT; fcont <= ABI_CONT_WITH_ENTER; aux <= vint(jt);
                    wr(ab_ptr(8'd0), at_v, S_AB_31);
                end else if (at_kind == 2'd3) begin
                    aux <= vint(jt); aux2 <= vint(32'd1); aux3 <= t[0];
                    fcont <= ABI_CONT_WITH_ATTR;
                    hook(ABI_HOOK_GETATTR, ABI_RK_CONT, 8'd2, t[0], {ABI_TAG_QSTR, ABI_Q_ENTER_D}, VNULL, VNULL);
                end else raise_err(ABI_ERR_ATTR, t[0], {ABI_TAG_QSTR, ABI_Q_ENTER_D});
            S_AB_31: wr(ab_ptr(8'd31), t[0], S_CALL);
            S_WC: begin
                ab_nkw <= 8'd0; crk <= ABI_RK_CONT; ab_pe <= 8'd35;
                if (rf[`SX(6'(sp - 7'd1))] == VNONE) begin
                    x0 <= 32'd0;
                    ab_lo <= (rf[`SX(6'(sp - 7'd2))] != VNULL) ? 8'd31 : 8'd32;
                    fcont <= ABI_CONT_WITH_NONE;
                end else if (tg(rf[`SX(6'(sp - 7'd1))]) == ABI_TAG_INT) begin
                    x0 <= 32'd1;
                    ab_lo <= (rf[`SX(6'(sp - 7'd3))] != VNULL) ? 8'd31 : 8'd32;
                    aux <= rf[`SX(6'(sp - 7'd2))]; aux2 <= rf[`SX(6'(sp - 7'd1))];
                    fcont <= ABI_CONT_WITH_UNWIND;
                end else begin
                    x0 <= 32'd2;
                    ab_lo <= (rf[`SX(6'(sp - 7'd2))] != VNULL) ? 8'd31 : 8'd32;
                    aux <= rf[`SX(6'(sp - 7'd1))];
                    fcont <= ABI_CONT_WITH_EXC;
                end
                i0 <= 8'd0; st <= S_WC_W;
            end
            // sp stays put until the writes finish, so the rf sources do not move.
            S_WC_W: begin
                case (i0)
                    8'd0: begin wr(ab_ptr(8'd34), VNONE, S_WC_W); i0 <= 8'd1; end
                    8'd1: if (x0 == 32'd2) i0 <= 8'd2;
                          else begin wr(ab_ptr(8'd32), VNONE, S_WC_W); i0 <= 8'd2; end
                    8'd2: begin
                        if (x0 == 32'd2) wr(ab_ptr(8'd33), rf[`SX(6'(sp - 7'd1))], S_WC_W);
                        else wr(ab_ptr(8'd33), VNONE, S_WC_W);
                        i0 <= 8'd3;
                    end
                    8'd3: begin
                        if (x0 == 32'd1) wr(ab_ptr(8'd0), rf[`SX(6'(sp - 7'd4))], S_WC_W);
                        else wr(ab_ptr(8'd0), rf[`SX(6'(sp - 7'd3))], S_WC_W);
                        i0 <= 8'd4;
                    end
                    8'd4: begin
                        if (x0 == 32'd1) wr(ab_ptr(8'd31), rf[`SX(6'(sp - 7'd3))], S_WC_W);
                        else wr(ab_ptr(8'd31), rf[`SX(6'(sp - 7'd2))], S_WC_W);
                        i0 <= 8'd5;
                    end
                    default: if (x0 == 32'd2) rd(adr(rf[`SX(6'(sp - 7'd1))]) + 4, S_WC_T);
                             else st <= S_WC_SP;
                endcase
            end
            S_WC_T: wr(ab_ptr(8'd32), mv, S_WC_SP);
            S_WC_SP: begin
                if (x0 == 32'd1) sp <= sp - 7'd4;
                else sp <= sp - 7'd3;
                st <= S_CALL;
            end

            // sw_k is the word phase. Callers enter these at 0.
            // Push args: x0 handler, b0 finally, x1[15:0] stack depth.
            S_XPUSH: if (xsp != 5'd0 && sw_k != 2'd3) begin
                         v0 = exc_ptr(fbase, xsp - 5'd1) + {28'd0, sw_k, 2'b00};
                         case (sw_k)
                             2'd0: wr(v0, {4'd0, xh}, S_XPUSH);
                             2'd1: wr(v0, {4'd0, xf, 15'd0, xv}, S_XPUSH);
                             default: wr(v0, xp, S_XPUSH);
                         endcase
                         sw_k <= sw_k + 2'd1;
                     end else begin
                         xh <= x0; xv <= x1[15:0]; xf <= b0; xp <= VNULL;
                         xsp <= xsp + 5'd1;
                         ret();
                     end
            S_XPOP: if (sw_k == 2'd0) begin
                        if (xsp <= 5'd1) begin
                            if (xsp == 5'd1) xsp <= 5'd0;
                            ret();
                        end else begin
                            rd(exc_ptr(fbase, xsp - 5'd2), S_XPOP);
                            xsp <= xsp - 5'd1;
                            sw_k <= 2'd1;
                        end
                    end else if (sw_k == 2'd1) begin
                        xh <= md;
                        rd(exc_ptr(fbase, xsp - 5'd1) + 32'd4, S_XPOP);
                        sw_k <= 2'd2;
                    end else if (sw_k == 2'd2) begin
                        xv <= md[15:0];
                        xf <= md[31];
                        rd(exc_ptr(fbase, xsp - 5'd1) + 32'd8, S_XPOP);
                        sw_k <= 2'd3;
                    end else begin
                        xp <= mv;
                        ret();
                    end
            // Top goes into the frame that already holds entries [0, xsp-2].
            // A generator image copy still reads that frame from x4.
            S_XFLUSH: if (xsp == 5'd0 || sw_k == 2'd3) ret();
                      else begin
                          v0 = exc_ptr(spill_to_img ? x4 : fbase, xsp - 5'd1) + {28'd0, sw_k, 2'b00};
                          case (sw_k)
                              2'd0: wr(v0, {4'd0, xh}, S_XFLUSH);
                              2'd1: wr(v0, {4'd0, xf, 15'd0, xv}, S_XFLUSH);
                              default: wr(v0, xp, S_XFLUSH);
                          endcase
                          sw_k <= sw_k + 2'd1;
                      end
            S_XLOAD: if (xsp == 5'd0) ret();
                     else if (sw_k == 2'd0) begin
                         rd(exc_ptr(fbase, xsp - 5'd1), S_XLOAD);
                         sw_k <= 2'd1;
                     end else if (sw_k == 2'd1) begin
                         xh <= md;
                         rd(exc_ptr(fbase, xsp - 5'd1) + 32'd4, S_XLOAD);
                         sw_k <= 2'd2;
                     end else if (sw_k == 2'd2) begin
                         xv <= md[15:0];
                         xf <= md[31];
                         rd(exc_ptr(fbase, xsp - 5'd1) + 32'd8, S_XLOAD);
                         sw_k <= 2'd3;
                     end else begin
                         xp <= mv;
                         ret();
                     end
            S_XS: if (sw_k == 2'd0) begin
                      rd(exc_ptr(fbase, sw_i[4:0]) + 32'd8, S_XS);
                      sw_k <= 2'd1;
                  end else if (mv != VNULL) begin
                      xc <= mv; rx_from <= 1'b0; rsp <= 5'd0; st <= S_RAISE;
                  end else if (sw_i == 32'd0) raise_msg(ABI_MSG_NO_ACTIVE_EXC);
                  else begin
                      rd(exc_ptr(fbase, sw_i[4:0] - 5'd1) + 32'd8, S_XS);
                      sw_i <= sw_i - 32'd1;
                  end
            S_XEF: begin
                if (rf[`SX(6'(sp - 7'd1))] == VNONE) begin sp <= sp - 7'd1; st <= S_FETCH; end
                else if (tg(rf[`SX(6'(sp - 7'd1))]) == ABI_TAG_INT) begin
                    if (rf[`SX(6'(sp - 7'd1))][31]) begin sp <= sp - 7'd1; st <= S_UR; end
                    else st <= S_UJ;
                end else raise_val(rf[`SX(6'(sp - 7'd1))]);
            end

            // ---- unwinding for return and jumps out of finally/with/for ----
            S_UR: if (has_link && sp <= 7'(RF_RELOAD_AT)) begin
                      rf_resume <= S_UR; st <= S_RF_RELOAD;
                  end else if (xsp == 5'd0) begin
                      t[7] <= rf[`SX(sp - 7'd1)];
                      if (gen != VNULL) begin pc <= 32'd0; st <= S_GN_RET; end
                      else st <= S_RET;
                  end else if (xf && xh >= pc) begin
                      // The direct write indexes the ring. A saved depth that
                      // needs two more slots than the file holds takes the slow path.
                      if (spilled_reals != 16'd0 || has_link || rf_base != 6'd0 ||
                          (32'(xv) + 32'd2 > 32'(MPY_RF_DEPTH))) begin
                          ur_target <= xv;
                          ur_val <= rf[`SX(sp - 7'd1)];
                          pc <= xh;
                          st <= S_UR_SLOW;
                      end else begin
                          rf[`SX(xv[6:0])] <= rf[`SX(sp - 7'd1)];
                          rf[`SX(6'(xv[6:0] + 7'd1))] <= vint(32'hFFFF_FFFF);
                          sp <= xv[6:0] + 7'd2;
                          pc <= xh;
                          st <= S_FETCH;
                      end
                  end else begin
                      if (xf) begin
                          if (tg(rf[`SX(6'(sp - 7'd2))]) == ABI_TAG_INT) begin
                              rf[`SX(6'(sp - 7'd3))] <= rf[`SX(6'(sp - 7'd1))]; sp <= sp - 7'd2;
                          end else begin
                              rf[`SX(6'(sp - 7'd2))] <= rf[`SX(6'(sp - 7'd1))]; sp <= sp - 7'd1;
                          end
                      end
                      sw_k <= 2'd0;
                      gosub(S_XPOP, S_UR);
                  end
            S_UJ: begin uj <= rf[`SX(6'(sp - 7'd1))][31:0]; sp <= sp - 7'd1; st <= S_UJ_L; end
            S_UJ_L: if (uj[6:0] == 7'd0) begin
                        pc <= rf[`SX(6'(sp - 7'd1))][31:0];
                        sp <= sp - 7'd1 - (uj[7] ? 7'd4 : 7'd0);
                        st <= S_FETCH;
                    end else if (xsp == 5'd0) begin
                        uj <= uj - 32'd1;
                    end else if (xf && xh >= pc) begin
                        uj <= uj - 32'd1;
                        push(vint(uj - 32'd1)); pc <= xh; st <= S_FETCH;
                    end else begin
                        uj <= uj - 32'd1;
                        if (xf) begin
                            if (tg(rf[`SX(6'(sp - 7'd2))]) == ABI_TAG_INT) begin
                                rf[`SX(6'(sp - 7'd3))] <= rf[`SX(6'(sp - 7'd1))]; sp <= sp - 7'd2;
                            end else begin
                                rf[`SX(6'(sp - 7'd2))] <= rf[`SX(6'(sp - 7'd1))]; sp <= sp - 7'd1;
                            end
                        end
                        sw_k <= 2'd0;
                        gosub(S_XPOP, S_UJ_L);
                    end

            // ---- RAISE_OBJ ----
            S_ROBJ: if (tg(t[0]) != ABI_TAG_OBJECT) raise_err(ABI_ERR_NOT_EXC, t[0], VNULL);
                    else rd(adr(t[0]), S_ROBJ_K);
            S_ROBJ_K: if (md == ABI_OB_EXCEPTION) raise_val(t[0]);
                      else if (md == ABI_OB_TYPE) rd(adr(t[0]) + 28, S_ROBJ_T);
                      else raise_err(ABI_ERR_NOT_EXC, t[0], VNULL);
            S_ROBJ_T: if (md & ABI_TF_EXC) begin
                          wr(ab_ptr(8'd0), t[0], S_CALL);
                          ab_lo <= 8'd32; ab_pe <= 8'd32; ab_nkw <= 8'd0;
                          crk <= ABI_RK_CONT; fcont <= ABI_CONT_RAISE;
                      end else raise_err(ABI_ERR_NOT_EXC, t[0], VNULL);

            // ---- GET_ITER_STACK ----
            S_GI: begin
                vs0 = 7'(sp - 7'd1);
                if (tg(t[0]) == ABI_TAG_TUPLE || tg(t[0]) == ABI_TAG_BYTES || is_mut(t[0], ABI_MUT_LIST) ||
                    is_mut(t[0], ABI_MUT_DICT) || is_mut(t[0], ABI_MUT_SET) || is_mut(t[0], ABI_MUT_BYTEARRAY) ||
                    tg(t[0]) == ABI_TAG_ITER || (tg(t[0]) == ABI_TAG_OBJECT && b1)) begin
                    rf[`SX(6'(vs0 + 7'd1))] <= vint(32'd0); rf[`SX(6'(vs0 + 7'd2))] <= vint(32'd0);
                    rf[`SX(6'(vs0 + 7'd3))] <= vint(
                        (tg(t[0]) == ABI_TAG_ITER) ? ABI_IT_HEAPITER :
                        (tg(t[0]) == ABI_TAG_OBJECT) ? ABI_IT_PYOBJ :
                        is_mut(t[0], ABI_MUT_DICT) ? ABI_IT_DICT :
                        is_mut(t[0], ABI_MUT_SET) ? ABI_IT_SET : ABI_IT_SEQ);
                    sp <= sp + 7'd3; st <= S_FETCH;
                end else if (tg(t[0]) == ABI_TAG_RANGE) rd(adr(t[0]), S_GI_R0);
                else if (strlike(t[0])) begin si_v <= t[0]; gosub(S_SINFO, S_GI_S); end
                else if (tg(t[0]) == ABI_TAG_OBJECT) rd(adr(t[0]), S_GI_K);
                else st <= S_GI_FB;
            end
            S_GI_R0: begin rf[`SX(6'(sp - 7'd1))] <= mv; rd(adr(t[0]) + 4, S_GI_R1); end
            S_GI_R1: begin rf[`SX(sp)] <= mv; rd(adr(t[0]) + 8, S_GI_R2); end
            S_GI_R2: begin
                rf[`SX(6'(sp + 7'd1))] <= mv; rf[`SX(6'(sp + 7'd2))] <= vint(ABI_IT_RANGE);
                sp <= sp + 7'd3; st <= S_FETCH;
            end
            S_GI_S: if (si_na) st <= S_GI_FB;
                    else begin
                        rf[`SX(sp)] <= vint(32'd0); rf[`SX(6'(sp + 7'd1))] <= vint(32'd0);
                        rf[`SX(6'(sp + 7'd2))] <= vint(ABI_IT_STR);
                        sp <= sp + 7'd3; st <= S_FETCH;
                    end
            S_GI_K: if (md == ABI_OB_DICT_VIEW) rd(adr(t[0]) + 8, S_GI_V0);
                    else begin at_q <= ABI_Q_ITER_D; gosub_scr(SCR_AT, S_AT, S_GI_AT); end
            S_GI_V0: begin rf[`SX(6'(sp - 7'd1))] <= mv; rd(adr(t[0]) + 12, S_GI_V1); end
            S_GI_V1: begin
                rf[`SX(sp)] <= vint(32'd0); rf[`SX(6'(sp + 7'd1))] <= mv; rf[`SX(6'(sp + 7'd2))] <= vint(ABI_IT_DICT);
                sp <= sp + 7'd3; st <= S_FETCH;
            end
            S_GI_AT: if (at_kind == 2'd2 || at_kind == 2'd1) begin
                    ab_lo <= (at_kind == 2'd2) ? 8'd31 : 8'd32; ab_pe <= 8'd32; ab_nkw <= 8'd0;
                    crk <= ABI_RK_CONT; fcont <= ABI_CONT_GETITER; pc <= op_pc;
                    wr(ab_ptr(8'd0), at_v, S_AB_31);
                end else st <= S_GI_FB;
            S_GI_FB: begin
                fcont <= ABI_CONT_GETITER; pc <= op_pc;
                hook(ABI_HOOK_GETITER, ABI_RK_CONT, 8'd1, t[0], VNULL, VNULL, VNULL);
            end

            // ---- FOR_ITER ----
            // Install the four iterator words as the IT image, then step or
            // call __next__. A different resident image is stored first.
            S_FI_PRE: if (scr_id != SCR_NONE && scr_id != SCR_IT) scr_go_store(scr_id, S_FI_PRE);
                      else begin
                          for (int k = 0; k < 4; k++) `iv[k] <= rf[`SX(6'(sp - 7'd4 + 7'(k)))];
                          scr_id <= SCR_IT;
                          if (rf[`SX(6'(sp - 7'd4))] == VNULL) begin
                              if (tg(rf[`SX(6'(sp - 7'd3))]) == ABI_TAG_ITER) begin
                                  it_h <= 1'b1; t[3] <= rf[`SX(6'(sp - 7'd3))]; i0 <= 8'd0; st <= S_FI_LD;
                              end else begin
                                  t[0] <= rf[`SX(6'(sp - 7'd3))];
                                  if (tg(rf[`SX(6'(sp - 7'd3))]) == ABI_TAG_OBJECT)
                                      rd(adr(rf[`SX(6'(sp - 7'd3))]), S_FI_GK);
                                  else begin
                                      at_q <= ABI_Q_NEXT_D;
                                      scr_go_store_gosub(SCR_IT, S_AT, S_FI_AT);
                                  end
                              end
                          end else if (rf[`SX(6'(sp - 7'd1))] == vint(ABI_IT_HEAPITER)) begin
                              it_h <= 1'b1; t[3] <= rf[`SX(6'(sp - 7'd4))]; i0 <= 8'd0; st <= S_FI_LD;
                          end else begin it_h <= 1'b0; gosub(S_IT, S_FI_R); end
                      end
            S_FI_LD: if (i0 == 8'd0 && scr_id != SCR_NONE && scr_id != SCR_IT)
                         scr_go_store(scr_id, S_FI_LD);
                     else begin
                         if (scr_id != SCR_IT) scr_id <= SCR_IT;
                         if (i0 == 8'd4) gosub(S_IT, S_FI_R);
                         else rd(adr(t[3]) + 4 * i0, S_FI_LD2);
                     end
            S_FI_LD2: begin `iv[i0[1:0]] <= mv; i0 <= i0 + 8'd1; st <= S_FI_LD; end
            S_FI_R: if (it_py) begin
                    t[0] <= `iv[0];
                    if (tg(`iv[0]) == ABI_TAG_OBJECT) rd(adr(`iv[0]), S_FI_GK);
                    else begin at_q <= ABI_Q_NEXT_D; gosub_scr(SCR_AT, S_AT, S_FI_AT); end
                end else if (it_h) wr(adr(t[3]), `iv[0], S_FI_W1);
                else begin
                    rf[`SX(6'(sp - 7'd4))] <= `iv[0]; rf[`SX(6'(sp - 7'd3))] <= `iv[1];
                    st <= S_FI_DONE;
                end
            S_FI_W1: wr(adr(t[3]) + 4, `iv[1], S_FI_DONE);
            S_FI_DONE: begin
                if (it_stop) begin sp <= sp - 7'd4; pc <= jt; end
                else push(it_val);
                st <= S_FETCH;
            end
            S_FI_AT: if (at_kind == 2'd2 || at_kind == 2'd1) begin
                    ab_lo <= (at_kind == 2'd2) ? 8'd31 : 8'd32; ab_pe <= 8'd32; ab_nkw <= 8'd0;
                    crk <= ABI_RK_CONT; fcont <= ABI_CONT_FOR_NEXT; aux <= vint(jt);
                    wr(ab_ptr(8'd0), at_v, S_AB_31);
                end else raise_err(ABI_ERR_NOT_ITERATOR, t[0], VNULL);
            // Word 0 of the object FOR_ITER was about to call __next__ on.
            // A generator enters the same resume __next__ would have called.
            S_FI_GK: if (md == ABI_OB_GENERATOR) begin
                    t[1] <= VNONE; t[2] <= VNONE;
                    r_rk <= ABI_RK_CONT; fcont <= ABI_CONT_FOR_NEXT; aux <= vint(jt);
                    st <= S_GR0;
                end else begin
                    at_q <= ABI_Q_NEXT_D; gosub_scr(SCR_AT, S_AT, S_FI_AT);
                end

            // ---- containers ----
            S_BT_R: begin
                drop_left <= {8'd0, tb_n};
                drop_push_en <= 1'b1;
                drop_push_v <= tb_v;
                drop_then <= S_FETCH;
                st <= S_DROP;
            end
            S_BL_A: begin
                v0 = (arg < 32'd4) ? 32'd4 : arg;
                wb_v[0] <= vint(arg); wb_v[1] <= vint(v0); wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
                t[0] <= vmut(al_a, ABI_MUT_LIST);
                i0 <= 8'd0;
                wblock(al_a, 4'd3, S_BL_L);
            end
            S_BL_L: if (i0 == arg[7:0]) begin
                        drop_left <= {8'd0, arg[7:0]};
                        drop_push_en <= 1'b1;
                        drop_push_v <= t[0];
                        drop_then <= S_FETCH;
                        st <= S_DROP;
                    end else begin
                        v0 = 32'(stk_depth) - arg + 32'(i0);
                        if (stk_hit(v0[15:0])) begin
                            wr(adr(t[0]) + 12 + 4 * i0, stk_val(v0[15:0]), S_BL_L);
                            i0 <= i0 + 8'd1;
                        end else begin
                            srd_g <= v0[15:0];
                            gosub(S_SRD, S_BL_W);
                        end
                    end
            S_BL_W: begin wr(adr(t[0]) + 12 + 4 * i0, srd_v, S_BL_L); i0 <= i0 + 8'd1; end
            S_BM_A: begin
                wb_v[0] <= vint(32'd0); wb_v[1] <= vint(arg);
                wb_v[2] <= (arg == 32'd0) ? VNULL : {ABI_TAG_CONT, al_a + 32'd16};
                wb_v[3] <= vint(32'd0);
                rf[`SX(sp)] <= vmut(al_a, ABI_MUT_DICT); sp <= sp + 7'd1;
                wblock(al_a, 4'd4, S_FETCH);
            end
            S_BSET_R: if ({8'd0, tb_n} > resident_reals) begin
                    drop_left <= {8'd0, tb_n};
                    drop_push_en <= 1'b0;
                    drop_then <= S_BSET_H;
                    st <= S_DROP;
                end else begin
                    sp <= sp - 7'(tb_n);
                    hook(ABI_HOOK_DICTOP, ABI_RK_PUSH, 8'd4, vint(32'd0), tb_v, VNULL, VNULL);
                end
            S_BSET_H: hook(ABI_HOOK_DICTOP, ABI_RK_PUSH, 8'd4, vint(32'd0), tb_v, VNULL, VNULL);
            S_SLICE_A: begin
                wb_v[0] <= vint(ABI_OB_SLICE); wb_v[1] <= ty_slice;
                if (arg == 32'd3) begin
                    wb_v[2] <= rf[`SX(6'(sp - 7'd3))]; wb_v[3] <= rf[`SX(6'(sp - 7'd2))]; wb_v[4] <= rf[`SX(6'(sp - 7'd1))];
                end else begin
                    wb_v[2] <= rf[`SX(6'(sp - 7'd2))]; wb_v[3] <= rf[`SX(6'(sp - 7'd1))]; wb_v[4] <= VNONE;
                end
                rf[`SX(6'(sp - 7'(arg)))] <= vobj(al_a); sp <= sp - 7'(arg) + 7'd1;
                wblock(al_a, 4'd5, S_FETCH);
            end
            S_SC_L: begin sp <= sp - 7'd1; st <= S_FETCH; end
            S_SC_D: if (lk_cx || lk_ro) begin
                        sp <= sp - 7'd2;
                        hook(ABI_HOOK_DICTOP, ABI_RK_DISCARD, 8'd4, vint(32'd1), t[4], t[5], t[6]);
                    end else begin sp <= sp - 7'd2; st <= S_FETCH; end
            S_SC_S: if (lk_cx || lk_ro) begin
                        sp <= sp - 7'd1;
                        hook(ABI_HOOK_DICTOP, ABI_RK_DISCARD, 8'd4, vint(32'd2), t[4], t[5], VNULL);
                    end else begin sp <= sp - 7'd1; st <= S_FETCH; end
            S_STM_R: if (lk_cx || lk_ro) begin
                        sp <= sp - 7'd2;
                        hook(ABI_HOOK_DICTOP, ABI_RK_DISCARD, 8'd4, vint(32'd1), t[4], t[5], t[6]);
                    end else begin sp <= sp - 7'd2; st <= S_FETCH; end
            S_UPS_N: if (md != arg) begin
                        sp <= sp - 7'd1; fcont <= ABI_CONT_UNPACK;
                        hook(ABI_HOOK_UNPACK, ABI_RK_CONT, 8'd3, t[0], vint(arg), vint(32'd0), VNULL);
                    end else if (tg(t[0]) == ABI_TAG_TUPLE) begin
                        x2 <= adr(t[0]) + 4; x1 <= arg; sp <= sp - 7'd1; st <= S_UPS_L;
                    end else rd(adr(t[0]) + 8, S_UPS_P);
            S_UPS_P: begin x2 <= md; x1 <= arg; sp <= sp - 7'd1; st <= S_UPS_L; end
            S_UPS_L: if (x1 == 32'd0) st <= S_FETCH;
                     else rd(x2 + (x1 << 2) - 32'd4, S_UPS_V);
            S_UPS_V: begin x1 <= x1 - 32'd1; push(mv); st <= S_UPS_L; end

            // ---- MAKE_FUNCTION / MAKE_CLOSURE ----
            S_MF_C: rd(md + 4 * arg, S_MF_R);
            S_MF_R: begin
                c_rc <= md;
                if (op == 8'h20 || op == 8'h21) begin
                    tb_src <= 1'b1; tb_nz <= 1'b0; tb_from <= 8'(sp - 7'(ext));
                    stk_from <= stk_depth - 16'(ext); tb_n <= ext;
                    gosub(S_TUP, S_MF_CL);
                end else begin t[0] <= VNULL; st <= S_MF_RT; end
            end
            S_MF_CL: begin t[0] <= tb_v; st <= S_MF_RT; end
            // Word 7 is a root tuple. Nested functions copy the caller's so a
            // heap bytecode buffer stays live after the entry frame returns.
            S_MF_RT: if (fun == VNULL) begin t[1] <= VNULL; alloc(32'd8, S_MF_A); end
                     else rd(adr(fun) + 32'd28, S_MF_RT2);
            S_MF_RT2: begin t[1] <= mv; alloc(32'd8, S_MF_A); end
            S_MF_A: begin
                v0 = (op == 8'h20 || op == 8'h21) ? {24'd0, ext} : 32'd0;
                wb_v[0] <= vint(ABI_OB_FUNCTION); wb_v[1] <= ty_fun; wb_v[2] <= vint(c_rc);
                wb_v[3] <= t[0]; wb_v[6] <= glb; wb_v[7] <= t[1];
                if (op == 8'h33 || op == 8'h21) begin
                    wb_v[4] <= rf[`SX(6'(sp - 7'(v0) - 7'd2))]; wb_v[5] <= rf[`SX(6'(sp - 7'(v0) - 7'd1))];
                    v0 = v0 + 32'd2;
                end else begin wb_v[4] <= VNULL; wb_v[5] <= VNULL; end
                rf[`SX(6'(sp - 7'(v0)))] <= vobj(al_a); sp <= sp - 7'(v0) + 7'd1;
                wblock(al_a, 4'd8, S_FETCH);
            end

            // ---- CALL_*_VAR_KW: star-arg expansion ----
            // Direct mode is today's layout. A call that would pass slot 199
            // on a star, or whose keyword tail would pass slot 255, switches
            // to chunked mode: 16-value blocks addressed by i>>4.
            S_CVK_P: if (cv_wide) st <= S_CVK_PW;
                     else if (cv_i == cv_n) begin
                    if (op == 8'h37 && rf[`SX(6'(cv_fidx + 7'd1))] != VNULL) begin
                        b1 <= 1'b1; ab_lo <= 8'd31;
                    end else begin
                        b1 <= 1'b0; ab_lo <= 8'd32;
                    end
                    ab_pe <= 8'd32; cv_i <= 8'd0;
                    wr(ab_ptr(8'd0), rf[`SX(cv_fidx)], S_CVK_P2);
                end else begin
                    t[0] <= rf[`SX(6'(cv_base + 7'(cv_i)))];
                    if (cv_bm[cv_i[4:0]] && !(tg(rf[`SX(6'(cv_base + 7'(cv_i)))]) == ABI_TAG_TUPLE ||
                                             is_mut(rf[`SX(6'(cv_base + 7'(cv_i)))], ABI_MUT_LIST))) begin
                        aux <= vint({25'd0, 7'(cv_base + 7'(cv_i))}); fcont <= ABI_CONT_REPLACE; pc <= op_pc;
                        hook(ABI_HOOK_TUPLE, ABI_RK_CONT, 8'd1, rf[`SX(6'(cv_base + 7'(cv_i)))], VNULL, VNULL, VNULL);
                    end else cv_i <= cv_i + 8'd1;
                end
            S_CVK_P2: if (b1) wr(ab_ptr(8'd31), rf[`SX(6'(cv_fidx + 7'd1))], S_CVK_E);
                      else st <= S_CVK_E;
            S_CVK_PW: if (cv_i == cv_n) begin
                    cv_g <= cv_fun_g; cv_ret <= S_CVK_PF; st <= S_CVK_RD;
                end else begin
                    cv_g <= cv_pos_g + {8'd0, cv_i}; cv_ret <= S_CVK_PI; st <= S_CVK_RD;
                end
            S_CVK_PF: if (op == 8'h37) begin
                    t[2] <= t[3]; cv_g <= cv_fun_g + 16'd1; cv_ret <= S_CVK_PS; st <= S_CVK_RD;
                end else begin
                    b1 <= 1'b0; ab_lo <= 8'd32; ab_pe <= 8'd32; cv_i <= 8'd0;
                    wr(ab_ptr(8'd0), t[3], S_CVK_E);
                end
            S_CVK_PS: begin
                    t[6] <= t[3];
                    if (t[3] != VNULL) begin b1 <= 1'b1; ab_lo <= 8'd31; end
                    else begin b1 <= 1'b0; ab_lo <= 8'd32; end
                    ab_pe <= 8'd32; cv_i <= 8'd0;
                    wr(ab_ptr(8'd0), t[2], S_CVK_P2W);
                end
            S_CVK_P2W: if (b1) wr(ab_ptr(8'd31), t[6], S_CVK_E);
                       else st <= S_CVK_E;
            S_CVK_PI: begin
                    t[0] <= t[3];
                    if (cv_bm[cv_i[4:0]] && !(tg(t[3]) == ABI_TAG_TUPLE ||
                                             is_mut(t[3], ABI_MUT_LIST))) begin
                        if (stk_hit(cv_g)) begin
                            aux <= vint({25'd0, stk_slot(cv_g)});
                            fcont <= ABI_CONT_REPLACE;
                        end else begin
                            aux <= vint({16'd0, cv_g});
                            fcont <= ABI_CONT_SPILL_REPLACE;
                        end
                        pc <= op_pc;
                        hook(ABI_HOOK_TUPLE, ABI_RK_CONT, 8'd1, t[3], VNULL, VNULL, VNULL);
                    end else begin cv_i <= cv_i + 8'd1; st <= S_CVK_PW; end
                end
            // Walk the same chunk link as S_SRD, then store the tuple and its
            // tag nibble. The collector marks a spill payload from the nibble.
            S_CVK_SW0: rd(srd_addr, S_CVK_SW1);
            S_CVK_SW1: begin
                    v0 = 32'(mpy_rf_chunk_count(mt, md));
                    v1 = mpy_rf_chunk_prev(md);
                    if (v0 != 32'd0 && srd_off < v0[15:0]) begin
                        x1 <= v0 - 32'd1 - 32'(srd_off);
                        x0 <= srd_addr + 32'd4 + (32'((v0[5:0] + 6'd7) >> 3) << 2)
                              + ((v0 - 32'd1 - 32'(srd_off)) << 2);
                        st <= S_CVK_SWN;
                    end else if (v1 == 32'd0 || srd_hops == 8'd64)
                        halt(ABI_HALT_INTERNAL, 32'h0000_C0C1);
                    else begin
                        srd_off <= srd_off - v0[15:0];
                        srd_addr <= v1;
                        srd_hops <= srd_hops + 8'd1;
                        st <= S_CVK_SW0;
                    end
                end
            S_CVK_SWN: rd(srd_addr + 32'd4 + ((x1 >> 3) << 2), S_CVK_SWN2);
            S_CVK_SWN2: begin
                    case (x1[2:0])
                        3'd0: v3 = {md[31:4], t[7][35:32]};
                        3'd1: v3 = {md[31:8], t[7][35:32], md[3:0]};
                        3'd2: v3 = {md[31:12], t[7][35:32], md[7:0]};
                        3'd3: v3 = {md[31:16], t[7][35:32], md[11:0]};
                        3'd4: v3 = {md[31:20], t[7][35:32], md[15:0]};
                        3'd5: v3 = {md[31:24], t[7][35:32], md[19:0]};
                        3'd6: v3 = {md[31:28], t[7][35:32], md[23:0]};
                        default: v3 = {t[7][35:32], md[27:0]};
                    endcase
                    wr(srd_addr + 32'd4 + ((x1 >> 3) << 2), {4'd0, v3}, S_CVK_SWP);
                end
            S_CVK_SWP: wr(x0, t[7], S_CVK_SWD);
            S_CVK_SWD: begin pc <= op_pc; st <= S_FETCH; end
            S_CVK_RD: if (stk_hit(cv_g)) begin t[3] <= stk_val(cv_g); st <= cv_ret; end
                      else begin srd_g <= cv_g; gosub(S_SRD, S_CVK_RD2); end
            S_CVK_RD2: begin t[3] <= srd_v; st <= cv_ret; end
            S_CVK_E: if (cv_i == cv_n) begin
                    ab_nkw <= cv_j; crk <= ABI_RK_PUSH; gi <= 32'd0;
                    if (ab_chunked) ab_npos <= ab_nitems;
                    if (!cv_wide) sp <= cv_fidx;
                    st <= S_CVK_KW;
                end else if (cv_wide) begin
                    cv_g <= cv_pos_g + {8'd0, cv_i};
                    cv_ret <= cv_bm[cv_i[4:0]] ? S_CVK_ES : S_CVK_EV;
                    st <= S_CVK_RD;
                end else if (!cv_bm[cv_i[4:0]]) begin
                    wr(ab_ptr(ab_pe), rf[`SX(6'(cv_base + 7'(cv_i)))], S_CVK_E);
                    ab_pe <= ab_pe + 8'd1; cv_i <= cv_i + 8'd1;
                end else begin
                    t[0] <= rf[`SX(6'(cv_base + 7'(cv_i)))];
                    rd(adr(rf[`SX(6'(cv_base + 7'(cv_i)))]), S_CVK_N);
                end
            S_CVK_EV: if (ab_chunked) begin
                    cv_i <= cv_i + 8'd1; cv_ret <= S_CVK_E; st <= S_CVK_AP;
                end else begin
                    wr(ab_ptr(ab_pe), t[3], S_CVK_E);
                    ab_pe <= ab_pe + 8'd1; cv_i <= cv_i + 8'd1;
                end
            S_CVK_ES: begin t[0] <= t[3]; rd(adr(t[3]), S_CVK_N); end
            S_CVK_N: begin
                x4 <= md; gi <= 32'd0;
                if (tg(t[0]) == ABI_TAG_TUPLE) begin cv_items <= adr(t[0]) + 4; st <= S_CVK_L; end
                else rd(adr(t[0]) + 8, S_CVK_I);
            end
            S_CVK_I: begin cv_items <= md; st <= S_CVK_L; end
            S_CVK_L: if (gi == x4) begin cv_i <= cv_i + 8'd1; st <= S_CVK_E; end
                     else if (ab_chunked) rd(cv_items + (gi << 2), S_CVK_VC);
                     else if (ab_pe >= 8'd200) begin cv_kw <= 1'b0; st <= S_CVK_CH; end
                     else rd(cv_items + (gi << 2), S_CVK_V);
            S_CVK_VC: begin
                    t[3] <= mv; gi <= gi + 32'd1; cv_ret <= S_CVK_L; st <= S_CVK_AP;
                end
            S_CVK_V: begin
                wr(ab_ptr(ab_pe), mv, S_CVK_L);
                ab_pe <= ab_pe + 8'd1; gi <= gi + 32'd1;
            end
            S_CVK_KW: if (!ab_chunked && gi == 32'd0 &&
                          ({24'd0, ab_pe} + {23'd0, cv_j, 1'b0} > 32'd256)) begin
                    cv_kw <= 1'b1; st <= S_CVK_CH;
                end else if (gi == {23'd0, cv_j, 1'b0}) begin
                    if (cv_wide) begin
                        drop_left <= stk_depth - cv_fun_g;
                        drop_push_en <= 1'b0;
                        drop_then <= ab_chunked ? S_CVK_PACK : S_CALL;
                        st <= S_DROP;
                    end else st <= ab_chunked ? S_CVK_PACK : S_CALL;
                end else if (cv_wide) begin
                    cv_g <= cv_pos_g + {8'd0, cv_n} + gi[15:0];
                    cv_ret <= S_CVK_KV; st <= S_CVK_RD;
                end else if (ab_chunked) begin
                    t[3] <= rf[`SX(6'(cv_base + 7'(cv_n) + gi[6:0]))];
                    st <= S_CVK_KV;
                end else begin
                    wr(ab_ptr(ab_pe + gi[7:0]), rf[`SX(6'(cv_base + 7'(cv_n) + gi[6:0]))], S_CVK_KW);
                    gi <= gi + 32'd1;
                end
            // A NULL keyword key is the ** marker. The direct path turns it
            // into small int 0 while building the kw tuple.
            S_CVK_KV: begin
                    if (t[3] == VNULL && !gi[0]) t[3] <= vint(32'd0);
                    st <= S_CVK_KV2;
                end
            S_CVK_KV2: begin
                    gi <= gi + 32'd1;
                    if (ab_chunked) begin cv_ret <= S_CVK_KW; st <= S_CVK_AP; end
                    else begin wr(ab_ptr(ab_pe + gi[7:0]), t[3], S_CVK_KW); end
                end
            // Enter chunked mode and copy the direct positional window.
            S_CVK_CH: begin
                    ab_chunked <= 1'b1; ab_ovf <= 1'b0;
                    ab_npos <= {24'd0, ab_pe} - {24'd0, ab_lo};
                    ab_nitems <= 32'd0; ab_nblk <= 32'd0; ab_fill <= 5'd0;
                    ab_blk <= VNULL; t[5] <= VNULL; cv_k <= 32'd0;
                    wr(ab_ptr(8'd1), vint(32'd1), S_CVK_CH2);
                end
            S_CVK_CH2: wr(ab_ptr(8'd4), VNULL, S_CVK_CP);
            S_CVK_CP: if (cv_k == ab_npos) st <= cv_kw ? S_CVK_KW : S_CVK_L;
                      else rd(ab_ptr(8'({24'd0, ab_lo} + cv_k)), S_CVK_CPV);
            S_CVK_CPV: begin
                    t[3] <= mv; cv_k <= cv_k + 32'd1; cv_ret <= S_CVK_CP; st <= S_CVK_AP;
                end
            // Append t[3] to the block stream. cv_ret is where to resume.
            S_CVK_AP: if (ab_nblk != 32'd0 && ab_fill != 5'd16)
                    wr(adr(ab_blk) + 32'd4 + {25'd0, ab_fill, 2'b00}, t[3], S_CVK_EL);
                else alloc(32'd17, S_CVK_NB);
            S_CVK_EL: begin
                    wr(adr(ab_blk), vint({27'd0, ab_fill} + 32'd1), S_CVK_ELD);
                    ab_fill <= ab_fill + 5'd1; ab_nitems <= ab_nitems + 32'd1;
                end
            S_CVK_ELD: st <= cv_ret;
            S_CVK_NB: begin
                    ab_blk <= {ABI_TAG_TUPLE, al_a}; t[2] <= {ABI_TAG_TUPLE, al_a};
                    if (ab_ovf || ab_nblk >= 32'd251) st <= S_CVK_OVP;
                    else begin
                        wr(ab_ptr(8'(32'd5 + ab_nblk)), {ABI_TAG_TUPLE, al_a}, S_CVK_NBW);
                        ab_nblk <= ab_nblk + 32'd1; ab_fill <= 5'd0;
                    end
                end
            S_CVK_NBW: wr(adr(ab_blk) + 32'd4, t[3], S_CVK_NBL);
            S_CVK_NBL: begin
                    wr(adr(ab_blk), vint(32'd1), S_CVK_ELD);
                    ab_fill <= 5'd1; ab_nitems <= ab_nitems + 32'd1;
                end
            S_CVK_OVP: if (!ab_ovf) alloc(32'd253, S_CVK_MIG_A);
                       else rd(adr(t[5]), S_CVK_EXT_A);
            S_CVK_MIG_A: begin
                    t[4] <= {ABI_TAG_TUPLE, al_a}; cv_k <= 32'd0;
                    wr(al_a, vint(32'd252), S_CVK_MIG_C);
                end
            S_CVK_MIG_C: if (cv_k == 32'd251) begin
                    x0 <= 32'd252;
                    wr(adr(t[4]) + 32'd4 + (32'd251 << 2), t[2], S_CVK_MIG_D);
                end else rd(ab_ptr(8'(32'd5 + cv_k)), S_CVK_MIG_W);
            S_CVK_MIG_W: begin
                    wr(adr(t[4]) + 32'd4 + (cv_k << 2), mv, S_CVK_MIG_C);
                    cv_k <= cv_k + 32'd1;
                end
            S_CVK_MIG_D: begin
                    wr(ab_ptr(8'd4), t[4], S_CVK_NBW);
                    t[5] <= t[4]; ab_ovf <= 1'b1; ab_nblk <= x0; ab_fill <= 5'd0;
                end
            S_CVK_EXT_A: begin x1 <= md; alloc(md + 32'd2, S_CVK_EXT_C); end
            S_CVK_EXT_C: begin
                    t[4] <= {ABI_TAG_TUPLE, al_a}; cv_k <= 32'd0;
                    wr(al_a, vint(x1 + 32'd1), S_CVK_EXT_W);
                end
            S_CVK_EXT_W: if (cv_k == x1) begin
                    x0 <= ab_nblk + 32'd1;
                    wr(adr(t[4]) + 32'd4 + (x1 << 2), t[2], S_CVK_MIG_D);
                end else rd(adr(t[5]) + 32'd4 + (cv_k << 2), S_CVK_EXT_D);
            S_CVK_EXT_D: begin
                    wr(adr(t[4]) + 32'd4 + (cv_k << 2), mv, S_CVK_EXT_W);
                    cv_k <= cv_k + 32'd1;
                end
            // Copy the block-pointer directory onto the heap, then wipe ARGBUF.
            S_CVK_PACK: rd(ab_ptr(8'd0), S_CVK_PK0);
            S_CVK_PK0: begin
                    t[0] <= mv;
                    if (ab_ovf) begin t[1] <= t[5]; cv_k <= 32'd5; x1 <= 32'd256; st <= S_CVK_W1; end
                    else if (ab_nblk == 32'd0) begin
                        t[1] <= {ABI_TAG_TUPLE, h_empty}; cv_k <= 32'd5; x1 <= 32'd5; st <= S_CVK_W1;
                    end else alloc(32'd1 + ab_nblk, S_CVK_PKA);
                end
            S_CVK_PKA: begin
                    t[1] <= {ABI_TAG_TUPLE, al_a}; cv_k <= 32'd0;
                    wr(al_a, vint(ab_nblk), S_CVK_PKC);
                end
            S_CVK_PKC: if (cv_k == ab_nblk) begin
                    cv_k <= 32'd5; x1 <= 32'd5 + ab_nblk; st <= S_CVK_W1;
                end else rd(ab_ptr(8'(32'd5 + cv_k)), S_CVK_PKW);
            S_CVK_PKW: begin
                    wr(adr(t[1]) + 32'd4 + (cv_k << 2), mv, S_CVK_PKC);
                    cv_k <= cv_k + 32'd1;
                end
            S_CVK_W1: if (cv_k == x1) st <= S_CVK_W4;
                      else begin
                          wr(ab_ptr(cv_k[7:0]), VNULL, S_CVK_W1);
                          cv_k <= cv_k + 32'd1;
                      end
            S_CVK_W4: if (ab_ovf) wr(ab_ptr(8'd4), VNULL, S_CVK_W1B);
                      else st <= S_CVK_W1B;
            S_CVK_W1B: wr(ab_ptr(8'd1), VNULL, S_CALL);

            // Chunked bound-method self: a new one-value block at directory[0].
            S_CALL_BSC: begin t[2] <= mv; alloc(32'd2, S_CALL_BSC2); end
            S_CALL_BSC2: begin
                    t[3] <= {ABI_TAG_TUPLE, al_a};
                    wr(al_a, vint(32'd1), S_CALL_BSC3);
                end
            S_CALL_BSC3: wr(al_a + 32'd4, t[2], S_CALL_BSC4);
            S_CALL_BSC4: alloc(32'd2 + ab_nblk, S_CALL_BSC5);
            S_CALL_BSC5: begin
                    t[4] <= {ABI_TAG_TUPLE, al_a}; x0 <= al_a; cv_k <= 32'd0;
                    wr(al_a, vint(ab_nblk + 32'd1), S_CALL_BSC6);
                end
            S_CALL_BSC6: wr(x0 + 32'd4, t[3], S_CALL_BSC7);
            S_CALL_BSC7: if (cv_k == ab_nblk) begin
                    t[1] <= t[4];
                    ab_npos <= ab_npos + 32'd1; ab_nblk <= ab_nblk + 32'd1;
                    rd(adr(ab_q) + 8, S_CALL_BF);
                end else rd(adr(t[1]) + 32'd4 + (cv_k << 2), S_CALL_BSC8);
            S_CALL_BSC8: begin
                    wr(x0 + 32'd8 + (cv_k << 2), mv, S_CALL_BSC7);
                    cv_k <= cv_k + 32'd1;
                end
            // Closure cells were written into ARGBUF by S_CF_CLI. Prepend them
            // as one leading block so _bind_wide sees them as positionals.
            S_BS_W: if (ab_lo0 != ab_lo) begin
                    x1 <= {24'd0, ab_lo0} - {24'd0, ab_lo};
                    cv_k <= 32'd0;
                    alloc(32'd1 + ({24'd0, ab_lo0} - {24'd0, ab_lo}), S_BS_CL);
                end else st <= S_BS_HK;
            S_BS_CL: begin
                    t[3] <= {ABI_TAG_TUPLE, al_a}; x0 <= al_a;
                    wr(al_a, vint(x1), S_BS_CL2);
                end
            S_BS_CL2: if (cv_k == x1) st <= S_BS_CLP;
                      else rd(ab_ptr(ab_lo + cv_k[7:0]), S_BS_CL3);
            S_BS_CL3: begin
                    wr(x0 + 32'd4 + (cv_k << 2), mv, S_BS_CL2);
                    cv_k <= cv_k + 32'd1;
                end
            S_BS_CLP: begin cv_k <= 32'd0; alloc(32'd2 + ab_nblk, S_BS_CL4); end
            S_BS_CL4: begin
                    t[4] <= {ABI_TAG_TUPLE, al_a}; x0 <= al_a;
                    wr(al_a, vint(ab_nblk + 32'd1), S_BS_CL5);
                end
            S_BS_CL5: wr(x0 + 32'd4, t[3], S_BS_CL6);
            S_BS_CL6: if (cv_k == ab_nblk) begin
                    t[1] <= t[4];
                    ab_npos <= ab_npos + x1; ab_nblk <= ab_nblk + 32'd1;
                    ab_lo <= ab_lo0;
                    st <= S_BS_HK;
                end else rd(adr(t[1]) + 32'd4 + (cv_k << 2), S_BS_CL7);
            S_BS_CL7: begin
                    wr(x0 + 32'd8 + (cv_k << 2), mv, S_BS_CL6);
                    cv_k <= cv_k + 32'd1;
                end
            S_BS_HK: rd(ab_ptr(8'd0), S_BS_HK2);
            S_BS_HK2: begin
                    fflags <= fflags | FF_NOTB; fcont <= ABI_CONT_BIND;
                    hook(ABI_HOOK_BIND_WIDE, ABI_RK_CONT, 8'd3, mv, vint(ab_npos), t[1], VNULL);
                end

            // ---------------- unary / binary ----------------
            S_UN: begin
                v0 = 32'(n_o);
                if (v0 == ABI_UNOP_NOT) begin tr_v <= rf[`SX(6'(sp - 7'd1))]; gosub(S_TR, S_JT); end
                else if (numlike(rf[`SX(6'(sp - 7'd1))]) && v0 <= ABI_UNOP_INVERT) begin
                    n_un <= 1'b1;
                    alu_op <= (v0 == ABI_UNOP_POSITIVE) ? ALU_POS : (v0 == ABI_UNOP_NEGATIVE) ? ALU_NEG : ALU_INVERT;
                    t[0] <= rf[`SX(6'(sp - 7'd1))]; t[1] <= vint(32'd0);
                    st <= S_NUM;
                end else begin
                    sp <= sp - 7'd1;
                    hook(ABI_HOOK_UNOP, ABI_RK_PUSH, 8'd2, vint(v0), rf[`SX(6'(sp - 7'd1))], VNULL, VNULL);
                end
            end
            S_BIN: begin
                v0 = 32'(n_o);
                t[0] <= rf[`SX(6'(sp - 7'd2))]; t[1] <= rf[`SX(6'(sp - 7'd1))];
                n_un <= 1'b0;
                if (v0 == ABI_BINOP_IS) begin
                    rf[`SX(6'(sp - 7'd2))] <= vbool(rf[`SX(6'(sp - 7'd2))] == rf[`SX(6'(sp - 7'd1))]);
                    sp <= sp - 7'd1; st <= S_FETCH;
                end else if (v0 == ABI_BINOP_EXCEPTION_MATCH) st <= S_EXM;
                else if (v0 == ABI_BINOP_IN) st <= S_IN;
                else if (numlike(rf[`SX(6'(sp - 7'd2))]) && numlike(rf[`SX(6'(sp - 7'd1))]) &&
                         (v0 <= ABI_BINOP_NOT_EQUAL || (v0 >= ABI_BINOP_INPLACE_OR && v0 <= ABI_BINOP_POWER))) begin
                    alu_op <= (v0 >= ABI_BINOP_INPLACE_OR && v0 < ABI_BINOP_OR) ? 6'(v0 + 32'd13) : 6'(v0);
                    st <= S_NUM;
                end else if (v0 == ABI_BINOP_EQUAL || v0 == ABI_BINOP_NOT_EQUAL) st <= S_EQ;
                else st <= S_BIN_FB;
            end
            S_BIN_FB: begin
                sp <= sp - 7'd2;
                hook(ABI_HOOK_BINOP, ABI_RK_PUSH, 8'd3, vint(32'(n_o)), t[0], t[1], VNULL);
            end
            S_EQ: begin
                vb = (32'(n_o) == ABI_BINOP_NOT_EQUAL);
                if (t[0] == t[1] && tg(t[0]) != ABI_TAG_OBJECT && tg(t[0]) != ABI_TAG_COMPLEX) begin
                    rf[`SX(6'(sp - 7'd2))] <= vbool(!vb); sp <= sp - 7'd1; st <= S_FETCH;
                end else if (strlike(t[0]) && strlike(t[1])) begin
                    se_a <= t[0]; se_b <= t[1]; gosub_scr(SCR_SE, S_STREQ, S_EQ_S);
                end else if (strlike(t[0]) || strlike(t[1]) ||
                             (tg(t[0]) == ABI_TAG_CONTROL && tg(t[1]) != ABI_TAG_OBJECT) ||
                             (tg(t[1]) == ABI_TAG_CONTROL && tg(t[0]) != ABI_TAG_OBJECT)) begin
                    rf[`SX(6'(sp - 7'd2))] <= vbool(vb); sp <= sp - 7'd1; st <= S_FETCH;
                end else st <= S_BIN_FB;
            end
            S_EQ_S: begin
                rf[`SX(6'(sp - 7'd2))] <= vbool(se_eq ^ (32'(n_o) == ABI_BINOP_NOT_EQUAL));
                sp <= sp - 7'd1; st <= S_FETCH;
            end
            S_IN: if ((is_mut(t[1], ABI_MUT_DICT) || is_mut(t[1], ABI_MUT_SET)))
                      lookup(t[1], t[0], VNULL, LK_FIND, is_mut(t[1], ABI_MUT_SET), S_IN_R);
                  else st <= S_BIN_FB;
            S_IN_R: if (lk_cx) st <= S_BIN_FB;
                    else begin rf[`SX(6'(sp - 7'd2))] <= vbool(lk_found); sp <= sp - 7'd1; st <= S_FETCH; end

            S_EXM: if (tg(t[0]) != ABI_TAG_OBJECT) st <= S_BIN_FB;
                   else rd(adr(t[0]) + 4, S_EXM_T);
            S_EXM_T: begin
                is_t <= mv;
                if (tg(t[1]) == ABI_TAG_OBJECT) begin is_c <= t[1]; gosub(S_ISSUB, S_EXM_R); end
                else if (tg(t[1]) == ABI_TAG_TUPLE) rd(adr(t[1]), S_EXM_TN);
                else st <= S_BIN_FB;
            end
            S_EXM_R: begin rf[`SX(6'(sp - 7'd2))] <= vbool(is_r); sp <= sp - 7'd1; st <= S_FETCH; end
            S_EXM_TN: begin x4 <= md; gi <= 32'd0; st <= S_EXM_TL; end
            S_EXM_TL: if (gi == x4) begin rf[`SX(6'(sp - 7'd2))] <= VFALSE; sp <= sp - 7'd1; st <= S_FETCH; end
                      else rd(adr(t[1]) + 4 + (gi << 2), S_EXM_TI);
            S_EXM_TI: begin is_c <= mv; gosub(S_ISSUB, S_EXM_TR); end
            S_EXM_TR: if (is_r) begin rf[`SX(6'(sp - 7'd2))] <= VTRUE; sp <= sp - 7'd1; st <= S_FETCH; end
                      else begin gi <= gi + 32'd1; st <= S_EXM_TL; end

            // numeric datapath: t[0] op t[1]
            S_NUM: begin
                na_f <= (tg(t[0]) == ABI_TAG_FLOAT);
                if (tg(t[0]) == ABI_TAG_INT64) rd(adr(t[0]), S_NUM_AL);
                else begin na <= {{32{ival(t[0])[31]}}, ival(t[0])}; st <= S_NUM_B; end
            end
            S_NUM_AL: begin na[31:0] <= md; rd(adr(t[0]) + 4, S_NUM_AH); end
            S_NUM_AH: begin na[63:32] <= md; st <= S_NUM_B; end
            S_NUM_B: begin
                nb_f <= (tg(t[1]) == ABI_TAG_FLOAT);
                if (tg(t[1]) == ABI_TAG_INT64) rd(adr(t[1]), S_NUM_BL);
                else begin nb <= {{32{ival(t[1])[31]}}, ival(t[1])}; st <= S_NUM_GO; end
            end
            S_NUM_BL: begin nb[31:0] <= md; rd(adr(t[1]) + 4, S_NUM_BH); end
            S_NUM_BH: begin nb[63:32] <= md; st <= S_NUM_GO; end
            S_NUM_GO: begin
                n_small <= !na_f && !nb_f && fits31(na) && fits31(nb);
                alu_start <= 1'b1; st <= S_NUM_W;
            end
            S_NUM_W: if (alu_done) begin
                case (alu_err)
                    AE_NONE: begin
                        if (alu_kind == AK_BOOL) begin t[2] <= vbool(alu_res[0]); st <= S_NUM_PUT; end
                        else if (alu_kind == AK_FLOAT) begin t[2] <= {ABI_TAG_FLOAT, alu_res[31:0]}; st <= S_NUM_PUT; end
                        else if (fits32(alu_res)) begin t[2] <= vint(alu_res[31:0]); st <= S_NUM_PUT; end
                        else alloc(32'd2, S_NUM_BOX);
                    end
                    AE_ZERO_DIV: raise_msg(ABI_MSG_DIV_ZERO);
                    AE_OVERFLOW: raise_msg(ABI_MSG_OVERFLOW);
                    AE_NEG_SHIFT: raise_msg(ABI_MSG_NEG_SHIFT);
                    default: if (n_un) begin
                                 sp <= sp - 7'd1;
                                 hook(ABI_HOOK_UNOP, ABI_RK_PUSH, 8'd2, vint(32'(n_o)), t[0], VNULL, VNULL);
                             end else st <= S_BIN_FB;
                endcase
            end
            S_NUM_BOX: begin
                wb_v[0] <= vint(alu_res[31:0]); wb_v[1] <= vint(alu_res[63:32]);
                t[2] <= {ABI_TAG_INT64, al_a};
                wblock(al_a, 4'd2, S_NUM_PUT);
            end
            S_NUM_PUT: begin
                if (n_un) rf[`SX(6'(sp - 7'd1))] <= t[2];
                else begin rf[`SX(6'(sp - 7'd2))] <= t[2]; sp <= sp - 7'd1; end
                st <= S_FETCH;
            end

            // =================================================================
            // Natives. Args are the ARGBUF slots from ab_lo up to ab_pe; the result goes by crk.
            // ab_q is loaded with argument 0. Slot 0 (the builtin) is re-read
            // on the fallback path.
            S_NAT: begin
                if (ab_nkw != 8'd0) st <= S_NAT_FB;
                else rd(ab_ptr(ab_lo), S_NAT_A);
            end
            S_NAT_A: begin
                ab_q <= mv;
                v0 = 32'(ab_pe - ab_lo);
                v1 = mv[31:0];
                case (nid)
                    ABI_N_LEN: if (v0 != 32'd1) st <= S_NAT_FB;
                        else if (strlike(mv) || tg(mv) == ABI_TAG_BYTES) begin
                            si_v <= mv; gosub(S_SINFO, S_N_LEN_S);
                        end else if (tg(mv) == ABI_TAG_TUPLE || is_mut(mv, ABI_MUT_LIST) ||
                                     is_mut(mv, ABI_MUT_DICT) || is_mut(mv, ABI_MUT_SET))
                            rd(adr(mv), S_N_RINT);
                        else st <= S_NAT_FB;
                    ABI_N_ISINSTANCE: if (v0 != 32'd2) st <= S_NAT_FB;
                        else rd(ab_ptr(ab_lo + 8'd1), S_NAT_ISI);
                    ABI_N_ID: deliver(vint(v1), crk);
                    ABI_N_WR, ABI_N_WE: begin
                        x4 <= ABI_SIM_BASE + 4 * ((nid == ABI_N_WR) ? ABI_SIM_STDOUT : ABI_SIM_STDERR);
                        if (tg(mv) == ABI_TAG_INT)
                            wr(ABI_SIM_BASE + 4 * ((nid == ABI_N_WR) ? ABI_SIM_STDOUT : ABI_SIM_STDERR), mv, S_N_NONE);
                        else begin si_v <= mv; gosub(S_SINFO, S_N_WR); end
                    end
                    ABI_N_HALT: halt(v1 == 32'd0 ? ABI_HALT_CLEAN : ABI_HALT_SYSEXIT, v1);
                    ABI_N_TAG: deliver(vint({28'd0, tg(mv)}), crk);
                    ABI_N_PAY: deliver(vint(v1), crk);
                    ABI_N_MK: rd(ab_ptr(ab_lo + 8'd1), S_NAT_MK);
                    ABI_N_LD: rd(ab_ptr(ab_lo + 8'd1), S_NAT_LD);
                    ABI_N_ST: rd(ab_ptr(ab_lo + 8'd1), S_NAT_ST1);
                    ABI_N_PEEK8: rd(ab_ptr(ab_lo + 8'd1), S_NAT_PEEK);
                    ABI_N_POKE8: rd(ab_ptr(ab_lo + 8'd1), S_NAT_POKE1);
                    ABI_N_PEEK32: rd(v1, S_N_RINT);
                    ABI_N_ALLOC: alloc(v1, S_N_ALLOC);
                    ABI_N_TYPEOF: begin ty_v <= mv; gosub(S_TYPEOF, S_N_TYPEOF); end
                    ABI_N_CALLNS: if (tg(mv) == ABI_TAG_INT) rd(ab_ptr(ab_lo + 8'd1), S_NAT_CNS);
                        else wr(ab_ptr(8'd0), mv, S_NAT_CALL);
                    ABI_N_WCOPY: rd(ab_ptr(ab_lo + 8'd1), S_NAT_WC1);
                    ABI_N_BCOPY: rd(ab_ptr(ab_lo + 8'd2), S_NAT_BC0);
                    ABI_N_STRNEW: alloc(32'd3 + ((v1 + 32'd3) >> 2), S_N_STRNEW);
                    ABI_N_STRFIN: rd(adr(mv), S_N_SF0);
                    ABI_N_LOOKUP: rd(ab_ptr(ab_lo + 8'd1), S_NAT_LK);
                    ABI_N_TICKS: deliver(vint({2'b00, cyc[29:0]}), crk);
                    ABI_N_GC: gosub(S_GC, S_N_NONE);
                    ABI_N_GCINFO: deliver(vint((v1 == 32'd0) ? (gc_free_i << 4) : (v1 == 32'd1) ? (gc_total_i << 4) : gc_collections_i), crk);
                    ABI_N_FTOI: begin
                        t[0] <= mv; t[1] <= vint(32'd0); n_un <= 1'b1; alu_op <= ALU_F2I;
                        st <= S_N_FTOI;
                    end
                    ABI_N_INEXT: if (tg(mv) != ABI_TAG_ITER) deliver(VNULL, crk);
                        else begin t[3] <= mv; i0 <= 8'd0; st <= S_N_IN_LD; end
                    ABI_N_GRESUME: if (v0 != 32'd3) st <= S_NAT_FB;
                        else begin
                            r_rk <= crk; t[0] <= mv;
                            rd(ab_ptr(ab_lo + 8'd1), S_NAT_GR1);
                        end
                    ABI_N_BCMP: begin si_v <= mv; gosub(S_SINFO, S_N_BCMP1); end
                    ABI_N_HASH: begin hk <= mv; gosub(S_HASH, S_N_HASH); end
                    ABI_N_DATA: begin si_v <= mv; gosub(S_DADDR, S_N_DATA); end
                    ABI_N_FGET: if (fprev == 32'd0) deliver(VNULL, crk);
                        else begin x3 <= v1; rd(fprev + (v1 << 2), S_N_FGET); end
                    ABI_N_FLOC: if (fprev == 32'd0) deliver(VNULL, crk);
                        else rd(fprev + 32'd64 + (v1 << 2), S_N_RV);
                    ABI_N_QXSET: begin
                        h_qext <= mv[31:0];
                        rd(ab_ptr(ab_lo + 8'd1), S_NAT_QX);
                    end
                    ABI_N_SLEN: if (tg(mv) == ABI_TAG_MUT || tg(mv) == ABI_TAG_TUPLE) rd(adr(mv), S_N_RINT);
                        else begin si_v <= mv; gosub(S_SINFO, S_N_LEN_S); end
                    ABI_N_LIST_APPEND: if (v0 != 32'd2 || !is_mut(mv, ABI_MUT_LIST)) st <= S_NAT_FB;
                        else begin t[2] <= mv; rd(ab_ptr(ab_lo + 8'd1), S_NAT_LA); end
                    ABI_N_OBJECT_INIT: if (v0 != 32'd1) st <= S_NAT_FB; else deliver(VNONE, crk);
                    ABI_N_BASEEXCEPTION_INIT: if (v0 < 32'd1 || tg(mv) != ABI_TAG_OBJECT) st <= S_NAT_FB;
                        else begin
                            t[0] <= mv;
                            tb_src <= 1'b0; tb_nz <= 1'b0; tb_from <= ab_lo + 8'd1; tb_n <= ab_pe - ab_lo - 8'd1;
                            gosub(S_TUP, S_N_BEI);
                        end
                    ABI_N_NEW_RANGE: if (v0 < 32'd2 || v0 > 32'd4) st <= S_NAT_FB;
                        else begin x0 <= v0; rd(ab_ptr(ab_lo + 8'd1), S_NAT_RG1); end
                    ABI_N_NEW_OBJECT: if (v0 != 32'd1) st <= S_NAT_FB;
                        else begin t[0] <= mv; alloc(32'd3, S_N_OBJ); end
                    default: st <= S_NAT_FB;
                endcase
            end
            S_NAT_ISI: if (tg(mv) != ABI_TAG_OBJECT) st <= S_NAT_FB;
                       else begin ab_s[0] <= mv; rd(adr(mv), S_N_ISI); end
            S_NAT_MK: deliver({ab_q[3:0], mv[31:0]}, crk);
            S_NAT_LD: rd(padr(ab_q) + (mv[31:0] << 2), S_N_RV);
            S_NAT_ST1: begin x0 <= mv[31:0]; rd(ab_ptr(ab_lo + 8'd2), S_NAT_ST2); end
            S_NAT_ST2: wr(padr(ab_q) + (x0 << 2), mv, S_N_NONE);
            S_NAT_PEEK: begin
                v2 = padr(ab_q) + mv[31:0];
                x3 <= v2; rd({v2[31:2], 2'b00}, S_N_PEEK8);
            end
            S_NAT_POKE1: begin x0 <= mv[31:0]; rd(ab_ptr(ab_lo + 8'd2), S_NAT_POKE2); end
            S_NAT_POKE2: wrb(padr(ab_q) + x0, mv[7:0], S_N_NONE);
            S_NAT_CNS: begin
                c_ismod <= 1'b1; c_md <= ab_q[31:0]; cl_loc <= mv;
                ab_lo <= 8'd32; ab_pe <= 8'd32;
                rd(ab_q[31:0] + 4 * ABI_MD_RAW, S_CNS);
            end
            S_NAT_CALL: rd(ab_ptr(ab_lo + 8'd1), S_NAT_CALL2);
            S_NAT_CALL2: begin
                cl_loc <= mv; ab_lo <= 8'd32; ab_pe <= 8'd32; st <= S_CALL;
            end
            S_NAT_WC1: begin x1 <= mv[31:0]; rd(ab_ptr(ab_lo + 8'd2), S_NAT_WC2); end
            S_NAT_WC2: begin ab_s[0] <= mv; rd(ab_ptr(ab_lo + 8'd3), S_NAT_WC3); end
            S_NAT_WC3: begin x2 <= mv[31:0]; rd(ab_ptr(ab_lo + 8'd4), S_NAT_WC4); end
            // Latch the count before adopting SCR_LA. A store of the
            // previous image overwrites mv on the way back.
            S_NAT_WC4: begin
                x3 <= mv[31:0];
                if (cfg_ca) st <= S_NAT_WCA;
                else if (scr_id != SCR_LA) scr_adopt(SCR_LA, S_NAT_WC5);
                else st <= S_NAT_WC5;
            end
            // Ship the copy and return None. The scoreboard covers the words.
            S_NAT_WCA: if (x3 == 32'd0) deliver(VNONE, crk);
                       else if (ca_ok) begin
                           ca_ship(padr(ab_q) + (x1 << 2), padr(ab_s[0]) + (x2 << 2), x3);
                           deliver(VNONE, crk);
                       end
            S_NAT_WC5: begin
                v2 = padr(ab_q) + (x1 << 2);
                v3 = padr(ab_s[0]) + (x2 << 2);
                `la_new <= v2; `la_items <= v3; `la_len <= x3;
                b1 <= (v2 > v3);
                `la_i <= 32'd0; st <= S_N_WC;
            end
            S_NAT_BC0: begin si_v <= mv; gosub(S_DADDR, S_N_BC1); end
            S_NAT_LK: lookup(ab_q, mv, VNULL, LK_FIND, is_mut(ab_q, ABI_MUT_SET), S_N_LOOKUP);
            S_NAT_GR1: begin t[1] <= mv; rd(ab_ptr(ab_lo + 8'd2), S_NAT_GR2); end
            S_NAT_GR2: begin t[2] <= mv; st <= S_GR0; end
            S_NAT_LA: begin t[3] <= mv; gosub(S_LA, S_N_NONE); end
            S_NAT_QX: begin h_qextn <= mv[31:0]; deliver(VNONE, crk); end
            S_NAT_RG1: if (!intlike(mv)) st <= S_NAT_FB;
                       else if (x0 == 32'd2) begin
                           wb_v[0] <= vint(32'd0); wb_v[1] <= vint(ival(mv)); wb_v[2] <= vint(32'd1);
                           alloc(32'd3, S_N_RANGE);
                       end else begin
                           ab_s[0] <= mv; rd(ab_ptr(ab_lo + 8'd2), S_NAT_RG2);
                       end
            S_NAT_RG2: if (!intlike(mv)) st <= S_NAT_FB;
                       else if (x0 == 32'd3) begin
                           wb_v[0] <= vint(ival(ab_s[0])); wb_v[1] <= vint(ival(mv)); wb_v[2] <= vint(32'd1);
                           alloc(32'd3, S_N_RANGE);
                       end else begin
                           ab_s[1] <= mv; rd(ab_ptr(ab_lo + 8'd3), S_NAT_RG3);
                       end
            S_NAT_RG3: if (!intlike(mv)) st <= S_NAT_FB;
                       else if (ival(mv) == 32'd0) raise_msg(ABI_MSG_ZERO_STEP);
                       else begin
                           wb_v[0] <= vint(ival(ab_s[0])); wb_v[1] <= vint(ival(ab_s[1])); wb_v[2] <= vint(ival(mv));
                           alloc(32'd3, S_N_RANGE);
                       end
            S_NAT_FB: rd(ab_ptr(8'd0), S_NAT_FB0);
            S_NAT_FB0: begin ab_q <= mv; rd(adr(mv) + 12, S_NAT_FB1); end
            S_NAT_FB1: if (mv == VNULL) rd(adr(ab_q) + 16, S_NAT_FB2);
                       else wr(ab_ptr(8'd0), mv, S_CALL);
            S_NAT_FB2: raise_err(ABI_ERR_BUILTIN_ARGS, mv, vint(32'(ab_pe - ab_lo)));
            S_N_NONE: deliver(VNONE, crk);
            S_N_RINT: deliver(vint(md), crk);
            S_N_RV: deliver(mv, crk);
            S_N_LEN_S: if (si_na && tg(si_v) != ABI_TAG_BYTES && nid == ABI_N_LEN) st <= S_NAT_FB;
                       else deliver(vint(si_len), crk);
            S_N_ISI: if (md != ABI_OB_TYPE) st <= S_NAT_FB;
                     else begin ty_v <= ab_q; is_c <= ab_s[0]; gosub(S_TYPEOF, S_N_ISI2); end
            S_N_ISI2: begin is_t <= ty_t; gosub(S_ISSUB, S_N_ISI3); end
            S_N_ISI3: deliver(vbool(is_r), crk);
            S_N_WR: begin x2 <= si_addr; x1 <= 32'd0; st <= S_N_WRL; end
            S_N_WRL: if (x1 == si_len) deliver(VNONE, crk);
                     else rd(x2 + {x1[31:2], 2'b00}, S_N_WRB);
            S_N_WRB: begin wr(x4, vint({24'd0, byte_of(md, x1[1:0])}), S_N_WRL); x1 <= x1 + 32'd1; end
            S_N_PEEK8: deliver(vint({24'd0, byte_of(md, x3[1:0])}), crk);
            S_N_ALLOC: rd(ab_ptr(ab_lo + 8'd1), S_N_ALLOC1);
            S_N_ALLOC1: begin ab_q <= mv; rd(ab_ptr(ab_lo + 8'd2), S_N_ALLOC2); end
            S_N_ALLOC2: deliver({ab_q[3:0], al_a | mv[31:0]}, crk);
            S_N_TYPEOF: deliver(ty_t, crk);
            S_N_WC: if (`la_i == `la_len) deliver(VNONE, crk);
                    else rd(b1 ? (`la_items + ((`la_len - 32'd1 - `la_i) << 2)) : (`la_items + (`la_i << 2)), S_N_WC2);
            S_N_WC2: begin
                wr(b1 ? (`la_new + ((`la_len - 32'd1 - `la_i) << 2)) : (`la_new + (`la_i << 2)), mv, S_N_WC);
                `la_i <= `la_i + 32'd1;
            end
            S_N_BC1: if (scr_id != SCR_LA) scr_adopt(SCR_LA, S_N_BC1);
                     else rd(ab_ptr(ab_lo + 8'd3), S_N_BC1A);
            S_N_BC1A: begin
                `la_items <= si_addr + mv[31:0]; si_v <= ab_q; gosub(S_DADDR, S_N_BC2);
            end
            S_N_BC2: rd(ab_ptr(ab_lo + 8'd1), S_N_BC2A);
            S_N_BC2A: begin x0 <= mv[31:0]; rd(ab_ptr(ab_lo + 8'd4), S_N_BC2B); end
            S_N_BC2B: begin
                `la_new <= si_addr + x0;
                `la_len <= mv[31:0];
                b1 <= (si_addr + x0 > `la_items);
                `la_i <= 32'd0; st <= S_N_BC;
            end
            S_N_BC: if (`la_i == `la_len) deliver(VNONE, crk);
                    else begin
                        v2 = b1 ? (`la_items + `la_len - 32'd1 - `la_i) : (`la_items + `la_i);
                        x3 <= v2; rd({v2[31:2], 2'b00}, S_N_BC3);
                    end
            S_N_BC3: begin
                wrb(b1 ? (`la_new + `la_len - 32'd1 - `la_i) : (`la_new + `la_i), byte_of(md, x3[1:0]), S_N_BC);
                `la_i <= `la_i + 32'd1;
            end
            S_N_STRNEW: rd(ab_ptr(ab_lo), S_N_STRNEW_A);
            S_N_STRNEW_A: begin
                wb_v[0] <= vint(mv[31:0]); wb_v[1] <= vint(32'd0); wb_v[2] <= {ABI_TAG_CONT, al_a + 32'd12};
                rd(ab_ptr(ab_lo + 8'd1), S_N_STRNEW_B);
            end
            S_N_STRNEW_B: begin
                t[0] <= {mv[3:0], al_a};
                wblock(al_a, 4'd3, S_N_STRNEW2);
            end
            S_N_STRNEW2: deliver(t[0], crk);
            // _strfin(s): hash and ASCII flag over the bytes
            S_N_SF0: if (scr_id == SCR_NONE || scr_id == SCR_LA) begin
                         scr_id <= SCR_LA; `la_len <= md; rd(adr(ab_q) + 8, S_N_SF1);
                     end else wr(scr_addr(SCR_LA, 4'd0), {4'd0, md}, S_N_SF0B);
            S_N_SF0B: if (scr_id != SCR_LA) scr_ensure(SCR_LA, S_N_SF0B);
                      else rd(adr(ab_q) + 8, S_N_SF1);
            S_N_SF1: begin `la_items <= md; `la_i <= 32'd0; x2 <= 32'd5381; b1 <= 1'b0; st <= S_N_SFL; end
            S_N_SFL: if (`la_i == `la_len) begin
                         v3 = {16'd0, x2[15:0]};
                         if (v3 == 32'd0) v3 = 32'd1;
                         wr(adr(ab_q) + 4, vint(v3 | (b1 ? ABI_STR_NONASCII : 32'd0)), S_N_SF2);
                     end else rd(`la_items + {`la_i[31:2], 2'b00}, S_N_SFB);
            S_N_SFB: begin
                v3 = {24'd0, byte_of(md, `la_i[1:0])};
                x2 <= (x2 * 32'd33) ^ v3;
                if (v3[7]) b1 <= 1'b1;
                `la_i <= `la_i + 32'd1;
                st <= S_N_SFL;
            end
            S_N_SF2: deliver(ab_q, crk);
            S_N_LOOKUP: deliver(lk_cx ? VSTOP : lk_found ? lk_res : VNULL, crk);
            S_N_FTOI: begin
                na_f <= 1'b1; na <= {32'd0, t[0][31:0]}; nb_f <= 1'b0; nb <= 64'd0; n_small <= 1'b0;
                alu_start <= 1'b1; st <= S_N_FTOI_W;
            end
            S_N_FTOI_W: if (alu_done) begin
                if (alu_err != AE_NONE) deliver(VSTOP, crk);
                else if (fits32(alu_res)) deliver(vint(alu_res[31:0]), crk);
                else alloc(32'd2, S_N_FTOI_B);
            end
            S_N_FTOI_B: begin
                wb_v[0] <= vint(alu_res[31:0]); wb_v[1] <= vint(alu_res[63:32]);
                t[0] <= {ABI_TAG_INT64, al_a};
                wblock(al_a, 4'd2, S_N_STRNEW2);
            end
            S_N_IN_LD: if (i0 == 8'd0 && scr_id != SCR_NONE && scr_id != SCR_IT)
                           scr_go_store(scr_id, S_N_IN_LD);
                       else begin
                           if (scr_id != SCR_IT) scr_id <= SCR_IT;
                           if (i0 == 8'd4) begin it_h <= 1'b1; gosub(S_IT, S_N_IN_R); end
                           else rd(adr(t[3]) + 4 * i0, S_N_IN_LD2);
                       end
            S_N_IN_LD2: begin `iv[i0[1:0]] <= mv; i0 <= i0 + 8'd1; st <= S_N_IN_LD; end
            S_N_IN_R: if (it_py) deliver(VNULL, crk);
                      else wr(adr(t[3]), `iv[0], S_N_IN_W);
            S_N_IN_W: wr(adr(t[3]) + 4, `iv[1], S_N_IN_D);
            S_N_IN_D: deliver(it_stop ? VSTOP : it_val, crk);
            // SE stays resident. `la_len/`la_i alias sA[0]/sA[4], so the
            // compare index lives in SE pads sA[6]/sA[7] and is mirrored
            // into the LA image (words 0 and 4). The second operand is read
            // from ARGBUF; si_len/si_addr survive the scratch switch.
            S_N_BCMP1: if (scr_id != SCR_SE) scr_ensure(SCR_SE, S_N_BCMP1);
                       else begin
                           `se_len <= si_len; `se_pa <= si_addr;
                           rd(ab_ptr(ab_lo + 8'd1), S_N_BCMP1B);
                       end
            S_N_BCMP1B: begin si_v <= mv; gosub(S_SINFO, S_N_BCMP2); end
            S_N_BCMP2: begin
                `se_pb <= si_addr; sA[6] <= si_len; sA[7] <= 32'd0; st <= S_N_BCMP_W;
            end
            S_N_BCMP_W: wr(scr_addr(SCR_LA, 4'd0), {4'd0, sA[6]}, S_N_BCMP_W2);
            S_N_BCMP_W2: wr(scr_addr(SCR_LA, 4'd4), {4'd0, sA[7]}, S_N_BCL);
            S_N_BCL: if (sA[7] == sA[0] || sA[7] == sA[6]) begin
                         t[7] <= vint(sA[0] - sA[6]); d_rk <= crk; st <= S_N_BCF;
                     end else rd(sA[2] + {sA[7][31:2], 2'b00}, S_N_BCA);
            S_N_BCA: begin sA[5] <= md; rd(sA[3] + {sA[7][31:2], 2'b00}, S_N_BCB); end
            S_N_BCB: if (byte_of(sA[5], sA[7][1:0]) != byte_of(md, sA[7][1:0])) begin
                         t[7] <= vint({24'd0, byte_of(sA[5], sA[7][1:0])} - {24'd0, byte_of(md, sA[7][1:0])});
                         d_rk <= crk; st <= S_N_BCF;
                     end else begin sA[7] <= sA[7] + 32'd1; st <= S_N_BCI; end
            S_N_BCI: wr(scr_addr(SCR_LA, 4'd4), {4'd0, sA[7]}, S_N_BCL);
            S_N_BCF: wr(scr_addr(SCR_LA, 4'd4), {4'd0, sA[7]}, S_DELIVER);
            S_N_HASH: deliver(hok ? vint(hh) : VSTOP, crk);
            S_N_DATA: deliver(vint(si_addr), crk);
            S_N_FGET: if (x3 >= 32'd6 && x3 <= 32'd11) deliver(mv, crk);
                      else deliver(vint(md), crk);
            S_N_BEI: wr(adr(t[0]) + 8, tb_v, S_N_NONE);
            S_N_RANGE: begin
                t[0] <= {ABI_TAG_RANGE, al_a};
                wblock(al_a, 4'd3, S_N_STRNEW2);
            end
            S_N_OBJ: begin
                wb_v[0] <= vint(ABI_OB_INSTANCE); wb_v[1] <= t[0]; wb_v[2] <= VNULL;
                t[0] <= vobj(al_a);
                wblock(al_a, 4'd3, S_N_STRNEW2);
            end

            // =================================================================
            // Generators. The suspended frame is a heap block, not the reserve.
            // Resume order: finished, running, pend_throw, just-started send.
            // Word 4 is cleared only once the body actually starts.
            // FOR_ITER and the None/None YIELD_FROM case enter at S_GR0.
            // FF_YFAST marks that one yield-from parent; it spills with fflags.
            // =================================================================
            S_GSAVE: rd(adr(gen) + 20, S_GSAVE1);
            S_GSAVE1: begin
                x4 <= fbase;
                x0 <= md;
                spill_to_img <= 1'b1;
                if (lc_dirty_any) begin lc_fi <= 4'd0; lc_fl_ret <= S_GSAVE1B; st <= S_LC_FL; end
                else st <= S_GSAVE1B;
            end
            S_GSAVE1B: begin
                fbase <= x0;
                gosub(S_SPILL, S_GSAVE2);
            end
            S_GSAVE2: begin fbase <= x4; spill_to_img <= 1'b0; ret(); end

            S_GN_AL: rd(TT + 4 * ABI_T_GENERATOR, S_GN_AL2);
            S_GN_AL2: begin t[3] <= mv; alloc(32'd6, S_GN_AL3); end
            S_GN_AL3: begin
                t[0] <= vobj(al_a);
                alloc(32'd17 + 32'(nloc) + 32'd3 * {27'd0, nexc} + 32'd64, S_GN_AL4);
            end
            S_GN_AL4: begin
                wb_v[0] <= vint(ABI_OB_GENERATOR);
                wb_v[1] <= t[3];
                wb_v[2] <= fun;
                wb_v[3] <= vint(32'd0);
                wb_v[4] <= VNONE;
                wb_v[5] <= {ABI_TAG_CONT, al_a};
                gen <= t[0];
                wblock(adr(t[0]), 4'd6, S_GN_AL5);
            end
            S_GN_AL5: gosub(S_GSAVE, S_GN_AL6);
            S_GN_AL6: begin t[7] <= gen; st <= S_RET; end

            S_GN_RET: wr(adr(gen) + 12, vint(32'd0), S_GN_RET1);
            S_GN_RET1: gosub(S_GSAVE, S_GN_RET2);
            S_GN_RET2: begin fl_base <= fprev; gosub(S_FILL, S_GN_RET3); end
            S_GN_RET3: if (fflags & FF_YFAST) begin
                           // Child returned into yield from. TOS is the
                           // sub-iterator; the return value replaces it.
                           // VNONE stays VNONE. Do not build StopIteration
                           // and do not clobber fcont.
                           fflags <= fflags & ~FF_YFAST;
                           rf[`SX(6'(sp - 7'd1))] <= t[7];
                           st <= S_FETCH;
                       end else if (fcont == ABI_CONT_FOR_NEXT) begin
                           // FOR_ITER's frame is the parent, so op is the
                           // child's return opcode and building StopIteration
                           // would clobber aux (the exit pc). A bare
                           // StopIteration keeps aux; S_RX_SI ends the loop.
                           // The return value is not a for-loop item.
                           op <= 8'h4b;
                           raise_msg(ABI_MSG_STOP_ITER);
                       end else if (t[7] == VNONE) raise_msg(ABI_MSG_STOP_ITER);
                       else begin
                           ab_lo <= 8'd32; ab_pe <= 8'd33; ab_nkw <= 8'd0;
                           crk <= ABI_RK_CONT; fcont <= ABI_CONT_RAISE;
                           wr(ab_ptr(8'd0), ty_stop, S_GN_RET4);
                       end
            S_GN_RET4: wr(ab_ptr(8'd32), t[7], S_CALL);

            S_GN_ESC: wr(adr(gen) + 12, vint(32'd0), S_GN_ESC1);
            S_GN_ESC1: gosub(S_GSAVE, S_GN_ESC2);
            S_GN_ESC2: rd(adr(xc) + 4, S_GN_ESC3);
            S_GN_ESC3: begin is_t <= mv; is_c <= ty_stop; gosub(S_ISSUB, S_GN_ESC4); end
            S_GN_ESC4: begin
                b0 <= is_r;
                rx_crk <= frk;
                fl_base <= fprev;
                gosub(S_FILL, S_GN_ESC5);
            end
            S_GN_ESC5: begin
                // The parent is filled, so finally/with around yield from
                // still run. Drop the fast bit before propagating so a later
                // throw takes the firmware hook.
                fflags <= fflags & ~FF_YFAST;
                if (b0) raise_msg(ABI_MSG_GEN_STOP);
                else begin rx_from <= 1'b1; st <= S_RAISE; end
            end

            // _gresume. t0 gen, t1 send, t2 throw, r_rk deliver kind, x4 image.
            S_GR0: rd(adr(t[0]) + 20, S_GR1);
            S_GR1: begin x4 <= md; rd(md + 8, S_GR2); end
            S_GR2: if (md == 32'd0) begin
                       // Yield-from of an already-finished generator. The
                       // parent is still the live frame; the result is None.
                       if (fflags & FF_YFAST) begin
                           fflags <= fflags & ~FF_YFAST;
                           rf[`SX(6'(sp - 7'd1))] <= VNONE;
                           st <= S_FETCH;
                       end else raise_msg(ABI_MSG_STOP_ITER);
                   end else rd(adr(t[0]) + 12, S_GR3);
            S_GR3: if (md[0]) begin
                       fflags <= fflags & ~FF_YFAST;
                       raise_msg(ABI_MSG_GEN_RUNNING);
                   end else rd(adr(t[0]) + 16, S_GR4);
            S_GR4: begin
                if (mv != VNONE) t[2] <= mv;
                rd(x4 + 16, S_GR5);
            end
            S_GR5: begin x1 <= md; rd(x4 + 20, S_GR6); end
            S_GR6: begin
                // Past the caller's spilled operand stack, same as a call.
                // The stack sits at ftop; planting the frame on ftop itself
                // overwrites it when this generator later spills.
                v0 = noframe ? ABI_FRAME_BASE : (ftop + {23'd0, sp, 2'b00});
                v1 = v0 + ((32'd17 + {25'd0, x1[22:16]} + 32'd3 * {27'd0, md[20:16]}) << 2);
                if (x1[6:0] == 7'd0 && t[1] != VNONE) begin
                    fflags <= fflags & ~FF_YFAST;
                    raise_msg(ABI_MSG_GEN_SEND);
                end else if (v1 > spill_hp) begin
                    fflags <= fflags & ~FF_YFAST;
                    raise_msg(ABI_MSG_RECURSION);
                end else begin
                    x3 <= v0;
                    b1 <= (x1[6:0] != 7'd0);
                    wr(adr(t[0]) + 16, VNONE, S_GR_CLR);
                end
            end
            S_GR_CLR: wr(adr(t[0]) + 12, vint(32'd1), S_GR_RUN);
            S_GR_RUN: if (noframe) st <= S_GR_INST;
                      else gosub(S_SPILL, S_GR_INST);
            S_GR_INST: begin
                fprev <= noframe ? 32'd0 : fbase;
                fbase <= x3;
                noframe <= 1'b0;
                fl_base <= x4;
                fl_img <= 1'b1;
                gosub(S_FILL, S_GR_GO);
            end
            S_GR_GO: begin
                frk <= r_rk;
                gen <= t[0];
                if (b1) rf[`SX(6'(sp - 7'd1))] <= t[1];
                if (t[2] != VNONE) st <= S_GR_OPC;
                else begin inj <= VNONE; st <= S_FETCH; end
            end
            S_GR_OPC: rd({pc[31:2], 2'b00}, S_GR_OPB);
            S_GR_OPB: if (byte_of(md, pc[1:0]) == 8'h68) begin
                          inj <= t[2];
                          st <= S_FETCH;
                      end else begin
                          inj <= VNONE;
                          t[0] <= t[2];
                          op <= 8'h65;
                          op_pc <= pc;
                          st <= S_ROBJ;
                      end

            // YIELD_VALUE. pc already addresses the opcode after this one.
            S_YLD: begin
                t[7] <= rf[`SX(6'(sp - 7'd1))];
                rf[`SX(6'(sp - 7'd1))] <= VNONE;
                wr(adr(gen) + 12, vint(32'd0), S_YLD2);
            end
            S_YLD2: gosub(S_GSAVE, S_YLD3);
            S_YLD3: st <= S_RET;

            // _yfrom returned (True, value) or (False, value). The sub-iterator
            // is still the top of stack. A yield suspends on the YIELD_VALUE
            // path with pc put back on this opcode. The running bit stays set
            // until that suspend.
            // Word 0 of a YIELD_FROM sub-iterator whose send and inj are None.
            S_YF_K: if (md == ABI_OB_GENERATOR) begin
                    fflags <= fflags | FF_YFAST;
                    t[0] <= rf[`SX(6'(sp - 7'd2))];
                    t[1] <= VNONE; t[2] <= VNONE;
                    r_rk <= ABI_RK_CONT; fcont <= ABI_CONT_YFROM;
                    sp <= sp - 7'd1;
                    st <= S_GR0;
                end else begin
                    aux <= inj;
                    fcont <= ABI_CONT_YFROM;
                    hook(ABI_HOOK_YFROM, ABI_RK_CONT, 8'd3, rf[`SX(6'(sp - 7'd2))],
                         (inj != VNONE) ? VNONE : rf[`SX(6'(sp - 7'd1))],
                         (inj != VNONE) ? inj : VNONE, VNULL);
                    inj <= VNONE;
                    sp <= sp - 7'd1;
                end
            S_YF_F: begin b0 <= (mv == VTRUE); rd(adr(t[7]) + 8, S_YF_V); end
            S_YF_V: begin
                fcont <= 8'd0;
                if (b0) begin
                    aux <= VNONE;
                    push(mv);
                    pc <= op_pc;
                    st <= S_YLD;
                end else begin
                    rf[`SX(6'(sp - 7'd1))] <= mv;
                    if (aux != VNONE) st <= S_YF_GE;
                    else st <= S_FETCH;
                end
            end
            // Finished, and this resume injected an exception. GeneratorExit
            // that the sub-iterator swallowed is raised again.
            S_YF_GE: if (tg(aux) != ABI_TAG_OBJECT) begin aux <= VNONE; st <= S_FETCH; end
                     else rd(adr(aux), S_YF_GK);
            S_YF_GK: if (md == ABI_OB_EXCEPTION) rd(adr(aux) + 4, S_YF_GT);
                     else if (md == ABI_OB_TYPE) begin
                         is_t <= aux;
                         rd(TT + 4 * ABI_T_GENERATOREXIT, S_YF_GC);
                     end else begin aux <= VNONE; st <= S_FETCH; end
            S_YF_GT: begin is_t <= mv; rd(TT + 4 * ABI_T_GENERATOREXIT, S_YF_GC); end
            S_YF_GC: begin is_c <= mv; gosub(S_ISSUB, S_YF_GR); end
            S_YF_GR: begin
                if (is_r) begin t[0] <= aux; st <= S_ROBJ; end
                else st <= S_FETCH;
                aux <= VNONE;
            end
            // StopIteration raised by the sub-iterator's __next__/send/throw
            // completes the delegation. Its .value replaces the sub-iterator.
            // Any other exception drops the sub-iterator and propagates.
            S_YF_SI: begin is_t <= mv; is_c <= ty_stop; fcont <= 8'd0; gosub(S_ISSUB, S_YF_SI2); end
            S_YF_SI2: if (is_r) rd(adr(xc) + 8, S_YF_SV);
                      else begin sp <= sp - 7'd1; st <= S_RX_TB; end
            S_YF_SV: begin t[6] <= mv; rd(adr(mv), S_YF_SL); end
            S_YF_SL: if (md == 32'd0) begin rf[`SX(6'(sp - 7'd1))] <= VNONE; st <= S_FETCH; end
                     else rd(adr(t[6]) + 4, S_YF_SA);
            S_YF_SA: begin rf[`SX(6'(sp - 7'd1))] <= mv; st <= S_FETCH; end

            // =================================================================
            // Subroutines
            // =================================================================
            S_WB: if (wb_i == wb_n) ret();
                  else begin wr(wb_a + 4 * wb_i, wb_v[wb_i[2:0]], S_WB); wb_i <= wb_i + 4'd1; end

            // allocate al_n words -> al_a (zeroed); GC once on failure
            S_AL: begin gc_alloc_req <= 1'b1; al_gc <= 1'b0; st <= S_AL_W; end
            S_AL_W: if (gc_alloc_done_i) begin
                if (gc_alloc_ok_i) begin al_a <= gc_alloc_addr_i; al_ok <= 1'b1; ret(); end
                else if (!al_gc) begin al_gc <= 1'b1; gosub(S_GC, S_AL_RT); end
                else if (al_soft) begin al_ok <= 1'b0; al_a <= 32'd0; ret(); end
                else begin
                    al_soft <= 1'b0;
                    // A failed block alloc must drop pointers already stored in
                    // ARGBUF. The direct path (ab_chunked clear, or no block
                    // stored yet) still takes the single emergency write.
                    if (ab_chunked && (ab_nblk != 32'd0 || ab_ovf)) begin
                        t[2] <= VNULL;
                        ab_blk <= VNULL;
                        if (ab_ovf) begin
                            t[4] <= VNULL;
                            t[5] <= VNULL;
                        end
                        cv_k <= ab_ovf ? 32'd4 : 32'd5;
                        x1 <= ab_ovf ? 32'd256 : (32'd5 + ab_nblk);
                        st <= S_AL_CLR;
                    end else
                        // Word 4 of the emergency exception is its __dict__. The byte
                        // count lives in the free sysroot word just past the object.
                        wr(EMERG_ADDR + 20, vint(al_n << 2), S_AL_OOM);
                end
            end
            S_AL_RT: begin gc_alloc_req <= 1'b1; st <= S_AL_W; end
            S_AL_OOM: wr(EMERG_ADDR + 12, VNULL, S_AL_OOM2);
            S_AL_OOM2: raise_val(vobj(EMERG_ADDR));
            S_AL_CLR: if (cv_k == x1) wr(EMERG_ADDR + 20, vint(al_n << 2), S_AL_OOM);
                      else begin
                          wr(ab_ptr(cv_k[7:0]), VNULL, S_AL_CLR);
                          cv_k <= cv_k + 32'd1;
                      end

            // collect: spill every root holder, then run the collector
            S_GC: if (noframe) begin gi <= 32'd0; st <= S_GC_T; end
                  else gosub(S_SPILL, S_GC_1);
            S_GC_1: begin gi <= 32'd0; st <= S_GC_T; end
            // The argument buffer already resides in ARGBUF, which the collector scans.
            S_GC_AB: begin gi <= 32'd0; st <= S_GC_T; end
            // A copy in flight holds pointers the collector cannot see. Drain first.
            S_GC_T: if (gi == 32'd9) begin
                        if (ca_idle_i) begin gc_collect_req <= 1'b1; st <= S_GC_W; end
                    end
                    else begin
                        case (gi[3:0])
                            4'd0: wr(ABI_SYSROOT_BASE + 4 * ABI_SR_CUR_EXC, xc, S_GC_T);
                            4'd1: wr(ABI_SYSROOT_BASE + 4 * ABI_SR_T0, t[0], S_GC_T);
                            4'd2: wr(ABI_SYSROOT_BASE + 4 * ABI_SR_T1, t[1], S_GC_T);
                            4'd3: wr(ABI_SYSROOT_BASE + 4 * ABI_SR_T2, t[2], S_GC_T);
                            4'd4: wr(ABI_SYSROOT_BASE + 4 * ABI_SR_T3, t[3], S_GC_T);
                            4'd5: wr(ABI_SYSROOT_BASE + 4 * ABI_SR_T4, t[4], S_GC_T);
                            4'd6: wr(ABI_SYSROOT_BASE + 4 * ABI_SR_T5, t[5], S_GC_T);
                            4'd7: wr(ABI_SYSROOT_BASE + 4 * ABI_SR_T6, t[6], S_GC_T);
                            default: wr(ABI_SYSROOT_BASE + 4 * ABI_SR_T7, t[7], S_GC_T);
                        endcase
                        gi <= gi + 32'd1;
                    end
            S_GC_W: if (gc_collect_done_i) ret();

            // type of ty_v -> ty_t
            S_TYPEOF: begin
                case (tg(ty_v))
                    ABI_TAG_CONTROL: rd(TT + 4 * (is_bool(ty_v) ? ABI_T_BOOL : ABI_T_NONETYPE), S_TYPEOF_TT);
                    ABI_TAG_INT, ABI_TAG_INT64: rd(TT + 4 * ABI_T_INT, S_TYPEOF_TT);
                    ABI_TAG_FLOAT: rd(TT + 4 * ABI_T_FLOAT, S_TYPEOF_TT);
                    ABI_TAG_COMPLEX: rd(TT + 4 * ABI_T_COMPLEX, S_TYPEOF_TT);
                    ABI_TAG_QSTR, ABI_TAG_STR: rd(TT + 4 * ABI_T_STR, S_TYPEOF_TT);
                    ABI_TAG_BYTES: rd(TT + 4 * ABI_T_BYTES, S_TYPEOF_TT);
                    ABI_TAG_TUPLE: rd(TT + 4 * ABI_T_TUPLE, S_TYPEOF_TT);
                    ABI_TAG_RANGE: rd(TT + 4 * ABI_T_RANGE, S_TYPEOF_TT);
                    ABI_TAG_ITER: rd(TT + 4 * ABI_T_ITERATOR, S_TYPEOF_TT);
                    ABI_TAG_OBJECT: rd(adr(ty_v) + 4, S_TYPEOF_TT);
                    ABI_TAG_MUT: case (ty_v[1:0])
                        ABI_MUT_LIST: rd(TT + 4 * ABI_T_LIST, S_TYPEOF_TT);
                        ABI_MUT_DICT: rd(TT + 4 * ABI_T_DICT, S_TYPEOF_TT);
                        ABI_MUT_SET: rd(adr(ty_v) + 12, S_TYPEOF_SET);
                        default: rd(TT + 4 * ABI_T_BYTEARRAY, S_TYPEOF_TT);
                    endcase
                    default: rd(TT + 4 * ABI_T_OBJECT, S_TYPEOF_TT);
                endcase
            end
            S_TYPEOF_SET: rd(TT + 4 * ((md & ABI_SET_FLAG_FROZEN) ? ABI_T_FROZENSET : ABI_T_SET), S_TYPEOF_TT);
            S_TYPEOF_TT: begin ty_t <= mv; ret(); end

            // hash of a simple key: hk -> hh, hok
            S_HASH: begin
                hok <= 1'b1;
                case (tg(hk))
                    ABI_TAG_INT: begin hh <= sx31(hk[31:0]); ret(); end
                    ABI_TAG_CONTROL: begin
                        if (hk == VTRUE) hh <= 32'd1;
                        else if (hk == VFALSE) hh <= 32'd0;
                        else if (hk == VNONE) hh <= HASH_NONE;
                        else hok <= 1'b0;
                        ret();
                    end
                    ABI_TAG_QSTR: begin qid <= hk[31:0]; qd_nxt <= S_HASH_W16; st <= S_QD; end
                    ABI_TAG_STR, ABI_TAG_BYTES: rd(adr(hk) + 4, S_HASH_W16);
                    ABI_TAG_INT64: rd(adr(hk), S_HASH_I64);
                    ABI_TAG_OBJECT: rd(adr(hk), S_HASH_OBJ);
                    default: begin hok <= 1'b0; ret(); end
                endcase
            end
            S_HASH_W16: begin hh <= {16'd0, md[15:0]}; ret(); end
            S_HASH_I64: begin hh <= sx31(md); ret(); end
            S_HASH_OBJ: begin
                if (md == ABI_OB_INSTANCE || md == ABI_OB_EXCEPTION) hok <= 1'b0;
                else hh <= {1'b0, hk[31:1]};
                ret();
            end

            // str/qstr/bytes info: si_v -> si_len, si_hash, si_addr, si_na
            S_QD: rd((qid < h_nq) ? (h_qdesc + (qid << 3))
                               : (h_qext + ((qid - h_nq) << 3)), qd_nxt);
            S_SINFO: if (tg(si_v) == ABI_TAG_QSTR) begin
                        qid <= si_v[31:0]; qd_nxt <= S_SI_Q0; st <= S_QD;
                     end else rd(adr(si_v), S_SI_S0);
            S_SI_Q0: begin si_hash <= {16'd0, md[15:0]}; si_len <= {16'd0, md[31:16]}; rd(m_addr + 4, S_SI_Q1); end
            S_SI_Q1: begin si_addr <= {1'b0, md[30:0]}; si_na <= md[31]; ret(); end
            S_SI_S0: begin si_len <= md; rd(adr(si_v) + 4, S_SI_S1); end
            S_SI_S1: begin si_hash <= {16'd0, md[15:0]}; si_na <= md[30]; rd(adr(si_v) + 8, S_SI_S2); end
            S_SI_S2: begin si_addr <= md; ret(); end

            // data address of a str/bytes/bytearray/list: si_v -> si_addr
            S_DADDR: if (tg(si_v) == ABI_TAG_QSTR) begin gosub(S_SINFO, S_DADDR_R); end
                     else if (tg(si_v) == ABI_TAG_INT) begin si_addr <= si_v[31:0]; ret(); end
                     else rd(adr(si_v) + 8, S_DADDR_M);
            S_DADDR_M: begin si_addr <= md; ret(); end
            S_DADDR_R: ret();

            // string equality: se_a, se_b -> se_eq
            S_STREQ: if (scr_id != SCR_SE) scr_adopt(SCR_SE, S_STREQ);
                     else if (se_a == se_b) begin se_eq <= 1'b1; ret(); end
                     else begin si_v <= se_a; gosub(S_SINFO, S_SE1); end
            S_SE1: begin `se_len <= si_len; `se_hash <= si_hash; `se_pa <= si_addr; si_v <= se_b; gosub(S_SINFO, S_SE2); end
            S_SE2: if (si_len != `se_len || si_hash != `se_hash) begin se_eq <= 1'b0; ret(); end
                   else begin `se_pb <= si_addr; `se_i <= 32'd0; st <= S_SEL; end
            S_SEL: if (`se_i >= `se_len) begin se_eq <= 1'b1; ret(); end
                   else rd(`se_pa + `se_i, S_SEA);
            S_SEA: begin `se_w <= md; rd(`se_pb + `se_i, S_SEB); end
            S_SEB: begin
                v0 = `se_len - `se_i;
                v1 = (v0 >= 32'd4) ? 32'hFFFF_FFFF : ((32'd1 << (v0 << 3)) - 32'd1);
                if (((`se_w ^ md) & v1) != 32'd0) begin se_eq <= 1'b0; ret(); end
                else begin `se_i <= `se_i + 32'd4; st <= S_SEL; end
            end

            // key equality for dict probing: ke_a (slot) vs ke_b (lookup key)
            // Integer and qstr probes only use the argument flops. The KE
            // image is adopted only when the int64 path writes ke_w0/ke_w1.
            S_KEYEQ: begin
                ke_cx <= 1'b0;
                if (ke_a == ke_b) begin ke_eq <= 1'b1; ret(); end
                // Qstrs are interned, so a different id is a different key.
                else if (tg(ke_a) == ABI_TAG_QSTR && tg(ke_b) == ABI_TAG_QSTR) begin ke_eq <= 1'b0; ret(); end
                else if (strlike(ke_a) && strlike(ke_b)) begin se_a <= ke_a; se_b <= ke_b; gosub_scr(SCR_SE, S_STREQ, S_KE_S); end
                else if (tg(ke_a) == ABI_TAG_BYTES && tg(ke_b) == ABI_TAG_BYTES) begin
                    se_a <= ke_a; se_b <= ke_b; gosub_scr(SCR_SE, S_STREQ, S_KE_S);
                end else if (strlike(ke_a) || strlike(ke_b)) begin ke_eq <= 1'b0; ret(); end
                else if (intlike(ke_a) && intlike(ke_b)) begin ke_eq <= (ival(ke_a) == ival(ke_b)); ret(); end
                else if (tg(ke_a) == ABI_TAG_INT64 && tg(ke_b) == ABI_TAG_INT64) begin
                    if (scr_id != SCR_KE) scr_adopt(SCR_KE, S_KEYEQ);
                    else rd(adr(ke_a), S_KE_A0);
                end
                else if (tg(ke_a) == ABI_TAG_FLOAT || tg(ke_a) == ABI_TAG_COMPLEX) begin
                    ke_eq <= 1'b0; ke_cx <= numlike(ke_b); ret();
                end else if (tg(ke_a) == ABI_TAG_OBJECT || tg(ke_a) == ABI_TAG_TUPLE) rd(adr(ke_a), S_KE_OBJ);
                else begin ke_eq <= 1'b0; ret(); end
            end
            S_KE_S: begin ke_eq <= se_eq; ret(); end
            S_KE_A0: begin `ke_w0 <= md; rd(adr(ke_a) + 4, S_KE_A1); end
            S_KE_A1: begin `ke_w1 <= md; rd(adr(ke_b), S_KE_B0); end
            S_KE_B0: if (md != `ke_w0) begin ke_eq <= 1'b0; ret(); end
                     else rd(adr(ke_b) + 4, S_KE_B1);
            S_KE_B1: begin ke_eq <= (md == `ke_w1); ret(); end
            S_KE_OBJ: begin
                ke_eq <= 1'b0;
                ke_cx <= (tg(ke_a) == ABI_TAG_TUPLE) ? (tg(ke_b) == ABI_TAG_TUPLE)
                                                      : (md == ABI_OB_INSTANCE || md == ABI_OB_EXCEPTION);
                ret();
            end

            // dict/set probe: t4 container, t5 key, t6 value; lk_mode, lk_set
            S_LK: if (scr_id != SCR_LK) scr_adopt(SCR_LK, S_LK);
                  else begin lk_found <= 1'b0; lk_cx <= 1'b0; lk_ro <= 1'b0; lk_res <= VNULL; rd(adr(t[4]) + 12, S_LK_FL); end
            S_LK_FL: if (lk_mode != LK_FIND && (md & ABI_DICT_FLAG_ROM)) begin lk_ro <= 1'b1; ret(); end
                     else rd(adr(t[4]) + 4, S_LK_AL);
            S_LK_AL: begin `lk_alloc <= md; rd(adr(t[4]) + 8, S_LK_TB); end
            S_LK_TB: begin
                `lk_tab <= md;
                if (`lk_alloc == 32'd0) begin
                    if (lk_mode == LK_ADD) gosub_scr(SCR_RH, S_RH, S_LK_RH);
                    else ret();
                end else begin hk <= t[5]; gosub(S_HASH, S_LK_H); end
            end
            S_LK_RH: if (lk_cx) ret(); else st <= S_LK;
            S_LK_H: if (!hok) begin lk_cx <= 1'b1; ret(); end
                    else begin
                        `lk_pos <= hh % `lk_alloc; `lk_start <= hh % `lk_alloc; lk_hasav <= 1'b0;
                        st <= S_LK_P;
                    end
            S_LK_P: begin
                `lk_slot <= `lk_tab + (lk_set ? (`lk_pos << 2) : (`lk_pos << 3));
                rd(`lk_tab + (lk_set ? (`lk_pos << 2) : (`lk_pos << 3)), S_LK_K);
            end
            S_LK_K: if (mv == VNULL) begin
                        if (lk_mode == LK_ADD) begin
                            if (lk_hasav) `lk_slot <= `lk_avail;
                            st <= S_LK_INS;
                        end else ret();
                    end else if (mv == VTOMB) begin
                        if (!lk_hasav) begin lk_hasav <= 1'b1; `lk_avail <= `lk_slot; end
                        st <= S_LK_NX;
                    end else if (mv == t[5]) st <= S_LK_HIT;
                    else begin ke_a <= mv; ke_b <= t[5]; gosub(S_KEYEQ, S_LK_KE); end
            S_LK_KE: if (ke_cx) begin lk_cx <= 1'b1; ret(); end
                     else if (scr_id != SCR_LK) scr_ensure(SCR_LK, S_LK_KE);
                     else if (ke_eq) st <= S_LK_HIT;
                     else st <= S_LK_NX;
            S_LK_NX: begin
                v0 = (`lk_pos + 32'd1 == `lk_alloc) ? 32'd0 : `lk_pos + 32'd1;
                if (v0 == `lk_start) begin
                    if (lk_mode == LK_ADD) begin
                        if (lk_hasav) begin `lk_slot <= `lk_avail; st <= S_LK_INS; end
                        else gosub_scr(SCR_RH, S_RH, S_LK_RH);
                    end else ret();
                end else begin `lk_pos <= v0; st <= S_LK_P; end
            end
            S_LK_HIT: begin
                lk_found <= 1'b1;
                case (lk_mode)
                    LK_FIND: if (lk_set) begin lk_res <= t[5]; ret(); end
                             else rd(`lk_slot + 4, S_LK_V);
                    LK_ADD: if (lk_set) ret();
                            else wr(`lk_slot + 4, t[6], S_LK_RET);
                    default: if (lk_set) st <= S_LK_RM;
                             else rd(`lk_slot + 4, S_LK_RV);
                endcase
            end
            S_LK_V: begin lk_res <= mv; ret(); end
            S_LK_RET: ret();
            S_LK_RV: begin lk_res <= mv; st <= S_LK_RM; end
            S_LK_RM: begin
                v0 = (`lk_pos + 32'd1 == `lk_alloc) ? 32'd0 : `lk_pos + 32'd1;
                rd(`lk_tab + (lk_set ? (v0 << 2) : (v0 << 3)), S_LK_RM2);
            end
            S_LK_RM2: begin
                wr(`lk_slot, (mv == VNULL) ? VNULL : VTOMB, S_LK_RM3);
            end
            S_LK_RM3: if (lk_set) rd(adr(t[4]), S_LK_DEC);
                      else wr(`lk_slot + 4, VNULL, S_LK_RM4);
            S_LK_RM4: rd(adr(t[4]), S_LK_DEC);
            S_LK_DEC: wr(adr(t[4]), vint(md - 32'd1), S_LK_RET);
            S_LK_INS: wr(`lk_slot, t[5], lk_set ? S_LK_INS3 : S_LK_INS2);
            S_LK_INS2: wr(`lk_slot + 4, t[6], S_LK_INS3);
            S_LK_INS3: rd(adr(t[4]), S_LK_INC);
            S_LK_INC: wr(adr(t[4]), vint(md + 32'd1), S_LK_RET);

            // Grow t4. The caller's LK image is in SRAM. Pads sA[5]/sA[6] hold
            // the re-read alloc and table for the copy loop. The new sizes are
            // written back to LK words 0 and 1 before returning.
            S_RH: if (scr_id != SCR_RH) scr_adopt(SCR_RH, S_RH);
                  else st <= S_RH_LKA;
            S_RH_LKA: rd(scr_addr(SCR_LK, 4'd0), S_RH_LKB);
            S_RH_LKB: begin
                `rh_alloc <= next_alloc(md + 32'd1);
                alloc(next_alloc(md + 32'd1) << (lk_set ? 0 : 1), S_RH_A);
            end
            S_RH_A: begin `rh_tab <= al_a; `rh_i <= 32'd0; `rh_used <= 32'd0; rd(adr(t[4]) + 4, S_RH_A2); end
            S_RH_A2: begin sA[5] <= md; rd(adr(t[4]) + 8, S_RH_A3); end
            S_RH_A3: begin sA[6] <= md; st <= S_RH_L; end
            S_RH_L: if (`rh_i == sA[5]) wr(adr(t[4]) + 4, vint(`rh_alloc), S_RH_F1);
                    else rd(sA[6] + (lk_set ? (`rh_i << 2) : (`rh_i << 3)), S_RH_K);
            S_RH_K: if (mv == VNULL || mv == VTOMB) begin `rh_i <= `rh_i + 32'd1; st <= S_RH_L; end
                    else begin `rh_k <= mv; hk <= mv; gosub(S_HASH, S_RH_H); end
            S_RH_H: if (!hok) begin lk_cx <= 1'b1; ret(); end
                    else begin `rh_p <= hh % `rh_alloc; st <= S_RH_P; end
            S_RH_P: rd(`rh_tab + (lk_set ? (`rh_p << 2) : (`rh_p << 3)), S_RH_PK);
            S_RH_PK: if (mv != VNULL) begin
                         `rh_p <= (`rh_p + 32'd1 == `rh_alloc) ? 32'd0 : `rh_p + 32'd1; st <= S_RH_P;
                     end else wr(`rh_tab + (lk_set ? (`rh_p << 2) : (`rh_p << 3)), `rh_k, lk_set ? S_RH_NX : S_RH_V);
            S_RH_V: rd(sA[6] + (`rh_i << 3) + 4, S_RH_V2);
            S_RH_V2: wr(`rh_tab + (`rh_p << 3) + 4, mv, S_RH_NX);
            S_RH_NX: begin `rh_used <= `rh_used + 32'd1; `rh_i <= `rh_i + 32'd1; st <= S_RH_L; end
            S_RH_F1: wr(adr(t[4]) + 8, {ABI_TAG_CONT, `rh_tab}, S_RH_F2);
            S_RH_F2: wr(adr(t[4]), vint(`rh_used), S_RH_F3);
            S_RH_F3: wr(scr_addr(SCR_LK, 4'd0), {4'd0, `rh_alloc}, S_RH_F3B);
            S_RH_F3B: wr(scr_addr(SCR_LK, 4'd1), {4'd0, `rh_tab}, S_LK_RET);

            // list append: t2 list, t3 value
            S_LA: if (scr_id != SCR_LA) scr_adopt(SCR_LA, S_LA);
                  else rd(adr(t[2]), S_LA_N);
            S_LA_N: begin `la_len <= md; rd(adr(t[2]) + 4, S_LA_A); end
            S_LA_A: begin `la_alloc <= md; rd(adr(t[2]) + 8, S_LA_I); end
            S_LA_I: begin
                `la_items <= md;
                if (`la_len < `la_alloc) wr(md + (`la_len << 2), t[3], S_LA_INC);
                else alloc((`la_alloc == 32'd0) ? 32'd4 : (`la_alloc << 1), S_LA_G);
            end
            S_LA_G: if (!al_ok) ret();
                    else begin `la_new <= al_a; `la_i <= 32'd0; rd(adr(t[2]) + 8, S_LA_G2); end
            S_LA_G2: begin
                `la_items <= md;
                st <= (cfg_ca && `la_len != 32'd0) ? S_LA_CA : S_LA_CP;
            end
            // The accelerator copies the old items. The core publishes the new
            // array and stores the appended item above the copied words.
            S_LA_CA: if (ca_ok) begin
                         ca_ship(`la_new, `la_items, `la_len);
                         `la_i <= `la_len; st <= S_LA_CP;
                     end
            S_LA_CP: if (`la_i == `la_len) wr(adr(t[2]) + 4, vint((`la_alloc == 32'd0) ? 32'd4 : (`la_alloc << 1)), S_LA_G3);
                     else rd(`la_items + (`la_i << 2), S_LA_CP2);
            S_LA_CP2: begin wr(`la_new + (`la_i << 2), mv, S_LA_CP); `la_i <= `la_i + 32'd1; end
            S_LA_G3: wr(adr(t[2]) + 8, {ABI_TAG_CONT, `la_new}, S_LA_G4);
            S_LA_G4: wr(`la_new + (`la_len << 2), t[3], S_LA_INC);
            S_LA_INC: wr(adr(t[2]), vint(`la_len + 32'd1), S_LA_RET);
            S_LA_RET: ret();

            // tuple from ARGBUF (tb_src=0) or rf (tb_src=1)
            S_TUP: if (tb_n == 8'd0) begin tb_v <= {ABI_TAG_TUPLE, h_empty}; ret(); end
                   else alloc(32'd1 + tb_n, S_TUP_A);
            S_TUP_A: begin tb_a <= al_a; tb_i <= 8'd0; wr(al_a, vint(32'(tb_n)), S_TUP_L); end
            S_TUP_L: if (tb_i == tb_n) begin tb_v <= {ABI_TAG_TUPLE, tb_a}; ret(); end
                     else if (!tb_src) rd(ab_ptr(8'(tb_from + tb_i)), S_TUP_AB);
                     else begin
                         v0 = {16'd0, stk_from} + 32'(tb_i);
                         if (stk_hit(v0[15:0])) begin
                             wr(tb_a + 4 + 4 * tb_i, stk_val(v0[15:0]), S_TUP_L);
                             tb_i <= tb_i + 8'd1;
                         end else begin
                             srd_g <= v0[15:0];
                             gosub(S_SRD, S_TUP_W);
                         end
                     end
            S_TUP_AB: begin
                if (tb_nz && mv == VNULL) wr(tb_a + 4 + 4 * tb_i, vint(32'd0), S_TUP_L);
                else wr(tb_a + 4 + 4 * tb_i, mv, S_TUP_L);
                tb_i <= tb_i + 8'd1;
            end
            S_TUP_W: begin wr(tb_a + 4 + 4 * tb_i, srd_v, S_TUP_L); tb_i <= tb_i + 8'd1; end

            // is_t a subclass of is_c?
            S_ISSUB: if (is_c == ty_obj || is_c == is_t) begin is_r <= 1'b1; ret(); end
                     else rd(adr(is_t) + 20, S_IS_M);
            S_IS_M: begin is_m <= adr(mv); rd(adr(mv), S_IS_N); end
            S_IS_N: begin is_n <= md; is_i <= 32'd0; st <= S_IS_L; end
            S_IS_L: if (is_i == is_n) begin is_r <= 1'b0; ret(); end
                    else rd(is_m + 4 + (is_i << 2), S_IS_C);
            S_IS_C: if (mv == is_c) begin is_r <= 1'b1; ret(); end
                    else begin is_i <= is_i + 32'd1; st <= S_IS_L; end

            // truth of tr_v -> tr_r, or tr_x when it needs __bool__/__len__
            S_TR: begin
                tr_x <= 1'b0;
                if (ovr == ABI_OVR_TRUE || ovr == ABI_OVR_FALSE) begin
                    tr_r <= (ovr == ABI_OVR_TRUE); ovr <= ABI_OVR_NONE; ret();
                end else case (tg(tr_v))
                    ABI_TAG_CONTROL: begin tr_r <= (tr_v == VTRUE); ret(); end
                    ABI_TAG_INT: begin tr_r <= (tr_v[31:0] != 32'd0); ret(); end
                    ABI_TAG_FLOAT: begin tr_r <= (tr_v[30:0] != 31'd0); ret(); end
                    ABI_TAG_INT64, ABI_TAG_ITER: begin tr_r <= 1'b1; ret(); end
                    ABI_TAG_QSTR: begin tr_r <= (tr_v[31:0] != ABI_Q_EMPTY); ret(); end
                    ABI_TAG_STR, ABI_TAG_BYTES, ABI_TAG_TUPLE, ABI_TAG_MUT: rd(adr(tr_v), S_TR_LEN);
                    ABI_TAG_OBJECT: rd(adr(tr_v) + 4, S_TR_T);
                    default: begin tr_x <= 1'b1; ret(); end
                endcase
            end
            S_TR_LEN: begin tr_r <= (md != 32'd0); ret(); end
            S_TR_T: rd(adr(mv) + 28, S_TR_F);
            S_TR_F: begin
                if (md & ABI_TF_TRUTH) tr_x <= 1'b1;
                else tr_r <= 1'b1;
                ret();
            end

            // attribute lookup: t0 object, at_q name -> at_kind (0 miss, 1 value, 2 method, 3 descriptor), at_v
            S_AT: if (scr_id != SCR_AT) scr_adopt(SCR_AT, S_AT);
                  else begin
                at_ty <= 1'b0; at_objd <= 1'b0;
                if (tg(t[0]) == ABI_TAG_OBJECT) rd(adr(t[0]), S_AT_K);
                else begin ty_v <= t[0]; gosub(S_TYPEOF, S_AT_NT); end
            end
            S_AT_K: if (md == ABI_OB_INSTANCE) rd(adr(t[0]) + 8, S_AT_ID);
                    else if (md == ABI_OB_EXCEPTION) rd(adr(t[0]) + 16, S_AT_ID);
                    else if (md == ABI_OB_TYPE) begin `at_t <= t[0]; at_ty <= 1'b1; st <= S_AT_MRO; end
                    else if (md == ABI_OB_MODULE) rd(adr(t[0]) + 8, S_AT_MOD);
                    else rd(adr(t[0]) + 4, S_AT_T1);
            S_AT_ID: if (mv == VNULL) rd(adr(t[0]) + 4, S_AT_T1);
                     else lookup(mv, {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, S_AT_IDR);
            S_AT_IDR: if (lk_found) begin at_kind <= 2'd1; at_v <= lk_res; ret(); end
                      else if (scr_id != SCR_AT) scr_ensure(SCR_AT, S_AT_IDR);
                      else rd(adr(t[0]) + 4, S_AT_T1);
            S_AT_MOD: lookup(mv, {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, S_AT_MODR);
            S_AT_MODR: begin at_kind <= lk_found ? 2'd1 : 2'd0; at_v <= lk_res; ret(); end
            S_AT_T1: begin `at_t <= mv; st <= S_AT_MRO; end
            S_AT_NT: begin `at_t <= ty_t; st <= S_AT_MRO; end
            S_AT_MRO: rd(adr(`at_t) + 20, S_AT_M1);
            S_AT_M1: begin `at_m <= adr(mv); rd(adr(mv), S_AT_M2); end
            S_AT_M2: begin `at_n <= md; `at_i <= 32'd0; st <= S_AT_ML; end
            S_AT_ML: if (`at_i == `at_n) begin
                         if (!at_objd) begin at_objd <= 1'b1; rd(adr(ty_obj) + 8, S_AT_MD2); end
                         else begin at_kind <= 2'd0; ret(); end
                     end else rd(`at_m + 4 + (`at_i << 2), S_AT_MT);
            S_AT_MT: rd(adr(mv) + 8, S_AT_MD2);
            S_AT_MD2: lookup(mv, {ABI_TAG_QSTR, at_q}, VNULL, LK_FIND, 1'b0, S_AT_MR);
            S_AT_MR: if (scr_id != SCR_AT) scr_ensure(SCR_AT, S_AT_MR);
                     else if (!lk_found) begin
                         if (at_objd) begin at_kind <= 2'd0; ret(); end
                         else begin `at_i <= `at_i + 32'd1; st <= S_AT_ML; end
                     end else begin
                         at_v <= lk_res;
                         if (tg(lk_res) == ABI_TAG_OBJECT) rd(adr(lk_res), S_AT_VK);
                         else begin at_kind <= 2'd1; ret(); end
                     end
            S_AT_VK: begin
                if (md == ABI_OB_FUNCTION || md == ABI_OB_BUILTIN) at_kind <= at_ty ? 2'd1 : 2'd2;
                else if (md == ABI_OB_STATICMETHOD || md == ABI_OB_CLASSMETHOD || md == ABI_OB_PROPERTY) at_kind <= 2'd3;
                // Any other object found on a class may be a data descriptor.
                // _getattr returns it unchanged when it has no __get__.
                else at_kind <= 2'd3;
                ret();
            end

            // one step of an iterator in `iv[0..3] -> it_val / it_stop, or it_py
            S_IT: if (scr_id != SCR_IT) scr_ensure(SCR_IT, S_IT);
                  else begin
                it_stop <= 1'b0; it_py <= 1'b0; `it_i <= `iv[1][31:0];
                case (`iv[3][31:0])
                    ABI_IT_RANGE: begin
                        if (`iv[2][31] ? ($signed(`iv[0][31:0]) <= $signed(`iv[1][31:0]))
                                      : ($signed(`iv[0][31:0]) >= $signed(`iv[1][31:0]))) it_stop <= 1'b1;
                        else begin it_val <= `iv[0]; `iv[0] <= vint(`iv[0][31:0] + `iv[2][31:0]); end
                        ret();
                    end
                    ABI_IT_SEQ: if (tg(`iv[0]) == ABI_TAG_TUPLE || is_mut(`iv[0], ABI_MUT_LIST)) rd(adr(`iv[0]), S_IT_SL);
                                else begin si_v <= `iv[0]; gosub(S_SINFO, S_IT_BL); end
                    ABI_IT_DICT, ABI_IT_SET: rd(adr(`iv[0]) + 4, S_IT_DA);
                    ABI_IT_STR: begin si_v <= `iv[0]; gosub(S_SINFO, S_IT_BL); end
                    ABI_IT_PYOBJ: begin it_py <= 1'b1; ret(); end
                    default: begin it_stop <= 1'b1; ret(); end
                endcase
            end
            S_IT_SL: if (`it_i >= md) begin it_stop <= 1'b1; ret(); end
                     else if (tg(`iv[0]) == ABI_TAG_TUPLE) rd(adr(`iv[0]) + 4 + (`it_i << 2), S_IT_V);
                     else rd(adr(`iv[0]) + 8, S_IT_LI);
            S_IT_LI: rd(md + (`it_i << 2), S_IT_V);
            S_IT_V: begin it_val <= mv; `iv[1] <= vint(`it_i + 32'd1); ret(); end
            S_IT_BL: if (`it_i >= si_len) begin it_stop <= 1'b1; ret(); end
                     else rd(si_addr + {`it_i[31:2], 2'b00}, S_IT_BB);
            S_IT_BB: if (tg(`iv[0]) == ABI_TAG_BYTES || is_mut(`iv[0], ABI_MUT_BYTEARRAY)) begin
                         it_val <= vint({24'd0, byte_of(md, `it_i[1:0])}); `iv[1] <= vint(`it_i + 32'd1); ret();
                     end else rd(h_chars + 4 * byte_of(md, `it_i[1:0]), S_IT_SC);
            S_IT_SC: begin it_val <= {ABI_TAG_QSTR, md}; `iv[1] <= vint(`it_i + 32'd1); ret(); end
            S_IT_DA: begin `it_alloc <= md; rd(adr(`iv[0]) + 8, S_IT_DT); end
            S_IT_DT: begin `it_tab <= md; st <= S_IT_DL; end
            S_IT_DL: if (`it_i >= `it_alloc) begin it_stop <= 1'b1; `iv[1] <= vint(`it_i); ret(); end
                     else rd(`it_tab + ((`iv[3][31:0] == ABI_IT_SET) ? (`it_i << 2) : (`it_i << 3)), S_IT_DK);
            S_IT_DK: if (mv == VNULL || mv == VTOMB) begin `it_i <= `it_i + 32'd1; st <= S_IT_DL; end
                     else if (`iv[3][31:0] == ABI_IT_SET || `iv[2][31:0] == 32'd0) begin
                         it_val <= mv; `iv[1] <= vint(`it_i + 32'd1); ret();
                     end else if (`iv[2][31:0] == 32'd1) rd(m_addr + 4, S_IT_V);
                     else begin t[2] <= mv; rd(m_addr + 4, S_IT_DV); end
            S_IT_DV: begin t[1] <= mv; alloc(32'd3, S_IT_DI); end
            S_IT_DI: begin
                wb_v[0] <= vint(32'd2); wb_v[1] <= t[2]; wb_v[2] <= t[1];
                it_val <= {ABI_TAG_TUPLE, al_a}; `iv[1] <= vint(`it_i + 32'd1);
                wblock(al_a, 4'd3, S_LA_RET);
            end

            // ---- register-stack spill / reload / chain walk ----
            // Word 0 packs the previous address and the value count. Tag
            // words follow, then payloads, oldest first. A growth spill
            // copies cfg_grow values (clamped so the ring stays above the
            // eager-reload line). After a pop, the chunk is MPY_RF_CHUNK_MIN.
            // A spill that already has a link moves that link into the header
            // and frees `n` registers. The first spill frees `n - 1`.
            S_RF_SPILL: begin
                v0 = (cfg_adapt && !rf_mono) ? 32'(MPY_RF_CHUNK_MIN) : 32'(cfg_grow);
                if (v0 < 32'(MPY_RF_CHUNK_MIN)) v0 = 32'(MPY_RF_CHUNK_MIN);
                if (v0 > 32'(MPY_RF_CHUNK_MAX)) v0 = 32'(MPY_RF_CHUNK_MAX);
                // Leave sp >= RF_LEAVE_SP so the next fetch does not reload.
                // No link: sp_new = sp - n + 1, so n <= sp - 4.
                // Link in slot 0: sp_new = sp - n, so n <= sp - 5.
                v1 = has_link ? ((sp > 7'(RF_LEAVE_SP)) ? 32'(sp - 7'(RF_LEAVE_SP)) : 32'd0)
                              : ((sp > 7'(RF_LEAVE_SP - 1)) ? 32'(sp - 7'(RF_LEAVE_SP - 1)) : 32'd0);
                if (v0 > v1) v0 = v1;
                v2 = mpy_rf_block_bytes(v0[5:0]);
                if (v0 < 32'(MPY_RF_CHUNK_MIN)) st <= rf_resume;
                else if (spill_hp < ftop + v2) raise_msg(ABI_MSG_RECURSION);
                else begin
                    spill_n <= v0[5:0];
                    spill_ntag <= 6'((v0[5:0] + 6'd7) >> 3);
                    spill_words <= 32'd1 + 32'((v0[5:0] + 6'd7) >> 3) + v0;
                    spill_addr <= spill_hp - v2;
                    spill_had_link <= has_link;
                    spill_prev <= has_link ? mpy_rf_link_addr(rf[`SX(7'd0)]) : 32'd0;
                    sw_i <= 32'd0;
                    st <= S_RF_SPILL_W;
                end
            end
            S_RF_SPILL_W: if (sw_i == spill_words) begin
                if (spill_had_link) begin
                    rf[`SX(spill_n)] <= mpy_make_rf_link(spill_addr);
                    rf_base <= 6'(4'(rf_base + spill_n));
                    sp <= sp - {1'b0, spill_n};
                end else begin
                    rf[`SX(spill_n - 6'd1)] <= mpy_make_rf_link(spill_addr);
                    rf_base <= 6'(4'(rf_base + spill_n - 6'd1));
                    sp <= (sp - {1'b0, spill_n}) + 7'd1;
                end
                spill_hp <= spill_addr;
                spilled_reals <= spilled_reals + {10'd0, spill_n};
                sp_hold <= 1'b1;
                st <= rf_resume;
            end else if (sw_i == 32'd0) begin
                wr(spill_addr, mpy_rf_chunk_hdr(spill_prev, spill_n), S_RF_SPILL_W);
                sw_i <= 32'd1;
            end else if (sw_i <= 32'(spill_ntag)) begin
                v3 = 32'd0;
                for (int k = 0; k < 8; k++) begin
                    vs0 = 7'((sw_i[5:0] - 6'd1) << 3) + 7'(k);
                    if (vs0 < {1'b0, spill_n})
                        v3[4*k +: 4] = rf[`SX(spill_had_link ? (vs0 + 7'd1) : vs0)][35:32];
                end
                wr(spill_addr + (sw_i << 2), {4'd0, v3}, S_RF_SPILL_W);
                sw_i <= sw_i + 32'd1;
            end else begin
                vs0 = spill_had_link ? (sw_i[6:0] - {1'b0, spill_ntag})
                                     : (sw_i[6:0] - 7'd1 - {1'b0, spill_ntag});
                wr(spill_addr + (sw_i << 2), rf[`SX(vs0)], S_RF_SPILL_W);
                sw_i <= sw_i + 32'd1;
            end

            S_RF_RELOAD: begin
                if (!has_link) st <= rf_resume;
                else begin
                    spill_addr <= mpy_rf_link_addr(rf[`SX(7'd0)]);
                    sw_i <= 32'd0;
                    st <= S_RF_RELOAD_R;
                end
            end
            S_RF_RELOAD_R: if (sw_i != 32'd0 && sw_i == spill_words) begin
                // Payloads were written as they arrived. This step only
                // installs the restored link and moves the ring window.
                spilled_reals <= (spilled_reals >= {10'd0, spill_n}) ? (spilled_reals - {10'd0, spill_n}) : 16'd0;
                if (spill_prev != 32'd0) begin
                    rf[4'(rf_base - spill_n)] <= mpy_make_rf_link(spill_prev);
                    rf_base <= 6'(4'(rf_base - spill_n));
                    sp <= sp + {1'b0, spill_n};
                end else begin
                    rf_base <= 6'(4'(rf_base - (spill_n - 6'd1)));
                    sp <= (sp + {1'b0, spill_n}) - 7'd1;
                end
                rf_reload_miss <= 1'b0;
                sp_hold <= 1'b1;
                st <= rf_resume;
            end else rd(spill_addr + (sw_i << 2), S_RF_RELOAD_G);
            S_RF_RELOAD_G: begin
                if (sw_i == 32'd0) begin
                    v0 = 32'(mpy_rf_chunk_count(mt, md));
                    v1 = mpy_rf_chunk_prev(md);
                    // With a previous link the reload occupies `count` slots.
                    // The oldest chunk occupies `count - 1` (no link to restore).
                    v2 = 32'(sp) + ((v1 != 32'd0) ? v0 : (v0 - 32'd1));
                    spill_n <= v0[5:0];
                    spill_prev <= v1;
                    spill_ntag <= 6'((v0[5:0] + 6'd7) >> 3);
                    spill_words <= 32'd1 + 32'((v0[5:0] + 6'd7) >> 3) + v0;
                    if (v0 < 32'(MPY_RF_CHUNK_MIN) || v0 > 32'(MPY_RF_CHUNK_MAX) || v2 > 32'(MPY_RF_DEPTH)) begin
                        if (rf_resume == S_EXEC) begin
                            rf_reload_miss <= 1'b1;
                            st <= S_EXEC;
                        end else halt(ABI_HALT_INTERNAL, 32'h0000_5F01);
                    end else begin
                        // Payloads carry their tags in the side array. Skip the tag words.
                        sw_i <= 32'd1 + 32'((v0[5:0] + 6'd7) >> 3);
                        st <= S_RF_RELOAD_R;
                    end
                end else begin
                    v0 = sw_i - 32'd1 - 32'(spill_ntag);
                    rf[4'(rf_base - spill_n + v0 + 32'd1)] <= mv;
                    sw_i <= sw_i + 32'd1;
                    st <= S_RF_RELOAD_R;
                end
            end

            S_SRD: if (stk_hit(srd_g)) begin
                srd_v <= stk_val(srd_g);
                ret();
            end else if (!has_link) begin
                srd_v <= VNULL;
                ret();
            end else begin
                srd_addr <= mpy_rf_link_addr(rf[`SX(7'd0)]);
                srd_off <= spilled_reals - 16'd1 - srd_g;
                srd_hops <= 8'd0;
                st <= S_SRD_T0;
            end
            S_SRD_T0: rd(srd_addr, S_SRD_T1);
            S_SRD_T1: begin
                v0 = 32'(mpy_rf_chunk_count(mt, md));
                v1 = mpy_rf_chunk_prev(md);
                if (v0 != 32'd0 && srd_off < v0[15:0])
                    rd(srd_addr + 32'd4 + (32'((v0[5:0] + 6'd7) >> 3) << 2)
                       + ((v0 - 32'd1 - 32'(srd_off)) << 2), S_SRD_GOT);
                else if (v1 == 32'd0 || srd_hops == 8'd64) begin
                    srd_v <= VNULL;
                    ret();
                end else begin
                    srd_off <= srd_off - v0[15:0];
                    srd_addr <= v1;
                    srd_hops <= srd_hops + 8'd1;
                    st <= S_SRD_T0;
                end
            end
            S_SRD_GOT: begin srd_v <= mv; ret(); end

            // Call window wider than the ring. x0 is the callable's global
            // index, x2 the first argument word, x1 how many argument words,
            // x3 the slots to drop (callable, optional self, arguments),
            // x4 the positional count. b0 means CALL_METHOD.
            // Resident call window: one ARGBUF store per cycle. x1 is v0+2*v1.
            S_CALL_CP: if (b1) wr(ab_ptr(8'd31), rf[`SX(6'(s1 + 7'd1))], S_CALL_CP2);
                       else st <= S_CALL_CP2;
            S_CALL_CP2: if (32'(i0) == x1) st <= S_CALL;
                        else begin
                            wr(ab_ptr(8'd32 + i0), rf[`SX(6'(s0 + 7'(i0)))], S_CALL_CP2);
                            i0 <= i0 + 8'd1;
                        end
            S_CC_FUN: if (stk_hit(x0[15:0])) begin
                    wr(ab_ptr(8'd0), stk_val(x0[15:0]), S_CC_SELF);
                end else begin
                    srd_g <= x0[15:0];
                    gosub(S_SRD, S_CC_FUN2);
                end
            S_CC_FUN2: wr(ab_ptr(8'd0), srd_v, S_CC_SELF);
            S_CC_SELF: if (!b0) begin
                    ab_lo <= 8'd32; st <= S_CC_ARG;
                end else if (stk_hit(x0[15:0] + 16'd1)) begin
                    if (stk_val(x0[15:0] + 16'd1) != VNULL) begin
                        wr(ab_ptr(8'd31), stk_val(x0[15:0] + 16'd1), S_CC_ARG);
                        ab_lo <= 8'd31;
                    end else begin ab_lo <= 8'd32; st <= S_CC_ARG; end
                end else begin
                    srd_g <= x0[15:0] + 16'd1;
                    gosub(S_SRD, S_CC_SELF2);
                end
            S_CC_SELF2: begin
                    if (srd_v != VNULL) begin
                        wr(ab_ptr(8'd31), srd_v, S_CC_ARG);
                        ab_lo <= 8'd31;
                    end else begin ab_lo <= 8'd32; st <= S_CC_ARG; end
                end
            S_CC_ARG: if (gi == x1) st <= S_CC_DONE;
                else if (stk_hit(x2[15:0] + gi[15:0])) begin
                    wr(ab_ptr(8'(32 + gi)), stk_val(x2[15:0] + gi[15:0]), S_CC_ARG);
                    gi <= gi + 32'd1;
                end else begin
                    srd_g <= x2[15:0] + gi[15:0];
                    gosub(S_SRD, S_CC_ARG2);
                end
            S_CC_ARG2: begin
                    wr(ab_ptr(8'(32 + gi)), srd_v, S_CC_ARG);
                    gi <= gi + 32'd1;
                end
            S_CC_DONE: begin
                    ab_pe <= 8'(32 + x4);
                    crk <= ABI_RK_PUSH;
                    drop_left <= x3[15:0];
                    drop_push_en <= 1'b0;
                    drop_then <= S_CALL;
                    st <= S_DROP;
                end

            S_DROP: if (drop_left == 16'd0) begin
                if (drop_push_en) begin
                    if (sp >= 7'(MPY_RF_DEPTH)) begin
                        rf_pend <= 1'b1;
                        rf_pend_v <= drop_push_v;
                        rf_resume <= drop_then;
                        st <= S_RF_SPILL;
                    end else begin
                        rf[`SX(sp)] <= drop_push_v;
                        sp <= sp + 7'd1;
                        st <= drop_then;
                    end
                end else st <= drop_then;
            end else if (has_link && sp <= 7'd1) begin
                rf_resume <= S_DROP;
                st <= S_RF_RELOAD;
            end else if (sp == 7'd0) begin
                drop_left <= 16'd0;
            end else begin
                sp <= sp - 7'd1;
                drop_left <= drop_left - 16'd1;
            end

            S_UR_SLOW: if (stk_depth <= ur_target) begin
                if (sp >= 7'(MPY_RF_DEPTH - 2)) begin
                    rf_resume <= S_UR_SLOW;
                    st <= S_RF_SPILL;
                end else begin
                    rf[`SX(sp)] <= ur_val;
                    rf[`SX(sp + 7'd1)] <= vint(32'hFFFF_FFFF);
                    sp <= sp + 7'd2;
                    st <= S_FETCH;
                end
            end else if (has_link && sp <= 7'd1) begin
                rf_resume <= S_UR_SLOW;
                st <= S_RF_RELOAD;
            end else if (sp != 7'd0) begin
                sp <= sp - 7'd1;
            end else st <= S_FETCH;

            default: halt(ABI_HALT_INTERNAL, 32'hDEAD_0000 | 32'(st));
            endcase
        end
    end
endmodule
`undef lk_alloc
`undef lk_tab
`undef lk_pos
`undef lk_start
`undef lk_avail
`undef lk_slot
`undef rh_alloc
`undef rh_tab
`undef rh_i
`undef rh_p
`undef rh_used
`undef rh_k
`undef se_len
`undef se_hash
`undef se_pa
`undef se_pb
`undef se_i
`undef se_w
`undef at_m
`undef at_n
`undef at_i
`undef at_k
`undef at_t
`undef iv
`undef it_i
`undef it_alloc
`undef it_tab
`undef la_len
`undef la_alloc
`undef la_items
`undef la_new
`undef la_i
`undef ke_w0
`undef ke_w1
/* verilator lint_on BLKSEQ */
/* verilator lint_on CASEINCOMPLETE */
/* verilator lint_on UNUSEDPARAM */
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on WIDTH */