import 'package:flutter_test/flutter_test.dart';
import 'package:entryon/utils/date_utils.dart';

void main() {
  group('isDateWithinRange', () {
    test('includes dates on the start and end day', () {
      final start = DateTime(2024, 1, 10);
      final end = DateTime(2024, 1, 15);

      expect(isDateWithinRange(DateTime(2024, 1, 10), start, end), isTrue);
      expect(isDateWithinRange(DateTime(2024, 1, 15), start, end), isTrue);
    });

    test('excludes dates before the start or after the end', () {
      final start = DateTime(2024, 1, 10);
      final end = DateTime(2024, 1, 15);

      expect(isDateWithinRange(DateTime(2024, 1, 9), start, end), isFalse);
      expect(isDateWithinRange(DateTime(2024, 1, 16), start, end), isFalse);
    });
  });
}
