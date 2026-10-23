import 'package:flutter_test/flutter_test.dart';
import 'package:entryon/models/expense_model.dart';

void main() {
  group('Expense Tax Calculation Tests', () {
    test('Inclusive VAT calculation (gross to net + vat)', () {
      const double gross = 115.0;
      const double vatRate = 15.0;

      final double exVat = gross / (1.0 + vatRate / 100.0);
      final double vatAmount = gross - exVat;

      expect(exVat, closeTo(100.0, 0.001));
      expect(vatAmount, closeTo(15.0, 0.001));
      expect(exVat + vatAmount, closeTo(gross, 0.001));
    });

    test('Exclusive VAT calculation (net to vat + total)', () {
      const double net = 200.0;
      const double vatRate = 15.0;

      final double vatAmount = net * (vatRate / 100.0);
      final double totalAmount = net + vatAmount;

      expect(vatAmount, closeTo(30.0, 0.001));
      expect(totalAmount, closeTo(230.0, 0.001));
    });

    test('Zero tax calculation handles gross == net', () {
      const double gross = 50.0;
      const double vatRate = 0.0;

      final double exVat = vatRate > 0 ? gross / (1.0 + vatRate / 100.0) : gross;
      final double vatAmount = gross - exVat;

      expect(exVat, equals(50.0));
      expect(vatAmount, equals(0.0));
    });

    test('ExpenseModel correctly stores calculated VAT in inclusive mode', () {
      const double gross = 230.0;
      const double vatRate = 15.0;
      final double exVat = gross / (1.0 + vatRate / 100.0);
      final double vatAmount = gross - exVat;

      final expense = ExpenseModel(
        id: 'test_123',
        title: 'Office Supplies',
        category: 'Office & Stationery',
        amountExVat: exVat,
        vatRate: vatRate,
        vatAmount: vatAmount,
        totalAmount: gross,
        date: DateTime(2026, 3, 28),
        paymentMethod: 'Card',
        createdAt: DateTime(2026, 3, 28),
      );

      expect(expense.amountExVat, closeTo(200.0, 0.01));
      expect(expense.vatAmount, closeTo(30.0, 0.01));
      expect(expense.totalAmount, equals(230.0));

      final map = expense.toMap();
      expect(map['totalAmount'], equals(230.0));
      expect(map['vatAmount'], closeTo(30.0, 0.01));
      expect(map['amountExVat'], closeTo(200.0, 0.01));
    });
  });
}
