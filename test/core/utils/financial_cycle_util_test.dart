import 'package:flutter_test/flutter_test.dart';
import 'package:sheepify/core/utils/financial_cycle_util.dart';

void main() {
  group('FinancialCycleUtil', () {
    test('start day 1 matches the calendar month', () {
      final range = FinancialCycleUtil.cycleRangeFor(DateTime(2026, 6, 7), 1);

      expect(range.start, DateTime(2026, 6, 1));
      expect(range.end, DateTime(2026, 6, 30, 23, 59, 59));
    });

    test('start day 10 places dates before the 10th in the previous cycle', () {
      final range = FinancialCycleUtil.cycleRangeFor(DateTime(2026, 6, 7), 10);

      expect(range.start, DateTime(2026, 5, 10));
      expect(range.end, DateTime(2026, 6, 9, 23, 59, 59));
    });

    test('start day 10 starts a new cycle on the 10th', () {
      final range = FinancialCycleUtil.cycleRangeFor(DateTime(2026, 6, 10), 10);

      expect(range.start, DateTime(2026, 6, 10));
      expect(range.end, DateTime(2026, 7, 9, 23, 59, 59));
    });

    test('start day 31 clamps to the last day of shorter months', () {
      final beforeFebruaryClamp = FinancialCycleUtil.cycleRangeFor(
        DateTime(2026, 2, 15),
        31,
      );
      final onFebruaryClamp = FinancialCycleUtil.cycleRangeFor(
        DateTime(2026, 2, 28),
        31,
      );

      expect(beforeFebruaryClamp.start, DateTime(2026, 1, 31));
      expect(beforeFebruaryClamp.end, DateTime(2026, 2, 27, 23, 59, 59));
      expect(onFebruaryClamp.start, DateTime(2026, 2, 28));
      expect(onFebruaryClamp.end, DateTime(2026, 3, 30, 23, 59, 59));
    });

    test('previous cycle is adjacent to the current cycle', () {
      final current = FinancialCycleUtil.cycleRangeFor(
        DateTime(2026, 6, 10),
        10,
      );
      final previous = FinancialCycleUtil.previousCycleRange(
        DateTime(2026, 6, 10),
        10,
      );

      expect(previous.start, DateTime(2026, 5, 10));
      expect(previous.end, DateTime(2026, 6, 9, 23, 59, 59));
      expect(previous.end.add(const Duration(seconds: 1)), current.start);
    });
  });
}
