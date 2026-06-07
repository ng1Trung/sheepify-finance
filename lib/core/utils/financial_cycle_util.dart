import 'package:flutter/material.dart';

class FinancialCycleUtil {
  static int normalizeStartDay(int startDay) => startDay.clamp(1, 31).toInt();

  static DateTimeRange cycleRangeFor(DateTime date, int startDay) {
    final normalizedDay = normalizeStartDay(startDay);
    final currentMonthStart = _cycleStartForMonth(
      date.year,
      date.month,
      normalizedDay,
    );

    final start = date.isBefore(currentMonthStart)
        ? _cycleStartForMonth(date.year, date.month - 1, normalizedDay)
        : currentMonthStart;
    final nextStart = _cycleStartForMonth(
      start.year,
      start.month + 1,
      normalizedDay,
    );

    return DateTimeRange(
      start: _startOfDay(start),
      end: nextStart.subtract(const Duration(seconds: 1)),
    );
  }

  static DateTimeRange previousCycleRange(DateTime date, int startDay) {
    final currentRange = cycleRangeFor(date, startDay);
    return cycleRangeFor(
      currentRange.start.subtract(const Duration(days: 1)),
      startDay,
    );
  }

  static bool isInRange(DateTime date, DateTimeRange range) {
    return !date.isBefore(range.start) && !date.isAfter(range.end);
  }

  static DateTime cycleDateInRange({
    required DateTimeRange range,
    required int day,
  }) {
    final normalizedDay = normalizeStartDay(day);
    final startCandidate = _dateInMonth(
      range.start.year,
      range.start.month,
      normalizedDay,
    );
    if (!startCandidate.isBefore(range.start) &&
        !startCandidate.isAfter(range.end)) {
      return startCandidate;
    }

    return _dateInMonth(range.end.year, range.end.month, normalizedDay);
  }

  static DateTime _cycleStartForMonth(int year, int month, int startDay) {
    return _dateInMonth(year, month, startDay);
  }

  static DateTime _dateInMonth(int year, int month, int day) {
    final firstOfMonth = DateTime(year, month);
    final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
    return DateTime(
      firstOfMonth.year,
      firstOfMonth.month,
      day.clamp(1, lastDay).toInt(),
    );
  }

  static DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
