import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/customer_provider.dart';
import 'providers/supplier_provider.dart';
import 'models/customer_model.dart';

class CreateSupplierScreen extends StatefulWidget {
  const CreateSupplierScreen({super.key});

  @override
  State<CreateSupplierScreen> createState() => _CreateSupplierScreenState();
}

class _CreateSupplierScreenState extends State<CreateSupplierScreen> {
  late TextEditingController nameController;
  late TextEditingController vatController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController emailController;

  Customer? selectedCustomer;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    vatController = TextEditingController();
    phoneController = TextEditingController();
    addressController = TextEditingController();
    emailController = TextEditingController();

    // Fetch customers on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    vatController.dispose();
    phoneController.dispose();
    addressController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> addSupplier() async {
    // Validation
    if (selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter supplier name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (vatController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter VAT number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final success = await context.read<SupplierProvider>().addSupplier(
      
        name: nameController.text.trim(),
        vatNumber: vatController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        email: emailController.text.trim(),
      );

      setState(() => isLoading = false);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh suppliers list for the selected customer
          await context.read<SupplierProvider>().fetchSuppliers(
               
              );
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.grey.shade50,
      appBar: AppBar(centerTitle: true,
        title: const Text('Add New Supplier',style: TextStyle(color: Colors.black,fontWeight: FontWeight.w500,fontSize: 20),),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Selection
                  // const Text(
                  //   'Select Customer *',
                  //   style: TextStyle(
                  //     fontWeight: FontWeight.w600,
                  //     fontSize: 14,
                  //     color: Colors.black87,
                  //   ),
                  // ),
                  // const SizedBox(height: 8),
                  // Consumer<CustomerProvider>(
                  //   builder: (context, customerProvider, _) {
                  //     final customers = customerProvider.customers;
            
                  //     if (customers.isEmpty) {
                  //       return Container(
                  //         padding: const EdgeInsets.all(16),
                  //         decoration: BoxDecoration(
                  //           border: Border.all(color: Colors.grey.shade300),
                  //           borderRadius: BorderRadius.circular(8),
                  //           color: Colors.grey.shade50,
                  //         ),
                  //         child: const Text(
                  //           'No customers available. Please create a customer first.',
                  //           style: TextStyle(
                  //             color: Colors.orange,
                  //             fontSize: 13,
                  //           ),
                  //         ),
                  //       );
                  //     }
            
                  //     return Container(
                  //       decoration: BoxDecoration(
                  //         border: Border.all(color: Colors.grey.shade300),
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //       child: DropdownButton<Customer>(
                  //         value: selectedCustomer,
                  //         isExpanded: true,
                  //         underline: const SizedBox(),
                  //         padding: const EdgeInsets.symmetric(horizontal: 12),
                  //         items: customers.map((customer) {
                  //           return DropdownMenuItem<Customer>(
                  //             value: customer,
                  //             child: Row(
                  //               children: [
                  //                 CircleAvatar(
                  //                   radius: 16,
                  //                   backgroundColor: Colors.blue.shade700,
                  //                   child: Text(
                  //                     customer.name[0].toUpperCase(),
                  //                     style: const TextStyle(
                  //                       color: Colors.white,
                  //                       fontWeight: FontWeight.bold,
                  //                       fontSize: 12,
                  //                     ),
                  //                   ),
                  //                 ),
                  //                 const SizedBox(width: 12),
                  //                 Expanded(
                  //                   child: Column(
                  //                     crossAxisAlignment: CrossAxisAlignment.start,
                  //                     children: [
                  //                       Text(
                  //                         customer.name,
                  //                         style: const TextStyle(
                  //                           fontWeight: FontWeight.w500,
                  //                         ),
                  //                       ),
                  //                       Text(
                  //                         customer.phone,
                  //                         style: TextStyle(
                  //                           fontSize: 12,
                  //                           color: Colors.grey.shade600,
                  //                         ),
                  //                       ),
                  //                     ],
                  //                   ),
                  //                 ),
                  //               ],
                  //             ),
                  //           );
                  //         }).toList(),
                  //         onChanged: (customer) {
                  //           setState(() => selectedCustomer = customer);
                  //         },
                  //       ),
                  //     );
                  //   },
                  // ),
                  // if (selectedCustomer != null) ...[
                  //   const SizedBox(height: 4),
                  //   Padding(
                  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  //     child: Row(
                  //       children: [
                  //         Icon(Icons.check_circle,
                  //             size: 16, color: Colors.green.shade700),
                  //         const SizedBox(width: 8),
                  //         Text(
                  //           'Selected: ${selectedCustomer!.name}',
                  //           style: TextStyle(
                  //             fontSize: 12,
                  //             color: Colors.green.shade700,
                  //             fontWeight: FontWeight.w500,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ],
                  // const SizedBox(height: 24),
            
                  // Supplier Name
                  const Text(
                    'Supplier Name *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(fillColor: Colors.white,filled: true,
                      hintText: 'e.g. ABC Supplies',
                      prefixIcon: const Icon(Icons.business),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade500,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
            
                  // VAT Number
                  const Text(
                    'VAT Number *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: vatController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(fillColor: Colors.white,filled: true,
                      hintText: 'e.g. 311146161700003',
                      prefixIcon: const Icon(Icons.receipt),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade500,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
            
                  // Phone Number
                  const Text(
                    'Phone Number *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(fillColor: Colors.white,filled: true,
                      hintText: 'e.g. +966 50 000 0000',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade500,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
            
                  // Address (Optional)
                  const Text(
                    'Address (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      hintText: 'Street, City, Region',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade500,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
            
                  // Email (Optional)
                  const Text(
                    'Email (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(fillColor: Colors.white,filled: true,
                      hintText: 'supplier@example.com',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade500,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                 
            
                  // Save Button
                  
                ],
              ),
            ),
          ),
           SafeArea(
             child: Padding(
               padding: const EdgeInsets.all(8.0),
               child: Row(
                  children: [
                    
                    // Cancel Button
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(backgroundColor: Colors.white,
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
               
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : addSupplier,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            isLoading ? 'Saving...' : 'Save Supplier',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                  ],
                ),
             ),
           ),
           
        ],
      ),
    );
  }
}
