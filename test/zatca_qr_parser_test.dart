import 'dart:convert';

import 'package:entryon/utils/zatca_qr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes Arabic seller names from QR TLV payloads', () {
    final sellerBytes = utf8.encode('شركة أبو عادل');
    final tlvBytes = <int>[1, sellerBytes.length, ...sellerBytes];

    final data = ZatcaQrParser.parse(base64.encode(tlvBytes));

    expect(data, isNotNull);
    expect(data!.sellerName, 'شركة أبو عادل');
  });

  test('decodes all ZATCA invoice fields', () {
    final fields = {
      1: 'Seller',
      2: '123456789012345',
      3: '2026-10-23T10:00:00Z',
      4: '115.00',
      5: '15.00',
    };
    final tlvBytes = <int>[
      for (final field in fields.entries) ...[
        field.key,
        utf8.encode(field.value).length,
        ...utf8.encode(field.value),
      ],
    ];

    final data = ZatcaQrParser.parse(base64.encode(tlvBytes));

    expect(data, isNotNull);
    expect(data!.sellerName, 'Seller');
    expect(data.vatNumber, '123456789012345');
    expect(data.invoiceDate, '2026-10-23T10:00:00Z');
    expect(data.totalIncVat, '115.00');
    expect(data.vatAmount, '15.00');
  });

  test('rejects truncated TLV payloads', () {
    final truncatedPayload = base64.encode([1, 5, 65]);

    expect(ZatcaQrParser.parse(truncatedPayload), isNull);
  });
}
