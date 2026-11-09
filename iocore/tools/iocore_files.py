"""File lists for the I/O island (CVE2 or Hazard3 core), shared by the
simulator builds, the unit benches and the synthesis/timing flows."""

from __future__ import annotations

CVE2_PRIM = "vendor/cve2/vendor/lowrisc_ip/ip/prim/rtl"
CVE2_RTL = (
    [f"{CVE2_PRIM}/prim_ram_1p_pkg.sv"]
    + [f"vendor/cve2/rtl/{n}.sv" for n in (
        "cve2_pkg", "cve2_alu", "cve2_compressed_decoder", "cve2_controller", "cve2_cs_registers",
        "cve2_csr", "cve2_counter", "cve2_decoder", "cve2_ex_block", "cve2_fetch_fifo",
        "cve2_id_stage", "cve2_if_stage", "cve2_load_store_unit", "cve2_multdiv_fast",
        "cve2_multdiv_slow", "cve2_prefetch_buffer", "cve2_pmp", "cve2_register_file_ff",
        "cve2_wb", "cve2_core", "cve2_clock_gate", "cve2_top")]
)
CVE2_INCDIRS = ["vendor/cve2/rtl", CVE2_PRIM, "vendor/cve2/vendor/lowrisc_ip/dv/sv/dv_utils"]

HAZARD3_RTL = [f"vendor/hazard3/hdl/{n}" for n in (
    "hazard3_core.v", "hazard3_cpu_1port.v", "hazard3_cpu_2port.v", "arith/hazard3_alu.v",
    "arith/hazard3_branchcmp.v", "arith/hazard3_mul_fast.v", "arith/hazard3_muldiv_seq.v",
    "arith/hazard3_onehot_encode.v", "arith/hazard3_onehot_priority.v",
    "arith/hazard3_onehot_priority_dynamic.v", "arith/hazard3_priority_encode.v",
    "arith/hazard3_shift_barrel.v", "hazard3_csr.v", "hazard3_decode.v", "hazard3_frontend.v",
    "hazard3_instr_decompress.v", "hazard3_irq_ctrl.v", "hazard3_pmp.v", "hazard3_power_ctrl.v",
    "hazard3_regfile_1w2r.v", "hazard3_triggers.v")]
HAZARD3_INCDIRS = ["vendor/hazard3/hdl"]

ISLAND_RTL = [
    "upycore/rtl/bsg_mem_1rw_sync_mask_write_bit.sv",
    "iocore/rtl/iocore_timer.sv", "iocore/rtl/iocore_uart.sv",
    "iocore/rtl/iocore_ahb2obi.sv", "iocore/rtl/iocore_cpu.sv", "iocore/rtl/iocore_top.sv",
]


def island(core: str = "both") -> tuple[list[str], list[str]]:
    """(files, include dirs) for the island with the named core option(s).

    iocore_cpu instantiates both options behind a generate; an elaboration
    needs only the chosen one's sources, but a simulator build that can pick
    either at run time needs both."""

    files, inc = [], []
    if core in ("cve2", "both"):
        files += CVE2_RTL
        inc += CVE2_INCDIRS
    if core in ("hazard3", "both"):
        files += HAZARD3_RTL
        inc += HAZARD3_INCDIRS
    return files + ISLAND_RTL, inc
