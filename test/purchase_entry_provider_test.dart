import 'package:entryon/models/service_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service entry preserves payment type in map conversion', () {
    final service = ServiceEntry(
      id: 'svc-1',
      title: 'Oil Change',
      customerName: 'Ali',
      serviceDate: DateTime(2026, 8, 3),
      amount: 100,
      paymentType: 'Card',
    );

    final map = service.toMap();
    expect(map['paymentType'], 'Card');

    final restored = ServiceEntry.fromMap(map, 'svc-1');
    expect(restored.paymentType, 'Card');
  });
}
