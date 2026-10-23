import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/supplier_provider.dart';
import '../models/supplier_model.dart';
import '../utils/app_theme.dart';

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

  InputDecoration _fieldDecoration(BuildContext context, String hint) {
    final isDark = AppTheme.isDark(context);
    return InputDecoration(
      fillColor: AppTheme.inputBg(context),
      filled: true,
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? FuturisticColors.neonCyan : Colors.teal, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppTheme.textPrimary(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      body: Column(
        children: [
          AppBar(
            toolbarHeight: 55,
            scrolledUnderElevation: 0,
            leading: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(0, 0),
                          ),
                        ],
                  color: AppTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorderColor(context)),
                ),
                padding: const EdgeInsets.all(5),
                margin: const EdgeInsets.all(10),
                child: Icon(LucideIcons.x, size: 20, color: AppTheme.textPrimary(context)),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: isLoading ? null : updateSupplier,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              spreadRadius: 1,
                              offset: const Offset(0, 0),
                            ),
                          ],
                    color: isDark ? FuturisticColors.neonCyan : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorderColor(context)),
                  ),
                  padding: const EdgeInsets.all(5),
                  margin: const EdgeInsets.all(10),
                  child: Icon(LucideIcons.save, color: isDark ? FuturisticColors.bgVoid : Colors.black87),
                ),
              ),
            ],
            centerTitle: true,
            title: Text(
              'Edit Supplier',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context)),
            ),
            backgroundColor: AppTheme.surfaceBg(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier Name
                    _buildLabel(context, 'Supplier Name *'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                      decoration: _fieldDecoration(context, 'e.g. ABC Supplies'),
                    ),
                    const SizedBox(height: 16),

                    // VAT Number
                    _buildLabel(context, 'VAT Number *'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: vatController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                      decoration: _fieldDecoration(context, 'e.g. 311146161700003'),
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    _buildLabel(context, 'Phone Number *'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                      decoration: _fieldDecoration(context, 'e.g. +966 50 000 0000'),
                    ),
                    const SizedBox(height: 16),

                    // Address (Optional)
                    _buildLabel(context, 'Address (Optional)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                      decoration: _fieldDecoration(context, 'Street, City, Region'),
                    ),
                    const SizedBox(height: 16),

                    // Email (Optional)
                    _buildLabel(context, 'Email (Optional)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13),
                      decoration: _fieldDecoration(context, 'supplier@example.com'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
