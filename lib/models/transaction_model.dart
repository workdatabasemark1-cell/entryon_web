class TransactionModel {
  final String id;
  final String serviceId;
  final String? customerId;
  final String customerName;
  final String? branchName;
  final double amount;
  final double balanceAmount;
  final double purchaseAmount;
  final double pendingAmount;
  final String paymentType; // 'Cash' or 'Card'
  final Map<String, dynamic>? paymentDetails;
  final DateTime createdAt;
  final String addedById;
  final String addedByName;
  final String? receivedByName;
  final String? receivedById;
  final DateTime? receivedAt;

  TransactionModel({
    required this.id,
    required this.serviceId,
    this.customerId,
    required this.customerName,
    this.branchName,
    required this.amount,
    required this.balanceAmount,
    required this.purchaseAmount,
    required this.pendingAmount,
    required this.paymentType,
    this.paymentDetails,
    required this.createdAt,
    required this.addedById,
    required this.addedByName,
    this.receivedByName,
    this.receivedById,
    this.receivedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serviceId': serviceId,
      'customerId': customerId,
      'customerName': customerName,
      'branchName': branchName,
      'amount': amount,
      'balanceAmount': balanceAmount,
      'purchaseAmount': purchaseAmount,
      'pendingAmount': pendingAmount,
      'paymentType': paymentType,
      'paymentDetails': paymentDetails ?? {},
      'createdAt': createdAt.toIso8601String(),
      'addedById': addedById,
      'addedByName': addedByName,
      'receivedByName': receivedByName,
      'receivedById': receivedById,
      'receivedAt': receivedAt?.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return TransactionModel(
      id: documentId,
      serviceId: map['serviceId'] ?? '',
      customerId: map['customerId'],
      customerName: map['customerName'] ?? '',
      branchName: map['branchName'],
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      balanceAmount: (map['balanceAmount'] is num)
          ? (map['balanceAmount'] as num).toDouble()
          : 0.0,
      purchaseAmount: (map['purchaseAmount'] is num)
          ? (map['purchaseAmount'] as num).toDouble()
          : 0.0,
      pendingAmount: (map['pendingAmount'] is num)
          ? (map['pendingAmount'] as num).toDouble()
          : 0.0,
      paymentType: map['paymentType'] ?? 'Cash',
      paymentDetails: Map<String, dynamic>.from(map['paymentDetails'] ?? {}),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      addedById: map['addedById'] ?? 'Administrator',
      addedByName: map['addedByName'] ?? 'Administrator',
      receivedByName: map['receivedByName'] as String?,
      receivedById: map['receivedById'] as String?,
      receivedAt: map['receivedAt'] != null
          ? DateTime.parse(map['receivedAt'] as String)
          : null,
    );
  }
}
