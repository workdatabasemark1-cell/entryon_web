import 'package:flutter/foundation.dart';

/// Represents a single purchase item in an invoice
class PurchaseItem {
  final String id;
  final DateTime date;
  final String invoiceNo;
  final String supplierName;
  final String vatNumber;
  final String supplierId;
  final double amountExVat;
  final double vatRate;
  final double vatAmount;
  final double totalIncVat;
  final DateTime createdAt;
 

  PurchaseItem({
    required this.id,
    required this.date,
    required this.invoiceNo,
    required this.supplierName,
    required this.vatNumber,
    required this.supplierId,
    required this.amountExVat,
    required this.vatRate,
    required this.vatAmount,
    required this.totalIncVat,
    required this.createdAt,
  
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'invoiceNo': invoiceNo,
      'supplierName': supplierName,
      'vatNumber': vatNumber,
      'supplierId': supplierId,
      'amountExVat': amountExVat,
      'vatRate': vatRate,
      'vatAmount': vatAmount,
      'totalIncVat': totalIncVat,
      'createdAt': createdAt,
      
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is DateTime) return dateValue;
      if (dateValue.runtimeType.toString().contains('Timestamp')) {
        return dateValue.toDate();
      }
      try {
        return DateTime.parse(dateValue.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
        return DateTime.now();
      }
    }
    
    return PurchaseItem(
      id: (map['id'] as String?) ?? '',
      date: parseDate(map['date']),
      invoiceNo: (map['invoiceNo'] as String?) ?? '',
      supplierName: (map['supplierName'] as String?) ?? '',
      vatNumber: (map['vatNumber'] as String?) ?? '',
      supplierId: (map['supplierId'] as String?) ?? '',
      amountExVat: ((map['amountExVat'] as num?) ?? 0).toDouble(),
      vatRate: ((map['vatRate'] as num?) ?? 0).toDouble(),
      vatAmount: ((map['vatAmount'] as num?) ?? 0).toDouble(),
      totalIncVat: ((map['totalIncVat'] as num?) ?? 0).toDouble(),
      createdAt: parseDate(map['createdAt']),
    );
  }
}

/// Represents a purchase invoice header
class PurchaseInvoice {
  final String id;
  final String customerId;
  final String customerName;
  final String customerVatNumber;
  final String supplierId;
  final String supplierName;
  final String invoiceNo;
  final DateTime invoiceDate;
  final List<PurchaseItem> items;
  final DateTime createdAt;
  final String periodSectionName;
  final String periodSectionId;

  PurchaseInvoice({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerVatNumber,
    required this.supplierId,
    required this.supplierName,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.items,
    required this.createdAt,
    required this.periodSectionName,
    required this.periodSectionId,
  });

  double get totalAmountExVat => items.fold(0, (sum, item) => sum + item.amountExVat);
  double get totalVatAmount => items.fold(0, (sum, item) => sum + item.vatAmount);
  double get totalAmountIncVat => items.fold(0, (sum, item) => sum + item.totalIncVat);

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerVatNumber': customerVatNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'invoiceNo': invoiceNo,
      'invoiceDate': invoiceDate,
      'totalAmountExVat': totalAmountExVat,
      'totalVatAmount': totalVatAmount,
      'totalAmountIncVat': totalAmountIncVat,
      'createdAt': createdAt,
      'periodSectionName': periodSectionName,
      'periodSectionId': periodSectionId,
    };
  }

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map, List<PurchaseItem> items) {
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is DateTime) return dateValue;
      if (dateValue.runtimeType.toString().contains('Timestamp')) {
        return dateValue.toDate();
      }
      try {
        return DateTime.parse(dateValue.toString());
      } catch (e) {
        debugPrint('Error parsing date: $e');
        return DateTime.now();
      }
    }
    
    return PurchaseInvoice(
      id: (map['id'] as String?) ?? '',
      customerId: (map['customerId'] as String?) ?? '',
      customerName: (map['customerName'] as String?) ?? '',
      customerVatNumber: (map['customerVatNumber'] as String?) ?? '',
      supplierId: (map['supplierId'] as String?) ?? '',
      supplierName: (map['supplierName'] as String?) ?? '',
      invoiceNo: (map['invoiceNo'] as String?) ?? '',
      invoiceDate: parseDate(map['invoiceDate']),
      items: items,
      createdAt: parseDate(map['createdAt']),
      periodSectionName: map['periodSectionName'] as String,
      periodSectionId: map['periodSectionId'] as String,
    );
  }
}