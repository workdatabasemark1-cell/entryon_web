import 'package:flutter_test/flutter_test.dart';
import 'package:entryon/utils/file_name_utils.dart';

void main() {
  group('buildSafeExportFileName', () {
    test('removes path separators and invalid characters from invoice numbers', () {
      expect(buildSafeExportFileName('S/2/6878'), 'invoice_S_2_6878');
    });

    test('collapses repeated separators and keeps extension', () {
      expect(buildSafeExportFileName('INV:2026?07'), 'invoice_INV_2026_07');
    });

    test('falls back to a default name when input is empty', () {
      expect(buildSafeExportFileName('   '), 'invoice');
    });
  });
}
