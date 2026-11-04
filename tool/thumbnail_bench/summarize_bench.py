#!/usr/bin/env python3
"""Summarise thumbnail benchmark JSON files into one CSV.

Usage: python3 -I summarize_bench.py <out.csv> <label=file.json> [...]
"""
import csv
import json
import sys

METRICS = [
    ("cold_grid_32", "http_requests", "list"),
    ("cold_grid_32", "peak_inflight", "list"),
    ("cold_grid_32", "errors", "list"),
    ("cold_grid_32", "first_display_ms", "stats"),
    ("cold_grid_32", "all_done_ms", "stats"),
    ("cold_grid_32", "queue_wait_ms", "stats"),
    ("cold_grid_32", "completion_ms", "stats"),
    ("cache_hits_with_full_queue", "hits_done_while_network_held", "list"),
    ("cache_hits_with_full_queue", "hit_http_requests", "list"),
    ("cache_hits_with_full_queue", "hit_completion_ms", "stats"),
    ("slot_handoff", "handoff_ms", "stats"),
    ("history_and_cover_same_comic", "http_requests", "list"),
]


def main():
    out = sys.argv[1]
    rows = []
    for arg in sys.argv[2:]:
        label, path = arg.split("=", 1)
        data = json.load(open(path))
        sc = data["scenarios"]
        for scenario, metric, kind in METRICS:
            v = sc[scenario][metric]
            if kind == "stats":
                rows.append([label, scenario, metric, v["n"], v["median"],
                             v["p95"], v["min"], v["max"], ""])
            else:
                rows.append([label, scenario, metric, len(v), "", "", min(v),
                             max(v), " ".join(map(str, v))])
        for scenario in ("cache_hit_paths", "broken_cache_retry"):
            raw = sc[scenario]["raw"]
            for key in raw[0]:
                vals = [r[key] for r in raw]
                rows.append([label, scenario, key, len(vals), "", "", "", "",
                             " ".join(map(str, vals))])
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["label", "scenario", "metric", "n", "median", "p95",
                    "min", "max", "per_sample_values"])
        w.writerows(rows)


if __name__ == "__main__":
    main()
