#!/usr/bin/env python3
"""Recompute r1 thumbnail benchmark summaries with the r2 definitions.

Reads r1 raw JSON files read-only and writes a new JSON report. For every
per-image metric it gives:
- pooled: all images of all runs together, with the r1 rule
  (sorted[round((n - 1) * p)]) and the r2 rule (bench_stats.py), side by side;
- per_run: the r2 median of each run (one value per run), and the median,
  min and max of those run medians. Runs, not images, are the independent
  repetitions; the images of one run share the same process and timing.

The r1 metric `queue_wait_ms` was measured from the call to
ImageProvider.resolve to the arrival of the request at the test server, so it
includes the cache lookup, the time in the limiter and the connection; it is
reported here as `resolve_to_server_arrival_ms`. Time spent inside the limiter
alone was not recorded in r1 and is not derived here.

Usage: python3 -I recompute_r1.py <out.json> <label=r1.json> [...]
"""
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench_stats as st  # noqa: E402

RENAME = {"queue_wait_ms": "resolve_to_server_arrival_ms"}
PER_IMAGE = [
    ("cold_grid_32", "queue_wait_ms"),
    ("cold_grid_32", "completion_ms"),
    ("cache_hits_with_full_queue", "hit_completion_ms"),
    ("slot_handoff", "handoff_ms"),
]
PER_RUN_SCALAR = [
    ("cold_grid_32", "first_display_ms"),
    ("cold_grid_32", "all_done_ms"),
]


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    out = sys.argv[1]
    report = {"definitions": {
        "median_r2": "middle value (odd n), mean of the two middle values (even n)",
        "percentile_r2": "linear interpolation, h=(n-1)*p (Hyndman-Fan type 7)",
        "rule_r1": "sorted[round((n-1)*p)], Dart round half away from zero",
        "independent_unit": "one benchmark run (sample); images inside a run are not independent",
        "renamed": RENAME,
    }, "sources": {}, "results": {}}
    for arg in sys.argv[2:]:
        label, path = arg.split("=", 1)
        data = json.load(open(path))
        report["sources"][label] = {"path": path, "sha256": sha256(path),
                                    "label_in_file": data.get("label")}
        res = {}
        sc = data["scenarios"]
        for scenario, metric in PER_IMAGE:
            raw = sc[scenario]["raw"]
            runs = [r[metric] for r in raw]
            pooled = [x for r in runs for x in r]
            run_medians = [st.median(r) for r in runs]
            name = RENAME.get(metric, metric)
            res[f"{scenario}.{name}"] = {
                "runs": len(runs),
                "images_per_run": sorted({len(r) for r in runs}),
                "pooled_n": len(pooled),
                "pooled_r1": {"median": st.r1_rank(pooled, 0.5),
                              "p95": st.r1_rank(pooled, 0.95)},
                "pooled_r2": {"median": st.median(pooled),
                              "p95": st.percentile(pooled, 0.95)},
                "per_run_median": run_medians,
                "across_runs": {"median": st.median(run_medians),
                                "min": min(run_medians),
                                "max": max(run_medians)},
            }
        for scenario, metric in PER_RUN_SCALAR:
            vals = [r[metric] for r in sc[scenario]["raw"]]
            res[f"{scenario}.{metric}"] = {
                "runs": len(vals),
                "r1": {"median": st.r1_rank(vals, 0.5),
                       "p95": st.r1_rank(vals, 0.95)},
                "r2": {"median": st.median(vals),
                       "p95": st.percentile(vals, 0.95),
                       "min": min(vals), "max": max(vals)},
            }
        report["results"][label] = res
    with open(out, "w") as f:
        json.dump(report, f, indent=2)


if __name__ == "__main__":
    st.self_test()
    main()
