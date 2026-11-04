// Known-value checks of bench_stats.dart (run explicitly with flutter test).
import 'package:flutter_test/flutter_test.dart';

import 'bench_stats.dart';

void main() {
  test('median of an odd count is the middle value', () {
    expect(median([5, 1, 3]), 3);
    expect(median([7]), 7);
  });

  test('median of an even count is the mean of the two middle values', () {
    expect(median([4, 1, 3, 2]), 2.5);
    expect(median([10, 20]), 15);
  });

  test('percentiles interpolate linearly between ranks (type 7)', () {
    final xs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    expect(percentile(xs, 0), 1);
    expect(percentile(xs, 1), 10);
    expect(percentile(xs, 0.95), closeTo(9.55, 1e-9));
    expect(percentile(xs, 0.25), closeTo(3.25, 1e-9));
    expect(percentile([15, 20, 35, 40, 50], 0.4), closeTo(29, 1e-9));
  });

  test('r1 rounding rule differs for an even count', () {
    final xs = [1, 2, 3, 4];
    double r1(List<num> v, double p) =>
        ([...v]..sort())[((v.length - 1) * p).round()].toDouble();
    expect(r1(xs, 0.5), 3, reason: 'upper middle value');
    expect(median(xs), 2.5);
  });
}
