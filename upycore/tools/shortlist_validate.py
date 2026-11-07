#!/usr/bin/env python3
"""Audit complete saved short-list captures without rerunning simulations.

Checks source/image identity, result agreement, and full manifest coverage.
Historical timeouts remain in the logs; a later passing rerun supersedes them.
This checks captured evidence, not an independent MicroPython oracle.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

import hw_tests

ROOT = Path(__file__).resolve().parents[2]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path,
                        default=ROOT / "upycore/docs/benchmarks/shortlist")
    args = parser.parse_args()
    folder = args.evidence
    read = lambda name: json.loads((folder / name).read_text())
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()

    baseline = read("baseline-kernels.json")
    current = read("kernels.json")
    old = {row["name"]: row for row in baseline["rows"]}
    now = {row["name"]: row for row in current["rows"]}
    require(len(old) == 15 and old.keys() == now.keys(), "Incomplete kernel suite")
    for name, row in now.items():
        require(row["ok"] and old[name]["ok"], f"Unvalidated kernel: {name}")
        for key in ("source_sha256", "result"):
            require(row[key] == old[name][key], f"Baseline kernel differs: {name}, {key}")
    for path, expected in current["rtl_sha256"].items():
        require(sha(ROOT / path) == expected, f"Captured RTL is stale: {path}")
    for name, expected in current["firmware_sources_sha256"].items():
        require(sha(ROOT / "upycore/firmware" / name) == expected,
                f"Captured firmware is stale: {name}")
    for filename in ("native-core-kernels.json", "eight-kernels.json"):
        other = read(filename)
        require({r["name"] for r in other["rows"]} == {"bm_fannkuch", "bm_nqueens"},
                f"Incomplete comparison: {filename}")
        require(other["firmware_sha256"] == current["firmware_sha256"],
                f"Comparison firmware differs: {filename}")
        for row in other["rows"]:
            require(row["ok"], f"Unvalidated comparison: {filename}")
            for key in ("image_sha256", "source_sha256", "result"):
                require(row[key] == now[row["name"]][key],
                        f"Matched-image comparison differs: {filename}, {key}")

    old_project = {r["name"]: r for r in read("baseline-project.json")["rows"]}
    project = read("project.json")["rows"]
    require(len(old_project) == 11 and {r["name"] for r in project} == old_project.keys(),
            "Incomplete project suite")
    for row in project:
        previous = old_project[row["name"]]
        require(row["source_sha256"] == previous["source_sha256"], "Project source differs")
        require(len(row["runs"]) == len(previous["runs"]) == 4, "Incomplete project modes")
        for run, before in zip(row["runs"], previous["runs"]):
            require(run["ok"] and before["ok"], f"Project failed: {row['name']}")
            for key in ("mode", "stdout", "stderr"):
                require(run[key] == before[key], f"Project differs: {row['name']}, {key}")
    for filename, count in (("micro.json", 68), ("eight-micro.json", 14)):
        rows = read(filename)["rows"]
        require(len(rows) == count, f"Incomplete micro suite: {filename}")
        for row in rows:
            require({run["mode"] for run in row["runs"]} == {0, 1, 2}, "Missing micro mode")
            require(all(run["ok"] for run in row["runs"]), f"Micro failed: {row['name']}")

    manifest = {f"{t.area}/{t.name}" for t in hw_tests.for_device(hw_tests.load_manifest())}
    methods = read("method-cases.json")
    require(len(methods) == 6 and all(r["ok"] for r in methods), "Method dispatch failed")
    hardware = []
    cross_status = {}
    equivalence = read("image-equivalence.json")
    environment = read("environment.json")
    require(equivalence["simulator_sha256"] == environment["simulator_sha256"],
            "Image equivalence uses a different simulator")
    require(equivalence["mpy_cross_sha256"] == environment["compiler_sha256"],
            "Image equivalence uses a different firmware compiler")
    require(len(equivalence["rows"]) == len({r["test"] for r in equivalence["rows"]}) == 100,
            "Incomplete or duplicate image equivalence cases")
    tests_by_name = {f"{t.area}/{t.name}": t for t in hw_tests.for_device(hw_tests.load_manifest())}
    pattern = re.compile(r"^(PASS|FAIL)\s+(\w+/\S+)", re.M)
    for compiler, stem in (("mpy-cross", "hardware"), ("mpyc", "mpyc")):
        status = {}
        logs = [f"{stem}-initial.log", f"{stem}-resumed.log"]
        supplement = folder / f"{stem}-supplement.log"
        if supplement.exists():
            logs.append(supplement.name)
        for name in logs:
            for result, test in pattern.findall((folder / name).read_text()):
                status[test] = result
        require(any(r["compiler"] == compiler and r["mode"] == 2 and r["ok"] for r in methods),
                "Missing default-mode method coverage")
        status["containers/shortlist_methods"] = "PASS"
        reused = []
        if compiler == "mpy-cross":
            cross_status = dict(status)
        else:
            for row in equivalence["rows"]:
                test = row["test"]
                require(test in tests_by_name, f"Unknown equivalent image: {test}")
                require(row["source_sha256"] == sha(tests_by_name[test].source),
                        f"Equivalent image source is stale: {test}")
                require(row["max_cycles"] == tests_by_name[test].cycles,
                        f"Equivalent image cycle budget differs: {test}")
                identical = (len(row["pairs"]) == 2 and all(
                    p["mpyc_sha256"] == p["mpy_cross_sha256"] for p in row["pairs"]))
                require(row["identical"] == identical, f"Invalid image comparison: {test}")
                if test not in status and identical and cross_status.get(test) == "PASS":
                    status[test] = "PASS"
                    reused.append(test)
        missing = sorted(manifest - status.keys())
        failed = sorted(t for t in manifest if status.get(t) != "PASS")
        require(not missing and not failed, f"{compiler}: missing {missing}, failed {failed}")
        hardware.append({"compiler": compiler, "passed": len(manifest),
                         "logs": logs, "method_evidence": "method-cases.json",
                         "identical_image_reuse": reused})

    unit = (folder / "unit-tests.log").read_text()
    require("unit_tests: 29 of 29 passed" in unit, "RTL unit suite incomplete")
    require("checks=339" in unit and "checks=227" in unit, "Short-engine unit cases missing")
    for row in read("ppa.json"):
        require(row["latches"] == 0, f"Synthesized latches: {row['name']}")
    host = (folder / "compiler-suite.log").read_text()
    require(re.findall(r"^DIFFER (\S+)", host, re.M) == ["math_funcs.py"],
            "Unexpected host compiler mismatch set")
    require("504 file(s), 500 byte-exact, 3 float spelling, 1 differ" in host,
            "Incomplete host comparison")
    summary = {"kernels": 15, "project_runs": 44, "micro_runs": 246,
               "method_runs": 6, "rtl_benches": 29, "short_engine_unit_cases": 566,
               "hardware": hardware, "host_inherited_mismatch": "math_funcs.py",
               "independent_pinned_oracle_run": False,
               "physical_timing_closure": False,
               "evidence_sha256": {p.name: sha(p) for p in sorted(folder.iterdir())
                                   if p.is_file() and p.name != "validation.json"}}
    (folder / "validation.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({k: v for k, v in summary.items() if k != "evidence_sha256"}, indent=2))


if __name__ == "__main__":
    main()
