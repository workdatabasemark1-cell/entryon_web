import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ExpenseModel {
  final String id;
  final String title;
  final String category;
  final double amountExVat;
  final double vatRate; // e.g. 15.0 (%)
  final double vatAmount;
  final double totalAmount; // amountExVat + vatAmount
  final DateTime date;
  final String paymentMethod; // Cash, Bank Transfer, Card, Cheque, Online
  final String referenceNo; // Bill / receipt / voucher #
  final String paidTo; // Beneficiary or vendor
  final String notes;
  final String? periodSectionId;
  final String? periodSectionName;
  final String? customerId;
  final String? customerName;
  final String addedById;
  final String addedByName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amountExVat,
    this.vatRate = 15.0,
    required this.vatAmount,
    required this.totalAmount,
    required this.date,
    this.paymentMethod = 'Cash',
    this.referenceNo = '',
    this.paidTo = '',
    this.notes = '',
    this.periodSectionId,
    this.periodSectionName,
    this.customerId,
    this.customerName,
    this.addedById = '',
    this.addedByName = '',
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amountExVat': amountExVat,
      'vatRate': vatRate,
      'vatAmount': vatAmount,
      'totalAmount': totalAmount,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      'referenceNo': referenceNo,
      'paidTo': paidTo,
      'notes': notes,
      'periodSectionId': periodSectionId,
      'periodSectionName': periodSectionName,
      'customerId': customerId,
      'customerName': customerName,
      'addedById': addedById,
      'addedByName': addedByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      try {
        return DateTime.parse(val.toString());
      } catch (e) {
        debugPrint('Error parsing expense date: $e');
        return DateTime.now();
      }
    }

    final double exVat = ((map['amountExVat'] as num?) ??
            (map['amount'] as num?) ??
            0.0)
        .toDouble();
    final double vRate = ((map['vatRate'] as num?) ?? 15.0).toDouble();
    final double vAmount = ((map['vatAmount'] as num?) ?? (exVat * vRate / 100.0)).toDouble();
    final double total = ((map['totalAmount'] as num?) ?? (exVat + vAmount)).toDouble();

    return ExpenseModel(
      id: docId.isNotEmpty ? docId : ((map['id'] as String?) ?? ''),
      title: (map['title'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'General',
      amountExVat: exVat,
      vatRate: vRate,
      vatAmount: vAmount,
      totalAmount: total,
      date: parseDate(map['date']),
      paymentMethod: (map['paymentMethod'] as String?) ?? 'Cash',
      referenceNo: (map['referenceNo'] as String?) ?? '',
      paidTo: (map['paidTo'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      periodSectionId: map['periodSectionId'] as String?,
      periodSectionName: map['periodSectionName'] as String?,
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      addedById: (map['addedById'] as String?) ?? '',
      addedByName: (map['addedByName'] as String?) ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  ExpenseModel copyWith({
    String? id,
    String? title,
    String? category,
    double? amountExVat,
    double? vatRate,
    double? vatAmount,
    double? totalAmount,
    DateTime? date,
    String? paymentMethod,
    String? referenceNo,
    String? paidTo,
    String? notes,
    String? periodSectionId,
    String? periodSectionName,
    String? customerId,
    String? customerName,
    String? addedById,
    String? addedByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amountExVat: amountExVat ?? this.amountExVat,
      vatRate: vatRate ?? this.vatRate,
      vatAmount: vatAmount ?? this.vatAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNo: referenceNo ?? this.referenceNo,
      paidTo: paidTo ?? this.paidTo,
      notes: notes ?? this.notes,
      periodSectionId: periodSectionId ?? this.periodSectionId,
      periodSectionName: periodSectionName ?? this.periodSectionName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      addedById: addedById ?? this.addedById,
      addedByName: addedByName ?? this.addedByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
