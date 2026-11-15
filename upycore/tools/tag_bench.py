#!/usr/bin/env python3
"""Compare callable-tag and string-offset switches against the Step 0 evidence.

Each workload has one image shared by the five switch configurations.
Kernel output comparisons exclude only the measured cycle line. Event
counts cover the entire run, including work outside the kernel boundary.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import subprocess

import mpy_build as build
from perf_inventory import HARNESS, SUITE
from runtime_profile import kernel_source
from shortlist_bench import CASES as PAPER_CASES
import timing_bench

BASE = build.ROOT / "planning/builtin_function_tags_baseline"
SWITCHES = ("BTAG", "FTAG", "SOFF", "CFWD")
# "all" keeps its Step 11 meaning (the three tag/offset switches). CFWD,
# the resident-call forwarding, is measured on its own and on top of all.
CONFIGS = {
    "none": (0, 0, 0, 0),
    "BUILTIN": (1, 0, 0, 0),
    "FUNCTION": (0, 1, 0, 0),
    "STROFF": (0, 0, 1, 0),
    "all": (1, 1, 1, 0),
    "CFWD": (0, 0, 0, 1),
    "all+CFWD": (1, 1, 1, 1),
}


@dataclass(frozen=True)
class Workload:
    suite: str
    name: str
    source: Path
    image: Path
    base_cycles: int
    kernel: bool
    baseline_result: bytes | None = None


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def whole_program_cycles(path: Path) -> dict[str, int]:
    rows = {}
    for line in path.read_text().splitlines()[1:]:
        name, _, _, _, cycles, _ = line.split()
        rows[name] = int(cycles.replace(",", ""))
    return rows


def timed_workloads(out: Path) -> list[Workload]:
    paper = {row["name"]: row for row in json.loads((BASE / "shortlist.json").read_text())["rows"]}
    clock = {row["name"]: row for row in json.loads((BASE / "clock.json").read_text())["rows"]
             if row["kind"] == "kernel"}
    pi, = json.loads((BASE / "pidigits.json").read_text())["rows"]
    pi_base, = pi["runs"]

    def make(suite: str, name: str, source: str, cycles: int, expected: str | None = None,
             *, bigint: bool = False) -> Workload:
        work = out / suite / name
        work.mkdir(parents=True, exist_ok=True)
        src = work / f"{name}.py"
        src.write_text(source)
        image = build.build_program(src, work, src.name, bigint=bigint)
        return Workload(suite, name, src, image, cycles, True, expected.encode() if expected else None)

    firmware_images = {}

    def measured_firmware(*, io: bool = False, repl: bool = False, bigint: bool = False) -> Path:
        if io or repl:
            raise ValueError("Timed workloads use the simulator console")
        if bigint in firmware_images:
            return firmware_images[bigint]
        work = out / ("firmware-bigint" if bigint else "firmware")
        work.mkdir(exist_ok=True)
        src = work / "bench_fw.py"
        compiled = work / "bench_fw.mpy"
        src.write_text(build.firmware_source(bigint=bigint) + "\ndef bench_ticks():\n    return _ticks()\n")
        build.mpy_cross(src, compiled, "_fw.py")
        firmware_images[bigint] = compiled
        return compiled

    normal_firmware = build.build_firmware
    build.build_firmware = measured_firmware
    try:
        workloads = [
            make("paper", name, (SUITE / f"{name}.py").read_text() + HARNESS.format(n=100, m=100),
                 paper[name]["cycles"], paper[name]["result"])
            for name in PAPER_CASES.split(",")
        ]
        for workload in workloads:
            if sha(workload.source) != paper[workload.name]["source_sha256"]:
                raise RuntimeError(f"{workload.name}: source differs from the recorded baseline")
        workloads.append(make("bigint", "bm_pidigits", (SUITE / "bm_pidigits.py").read_text()
                              + HARNESS.format(n=100, m=100), pi_base["kernel_cycles"],
                              "RESULT " + pi_base["result"], bigint=True))
        for name in ("misc_aes", "bm_fannkuch"):
            workloads.append(make("clock", name, kernel_source(name), clock[name]["before_cycles"]))
        for name in (*timing_bench.CASES, "pystone"):
            workloads.append(make("clock", name, timing_bench.source(name, 1000, 300),
                                  clock[name]["before_cycles"]))
    finally:
        build.build_firmware = normal_firmware
    return workloads


def program_workloads(out: Path) -> list[Workload]:
    baseline = whole_program_cycles(BASE / "bench.txt") | whole_program_cycles(BASE / "microbench.txt")
    return [
        Workload("program", p.stem, p, build.build_program(p, out / "program" / p.stem, p.name),
                 baseline[p.stem], False)
        for p in sorted((build.ROOT / "upycore/programs/bench").glob("*.py"))
    ]


def measure(workload: Workload, max_cycles: int) -> dict:
    runs = {}
    reference = None
    for name, config in CONFIGS.items():
        flags = [f"+{switch}={value}" for switch, value in zip(SWITCHES, config)]
        sim = build.run_image(workload.image, max_cycles=max_cycles, timeout=3600,
                              sim_args=["+CA=1", "+AALU=1", "+STATS", *flags])
        if sim.exit_code != 0:
            raise RuntimeError(f"{workload.suite}/{workload.name} {name}: {sim.halt}: {sim.log[-1000:]}")
        cycles = sim.cycles
        output = sim.stdout
        if workload.kernel:
            lines = output.splitlines(keepends=True)
            measurement, = (line for line in lines if line.startswith((b"CYCLES ", b"BENCH ")))
            cycles = int(measurement.split()[1])
            output = b"".join(line for line in lines if line != measurement)
            if workload.baseline_result is not None and workload.baseline_result not in output.splitlines():
                raise RuntimeError(f"{workload.name} {name}: result differs from the recorded baseline")
        streams = (output, sim.stderr)
        if reference is None:
            reference = streams
        elif streams != reference:
            raise RuntimeError(f"{workload.suite}/{workload.name}: {name} output differs from none")
        events, = (line for line in sim.log.splitlines() if line.startswith("MPY_TAG_STATS "))
        counters = {key: int(value) for key, value in (part.split("=", 1) for part in events.split()[1:])}
        runs[name] = {"cycles": cycles, "total_cycles": sim.cycles, "events": counters}
    assert reference is not None
    return {
        "suite": workload.suite, "name": workload.name, "base_cycles": workload.base_cycles,
        "source_sha256": sha(workload.source),
        "image_sha256": sha(Path(f"{workload.image}.hex")),
        "tags_sha256": sha(Path(f"{workload.image}.tags.hex")),
        "stdout": reference[0].decode(), "stderr": reference[1].decode(), "runs": runs,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=build.ROOT / "build/tag_bench")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--max-cycles", type=int, default=500_000_000)
    parser.add_argument("--suite", choices=("timed", "program", "all"), default="all")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    simulator = build.build_sim()
    workloads = []
    if args.suite != "program":
        workloads.extend(timed_workloads(out))
    if args.suite != "timed":
        workloads.extend(program_workloads(out))
    data = {
        "base_commit": "e12d6fe60528dcfecd7325df3a3dc690c678646e",
        "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=build.ROOT, text=True).strip(),
        "simulator_sha256": sha(simulator), "compiler_sha256": sha(build.MPY_CROSS),
        "testbench_sha256": sha(build.ROOT / "upycore/tb/tb_mpy_soc.sv"),
        "switches": list(SWITCHES), "configurations": CONFIGS, "rows": [],
    }
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        for row in executor.map(lambda w: measure(w, args.max_cycles), workloads):
            data["rows"].append(row)
            (out / "results.json").write_text(json.dumps(data, indent=2) + "\n")
            print(row["suite"], row["name"], *(v["cycles"] for v in row["runs"].values()), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
