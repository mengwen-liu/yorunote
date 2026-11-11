#!/usr/bin/env python3
"""Summary statistics for the thumbnail benchmark (same as bench_stats.dart).

median: middle value (odd n) or mean of the two middle values (even n).
percentile p in [0, 1]: linear interpolation, h = (n - 1) * p
(Hyndman & Fan type 7; NumPy `percentile` default, R `quantile` default).
r1_rank(p): the r1 rule sorted[round((n - 1) * p)], kept only to explain
old numbers. Note Dart rounds .5 away from zero, Python rounds half to even;
r1_rank therefore uses floor(x + 0.5) to match Dart.

Run `python3 -I bench_stats.py --self-test` to check the known values.
"""
import math
import sys


def percentile(xs, p):
    if not xs:
        raise ValueError("no values")
    s = sorted(float(x) for x in xs)
    h = (len(s) - 1) * p
    lo, hi = math.floor(h), math.ceil(h)
    return s[lo] + (s[hi] - s[lo]) * (h - lo)


def median(xs):
    return percentile(xs, 0.5)


def r1_rank(xs, p):
    s = sorted(float(x) for x in xs)
    return s[math.floor((len(s) - 1) * p + 0.5)]


def summary(xs):
    s = sorted(float(x) for x in xs)
    return {"n": len(s), "median": median(s), "p95": percentile(s, 0.95),
            "min": s[0], "max": s[-1]}


def self_test():
    assert median([5, 1, 3]) == 3
    assert median([4, 1, 3, 2]) == 2.5
    assert median([10, 20]) == 15
    xs = list(range(1, 11))
    assert percentile(xs, 0) == 1 and percentile(xs, 1) == 10
    assert abs(percentile(xs, 0.95) - 9.55) < 1e-9
    assert abs(percentile(xs, 0.25) - 3.25) < 1e-9
    assert abs(percentile([15, 20, 35, 40, 50], 0.4) - 29) < 1e-9
    assert r1_rank([1, 2, 3, 4], 0.5) == 3
    # Dart's round(1.5) == 2, round(2.5) == 3 (away from zero).
    assert r1_rank([1, 2, 3, 4, 5, 6], 0.5) == 4
    print("bench_stats self-test: OK")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
