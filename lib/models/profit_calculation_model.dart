import 'package:cloud_firestore/cloud_firestore.dart';

class ProfitCalculation {
  final String id;
  final String? customerId;
  final String? customerName;
  final String? branchName;
  final String? periodId;
  final String? periodName;
  final String? vatNumber;
  final double taxPercent;
  final bool enteredValuesIncludeVat;
  final double targetProfitPercent;
  final double targetProfitAmount;
  final double enteredSales;
  final double enteredPurchases;
  final double salesWithoutTax;
  final double salesWithTax;
  final double purchasesWithoutTax;
  final double purchasesWithTax;
  final double grossProfit;
  final double profitMargin;
  final double netVatDue;
  final double targetProfit;
  final DateTime createdAt;
  final String createdById;
  final String createdByName;

  const ProfitCalculation({
    required this.id,
    this.customerId,
    this.customerName,
    this.branchName,
    this.periodId,
    this.periodName,
    this.vatNumber,
    required this.taxPercent,
    required this.enteredValuesIncludeVat,
    required this.targetProfitPercent,
    required this.targetProfitAmount,
    required this.enteredSales,
    required this.enteredPurchases,
    required this.salesWithoutTax,
    required this.salesWithTax,
    required this.purchasesWithoutTax,
    required this.purchasesWithTax,
    required this.grossProfit,
    required this.profitMargin,
    required this.netVatDue,
    required this.targetProfit,
    required this.createdAt,
    required this.createdById,
    required this.createdByName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'branchName': branchName,
        'periodId': periodId,
        'periodName': periodName,
        'vatNumber': vatNumber,
        'taxPercent': taxPercent,
        'enteredValuesIncludeVat': enteredValuesIncludeVat,
        'targetProfitPercent': targetProfitPercent,
        'targetProfitAmount': targetProfitAmount,
        'enteredSales': enteredSales,
        'enteredPurchases': enteredPurchases,
        'salesWithoutTax': salesWithoutTax,
        'salesWithTax': salesWithTax,
        'purchasesWithoutTax': purchasesWithoutTax,
        'purchasesWithTax': purchasesWithTax,
        'grossProfit': grossProfit,
        'profitMargin': profitMargin,
        'netVatDue': netVatDue,
        'targetProfit': targetProfit,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdById': createdById,
        'createdByName': createdByName,
      };

  factory ProfitCalculation.fromMap(Map<String, dynamic> map, String documentId) {
    final createdAt = map['createdAt'];
    return ProfitCalculation(
      id: documentId,
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      branchName: map['branchName'] as String?,
      periodId: map['periodId'] as String?,
      periodName: map['periodName'] as String?,
      vatNumber: map['vatNumber'] as String?,
      taxPercent: (map['taxPercent'] as num?)?.toDouble() ?? 0,
      enteredValuesIncludeVat: map['enteredValuesIncludeVat'] as bool? ?? true,
      targetProfitPercent: (map['targetProfitPercent'] as num?)?.toDouble() ?? 0,
      targetProfitAmount: (map['targetProfitAmount'] as num?)?.toDouble() ?? 0,
      enteredSales: (map['enteredSales'] as num?)?.toDouble() ?? 0,
      enteredPurchases: (map['enteredPurchases'] as num?)?.toDouble() ?? 0,
      salesWithoutTax: (map['salesWithoutTax'] as num?)?.toDouble() ?? 0,
      salesWithTax: (map['salesWithTax'] as num?)?.toDouble() ?? 0,
      purchasesWithoutTax: (map['purchasesWithoutTax'] as num?)?.toDouble() ?? 0,
      purchasesWithTax: (map['purchasesWithTax'] as num?)?.toDouble() ?? 0,
      grossProfit: (map['grossProfit'] as num?)?.toDouble() ?? 0,
      profitMargin: (map['profitMargin'] as num?)?.toDouble() ?? 0,
      netVatDue: (map['netVatDue'] as num?)?.toDouble() ?? 0,
      targetProfit: (map['targetProfit'] as num?)?.toDouble() ?? 0,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.tryParse(createdAt?.toString() ?? '') ?? DateTime.now(),
      createdById: map['createdById']?.toString() ?? '',
      createdByName: map['createdByName']?.toString() ?? '',
    );
  }

  ProfitCalculation copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? branchName,
    String? periodId,
    String? periodName,
    String? vatNumber,
    double? taxPercent,
    bool? enteredValuesIncludeVat,
    double? targetProfitPercent,
    double? targetProfitAmount,
    double? enteredSales,
    double? enteredPurchases,
    double? salesWithoutTax,
    double? salesWithTax,
    double? purchasesWithoutTax,
    double? purchasesWithTax,
    double? grossProfit,
    double? profitMargin,
    double? netVatDue,
    double? targetProfit,
    DateTime? createdAt,
    String? createdById,
    String? createdByName,
  }) {
    return ProfitCalculation(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      branchName: branchName ?? this.branchName,
      periodId: periodId ?? this.periodId,
      periodName: periodName ?? this.periodName,
      vatNumber: vatNumber ?? this.vatNumber,
      taxPercent: taxPercent ?? this.taxPercent,
      enteredValuesIncludeVat: enteredValuesIncludeVat ?? this.enteredValuesIncludeVat,
      targetProfitPercent: targetProfitPercent ?? this.targetProfitPercent,
      targetProfitAmount: targetProfitAmount ?? this.targetProfitAmount,
      enteredSales: enteredSales ?? this.enteredSales,
      enteredPurchases: enteredPurchases ?? this.enteredPurchases,
      salesWithoutTax: salesWithoutTax ?? this.salesWithoutTax,
      salesWithTax: salesWithTax ?? this.salesWithTax,
      purchasesWithoutTax: purchasesWithoutTax ?? this.purchasesWithoutTax,
      purchasesWithTax: purchasesWithTax ?? this.purchasesWithTax,
      grossProfit: grossProfit ?? this.grossProfit,
      profitMargin: profitMargin ?? this.profitMargin,
      netVatDue: netVatDue ?? this.netVatDue,
      targetProfit: targetProfit ?? this.targetProfit,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
    );
  }

  /// Combines multiple calculations into a single consolidated ProfitCalculation.
  static ProfitCalculation combine(List<ProfitCalculation> list) {
    if (list.isEmpty) {
      throw ArgumentError('Cannot combine an empty list of calculations');
    }
    if (list.length == 1) {
      return list.first;
    }

    double totalEnteredSales = 0;
    double totalEnteredPurchases = 0;
    double totalSalesWithoutTax = 0;
    double totalSalesWithTax = 0;
    double totalPurchasesWithoutTax = 0;
    double totalPurchasesWithTax = 0;
    double totalGrossProfit = 0;
    double totalNetVatDue = 0;
    double totalTargetProfit = 0;
    double totalTargetProfitAmount = 0;

    final customerNames = <String>{};
    final branchNames = <String>{};
    final periodNames = <String>{};
    final creatorNames = <String>{};

    for (final c in list) {
      totalEnteredSales += c.enteredSales;
      totalEnteredPurchases += c.enteredPurchases;
      totalSalesWithoutTax += c.salesWithoutTax;
      totalSalesWithTax += c.salesWithTax;
      totalPurchasesWithoutTax += c.purchasesWithoutTax;
      totalPurchasesWithTax += c.purchasesWithTax;
      totalGrossProfit += c.grossProfit;
      totalNetVatDue += c.netVatDue;
      totalTargetProfit += c.targetProfit;
      totalTargetProfitAmount += c.targetProfitAmount;

      if (c.customerName != null && c.customerName!.trim().isNotEmpty) {
        customerNames.add(c.customerName!.trim());
      }
      if (c.branchName != null && c.branchName!.trim().isNotEmpty) {
        branchNames.add(c.branchName!.trim());
      }
      if (c.periodName != null && c.periodName!.trim().isNotEmpty) {
        periodNames.add(c.periodName!.trim());
      }
      if (c.createdByName.trim().isNotEmpty) {
        creatorNames.add(c.createdByName.trim());
      }
    }

    final combinedMargin = totalSalesWithoutTax > 0
        ? (totalGrossProfit / totalSalesWithoutTax) * 100
        : 0.0;

    final combinedCustomer = customerNames.isEmpty
        ? 'Consolidated Statements'
        : (customerNames.length == 1
            ? customerNames.first
            : '${customerNames.first} + ${customerNames.length - 1} other(s)');

    final combinedBranch = branchNames.isEmpty
        ? null
        : (branchNames.length == 1
            ? branchNames.first
            : '${branchNames.length} Branches');

    final combinedPeriod = periodNames.isEmpty
        ? 'Multiple Periods'
        : (periodNames.length == 1
            ? periodNames.first
            : periodNames.join(', '));

    final combinedCreator = creatorNames.isEmpty
        ? 'Multiple Users'
        : (creatorNames.length == 1
            ? creatorNames.first
            : creatorNames.join(', '));

    final avgTaxPct =
        list.map((e) => e.taxPercent).reduce((a, b) => a + b) / list.length;

    return ProfitCalculation(
      id: 'combined_${DateTime.now().millisecondsSinceEpoch}',
      customerId: customerNames.length == 1 ? list.first.customerId : null,
      customerName: combinedCustomer,
      branchName: combinedBranch,
      periodId: null,
      periodName: combinedPeriod,
      taxPercent: avgTaxPct,
      enteredValuesIncludeVat: list.first.enteredValuesIncludeVat,
      targetProfitPercent: 0,
      targetProfitAmount: totalTargetProfitAmount,
      enteredSales: totalEnteredSales,
      enteredPurchases: totalEnteredPurchases,
      salesWithoutTax: totalSalesWithoutTax,
      salesWithTax: totalSalesWithTax,
      purchasesWithoutTax: totalPurchasesWithoutTax,
      purchasesWithTax: totalPurchasesWithTax,
      grossProfit: totalGrossProfit,
      profitMargin: combinedMargin,
      netVatDue: totalNetVatDue,
      targetProfit: totalTargetProfit,
      createdAt:
          list.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b),
      createdById: 'consolidated',
      createdByName: combinedCreator,
    );
  }
}
