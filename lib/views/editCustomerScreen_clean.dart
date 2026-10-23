import 'package:flutter/material.dart';
import 'createCustomerScreen.dart';
import '../models/customer_model.dart';

class EditCustomerScreen extends StatelessWidget {
  final Customer customer;

  const EditCustomerScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    // Reuse CreateCustomerScreen with customer for edit mode
    return CreateCustomerScreen(customer: customer);
  }
}
