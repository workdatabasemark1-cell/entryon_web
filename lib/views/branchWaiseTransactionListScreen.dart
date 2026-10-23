import 'package:flutter/material.dart';

import '../models/customer_model.dart';
import 'customerTransactionsListScreen.dart';

class BranchWaiseTransactionListScreen extends StatelessWidget {
  final Customer customer;
  final Branch branch;

  const BranchWaiseTransactionListScreen({
    super.key,
    required this.customer,
    required this.branch,
  });

  @override
  Widget build(BuildContext context) {
    return CustomerTransactionsListScreen(
      customerName: customer.name,
      customerId: customer.id,
      branchName: branch.name,
    );
  }
}
