DateTime normalizeDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool isDateWithinRange(DateTime value, DateTime? start, DateTime? end) {
  final normalizedValue = normalizeDate(value);
  final normalizedStart = start == null ? null : normalizeDate(start);
  final normalizedEnd = end == null ? null : normalizeDate(end);

  if (normalizedStart != null && normalizedValue.isBefore(normalizedStart)) {
    return false;
  }

  if (normalizedEnd != null && normalizedValue.isAfter(normalizedEnd)) {
    return false;
  }

  return true;
}
