import 'package:flutter/material.dart';

import '../models/customer_model.dart';
import 'customerBasedServicesListScreen.dart';

class BranchWaiseServicesListScreen extends StatelessWidget {
  final Customer customer;
  final Branch branch;

  const BranchWaiseServicesListScreen({
    super.key,
    required this.customer,
    required this.branch,
  });

  @override
  Widget build(BuildContext context) {
    return CustomerBasedServicesListScreen(
      customer: customer,
      branchName: branch.name,
    );
  }
}
