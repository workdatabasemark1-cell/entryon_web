import 'package:cloud_firestore/cloud_firestore.dart';

class ServicePurchaseLine {
  final String id;
  final String purchaseName;
  final double cost;

  ServicePurchaseLine({
    required this.id,
    required this.purchaseName,
    required this.cost,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'purchaseName': purchaseName,
        'cost': cost,
      };

  factory ServicePurchaseLine.fromMap(Map<String, dynamic> map, String id) {
    return ServicePurchaseLine(
      id: id,
      purchaseName: map['purchaseName'] ?? '',
      cost: (map['cost'] is num) ? (map['cost'] as num).toDouble() : 0.0,
    );
  }
}

class ServiceEntry {
  final String id;
  // final String serviceCode;
  final String title;
  final String customerName;
  final String? customerId;
  final String? branchName;
  final String? staffName;
  final String? staffPhone;
  final String? softwareName;
  final String? description;
  final DateTime serviceDate;
  final double amount;
  final double serviceFee;
  final double customerPaidAmount;
  final double balanceAmount;
  final String paymentStatus;
  final String serviceStatus;
  final String paymentType;
  final DateTime? paymentExpiryDate;
  final List<ServicePurchaseLine> purchaseLines;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? addedById;
  final String? addedByName;
  final String? editedById;
  final String? editedByName;

  static double calculateTotalAmount({
    required List<ServicePurchaseLine> purchaseLines,
    required double serviceCost,
  }) {
    final purchaseTotal = purchaseLines.fold<double>(0.0, (sum, line) => sum + line.cost);
    return purchaseTotal + serviceCost;
  }

  ServiceEntry({
    required this.id,
    // required this.serviceCode,
    required this.title,
    required this.customerName,
    this.customerId,
    this.branchName,
    this.staffName,
    this.staffPhone,
    this.softwareName,
    this.description,
    required this.serviceDate,
    required this.amount,
    this.serviceFee = 0.0,
    this.customerPaidAmount = 0.0,
    this.balanceAmount = 0.0,
    this.paymentStatus = 'Pending',
    this.serviceStatus = 'Pending',
    this.paymentType = 'Cash',
    this.paymentExpiryDate,
    this.purchaseLines = const [],
    this.createdAt,
    this.updatedAt,
    this.addedById,
    this.addedByName,
    this.editedById,
    this.editedByName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // 'serviceCode': serviceCode,
      'title': title,
      'customerName': customerName,
      'customerId': customerId,
      'branchName': branchName,
      'staffName': staffName,
      'staffPhone': staffPhone,
      'softwareName': softwareName,
      'description': description,
      'serviceDate': Timestamp.fromDate(serviceDate),
      'amount': amount,
      'serviceFee': serviceFee,
      'customerPaidAmount': customerPaidAmount,
      'balanceAmount': balanceAmount,
      'paymentStatus': paymentStatus,
      'serviceStatus': serviceStatus,
      'paymentType': paymentType,
      'paymentExpiryDate': paymentExpiryDate != null ? Timestamp.fromDate(paymentExpiryDate!) : null,
      'purchaseLines': purchaseLines.map((line) => line.toMap()).toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'addedById': addedById,
      'addedByName': addedByName,
      'editedById': editedById,
      'editedByName': editedByName,
    }..removeWhere((_, value) => value == null);
  }

  factory ServiceEntry.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final purchaseLines = (map['purchaseLines'] as List<dynamic>? ?? [])
        .asMap()
        .entries
        .map((entry) => ServicePurchaseLine.fromMap(entry.value as Map<String, dynamic>, entry.key.toString()))
        .toList();

    return ServiceEntry(
      id: documentId,
      // serviceCode: map['serviceCode'] ?? '',
      title: map['title'] ?? '',
      customerName: map['customerName'] ?? '',
      customerId: map['customerId'],
      branchName: map['branchName'],
      staffName: map['staffName'],
      staffPhone: map['staffPhone'],
      softwareName: map['softwareName'],
      description: map['description'],
      serviceDate: parseDate(map['serviceDate']),
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      serviceFee: (map['serviceFee'] is num) ? (map['serviceFee'] as num).toDouble() : 0.0,
      customerPaidAmount: (map['customerPaidAmount'] is num) ? (map['customerPaidAmount'] as num).toDouble() : 0.0,
      balanceAmount: (map['balanceAmount'] is num) ? (map['balanceAmount'] as num).toDouble() : 0.0,
      paymentStatus: map['paymentStatus'] ?? 'Pending',
      serviceStatus: map['serviceStatus'] ?? 'Pending',
      paymentType: map['paymentType'] ?? 'Cash',
      paymentExpiryDate: map['paymentExpiryDate'] != null ? parseDate(map['paymentExpiryDate']) : null,
      purchaseLines: purchaseLines,
      createdAt: map['createdAt'] != null ? parseDate(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      addedById: map['addedById'],
      addedByName: map['addedByName'],
      editedById: map['editedById'],
      editedByName: map['editedByName'],
    );
  }
}
