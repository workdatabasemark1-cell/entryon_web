import 'package:flutter/material.dart';

import '../models/customer_model.dart';
import 'customerwiseMakeTransactionScreen.dart';

class BranchWaiseMakeAPaymentScreen extends StatelessWidget {
  final Customer customer;
  final Branch branch;

  const BranchWaiseMakeAPaymentScreen({
    super.key,
    required this.customer,
    required this.branch,
  });

  @override
  Widget build(BuildContext context) {
    return CustomerwiseMakeTransactionScreen(
      customer: customer,
      branchName: branch.name,
    );
  }
}
