#!/usr/bin/env python3
"""Summarise alternating r2 benchmark invocations.

Each JSON file is one invocation (one process) of
thumbnail_bench_r2_test.dart: 1 warm-up + N samples. Hierarchy:
  image   -> values inside one sample (not independent)
  sample  -> one repetition inside an invocation (same process)
  invocation (run) -> the independent unit compared between arms.
For each per-image metric, a sample is reduced to its median; an invocation to
the median of its samples; an arm is reported as the median and the min..max
of its invocation values. Scalar per-sample metrics are reduced the same way
from the sample level.

Usage: python3 -I summarize_r2.py <out.json> <arm>=<file.json> [...]
(files listed in the order they were run).
"""
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench_stats as st  # noqa: E402

PER_IMAGE = [
    ("cold_grid_32", "resolve_to_server_arrival_ms"),
    ("cold_grid_32", "completion_ms"),
    ("cache_hits_with_full_queue", "hit_completion_ms"),
    ("slot_handoff", "handoff_ms"),
]
SCALAR = [
    ("cold_grid_32", "first_display_ms"),
    ("cold_grid_32", "all_done_ms"),
    ("cold_grid_32", "http_requests"),
    ("cold_grid_32", "peak_inflight"),
    ("cache_hits_with_full_queue", "hits_done_while_network_held"),
    ("history_and_cover_same_comic", "http_requests"),
]


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    out = sys.argv[1]
    runs = []
    for order, arg in enumerate(sys.argv[2:]):
        arm, path = arg.split("=", 1)
        data = json.load(open(path))
        sc = data["scenarios"]
        vals = {}
        for scenario, metric in PER_IMAGE:
            samples = [st.median(r[metric]) for r in sc[scenario]["raw"]]
            vals[f"{scenario}.{metric}"] = st.median(samples)
        for scenario, metric in SCALAR:
            samples = [r[metric] for r in sc[scenario]["raw"]]
            vals[f"{scenario}.{metric}"] = st.median(samples)
        vals["broken_cache_retry.retry_errors"] = st.median(
            [r["retry_errors"] for r in sc["broken_cache_retry"]["raw"]])
        runs.append({"order": order, "arm": arm, "file": os.path.basename(path),
                     "sha256": sha256(path), "label": data.get("label"),
                     "samples": data.get("samples"), "values": vals})
    arms = sorted({r["arm"] for r in runs})
    keys = list(runs[0]["values"].keys())
    summary = {}
    for k in keys:
        summary[k] = {}
        for arm in arms:
            xs = [r["values"][k] for r in runs if r["arm"] == arm]
            summary[k][arm] = {"invocations": len(xs), "median": st.median(xs),
                               "min": min(xs), "max": max(xs), "values": xs}
    json.dump({
        "method": __doc__,
        "statistics": "bench_stats.py (median; type-7 percentiles)",
        "runs": runs,
        "summary": summary,
    }, open(out, "w"), indent=2, ensure_ascii=False)


if __name__ == "__main__":
    st.self_test()
    main()
