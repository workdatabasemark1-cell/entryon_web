import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/supplier_provider.dart';
import 'models/supplier_model.dart';

class EditSupplierScreen extends StatefulWidget {
  final Supplier supplier;

  const EditSupplierScreen({super.key, required this.supplier});

  @override
  State<EditSupplierScreen> createState() => _EditSupplierScreenState();
}

class _EditSupplierScreenState extends State<EditSupplierScreen> {
  late TextEditingController nameController;
  late TextEditingController vatController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController emailController;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.supplier.name);
    vatController = TextEditingController(text: widget.supplier.vatNumber);
    phoneController = TextEditingController(text: widget.supplier.phone);
    addressController = TextEditingController(text: widget.supplier.address ?? '');
    emailController = TextEditingController(text: widget.supplier.email ?? '');
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

  Future<void> updateSupplier() async {
    // Validation
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
      final success = await context.read<SupplierProvider>().updateSupplier(
        id: widget.supplier.id!,
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
              content: Text('Supplier updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await context.read<SupplierProvider>().fetchSuppliers();
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
    return Scaffold(backgroundColor: Colors.grey.shade100,
      appBar: AppBar(centerTitle: true,
        title: const Text('Edit Supplier'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              decoration: InputDecoration(
                hintText: 'e.g. ABC Supplies',
                prefixIcon: const Icon(Icons.business),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

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
              decoration: InputDecoration(
                hintText: 'e.g. 311146161700003',
                prefixIcon: const Icon(Icons.receipt),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

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
              decoration: InputDecoration(
                hintText: 'e.g. +966 50 000 0000',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                hintText: 'Street, City, Region',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

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
              decoration: InputDecoration(
                hintText: 'supplier@example.com',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Update Button
            Row(
              children: [
              
                
                // Cancel Button
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
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
                      onPressed: isLoading ? null : updateSupplier,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        isLoading ? 'Updating...' : 'Update',
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
