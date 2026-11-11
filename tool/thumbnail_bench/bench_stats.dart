// Summary statistics for the r2 thumbnail benchmark.
//
// Definitions (identical to tool/thumbnail_bench/bench_stats.py):
// - median: middle value for an odd count, mean of the two middle values for
//   an even count;
// - percentile p (0..1): linear interpolation between closest ranks on the
//   sorted values, h = (n - 1) * p (Hyndman & Fan type 7, the default of
//   NumPy `percentile` and R `quantile`).
// The r1 benchmark used sorted[round((n - 1) * p)] instead, which for an even
// count returns the upper of the two middle values as "median".

double median(List<num> xs) => percentile(xs, 0.5);

double percentile(List<num> xs, double p) {
  if (xs.isEmpty) throw ArgumentError('no values');
  if (p < 0 || p > 1) throw ArgumentError('p must be within 0..1');
  final s = [for (final x in xs) x.toDouble()]..sort();
  final h = (s.length - 1) * p;
  final lo = h.floor();
  final hi = h.ceil();
  return s[lo] + (s[hi] - s[lo]) * (h - lo);
}

Map<String, dynamic> summary(List<num> xs) {
  if (xs.isEmpty) return {'n': 0};
  final s = [for (final x in xs) x.toDouble()]..sort();
  return {
    'n': s.length,
    'median': median(s),
    'p95': percentile(s, 0.95),
    'min': s.first,
    'max': s.last,
  };
}
