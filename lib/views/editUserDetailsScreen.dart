import 'package:entryon/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';

class EditUserScreen extends StatefulWidget {
  final AppUser user;

  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _currentPasswordController;

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late String _role;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _usernameController = TextEditingController(text: widget.user.username);
    _currentPasswordController = TextEditingController(text: widget.user.password);
    _role = widget.user.role == 'admin' ? 'admin' : 'staff';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await context.read<UserProvider>().updateUser(
          id: widget.user.id,
          name: _nameController.text.trim(),
          username: _usernameController.text.trim(),
          role: _role,
          password: _passwordController.text.isEmpty
              ? null
              : _passwordController.text,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<UserProvider>().errorMessage ?? 'Failed to update user',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  InputDecoration _decoration(BuildContext context, String label, {Widget? suffix}) {
    final isDark = AppTheme.isDark(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
      filled: true,
      fillColor: AppTheme.inputBg(context),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? FuturisticColors.neonCyan : Colors.teal,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Edit User',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTheme.textPrimary(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? FuturisticColors.bgVoid : Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Update'),
              style: TextButton.styleFrom(
                backgroundColor: isDark ? FuturisticColors.neonCyan : Colors.teal,
                foregroundColor: isDark ? FuturisticColors.bgVoid : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: AppTheme.textPrimary(context)),
                    decoration: _decoration(context, 'Full Name *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameController,
                    style: TextStyle(color: AppTheme.textPrimary(context)),
                    decoration: _decoration(context, 'Username *'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().toLowerCase() == 'admin') {
                        return 'Username "admin" is reserved';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscurePassword,
                    readOnly: true,
                    style: TextStyle(color: AppTheme.textPrimary(context)),
                    decoration: _decoration(
                      context,
                      'Current Password',
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textSecondary(context),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length < 4) {
                        return 'Min 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: AppTheme.textPrimary(context)),
                    decoration: _decoration(
                      context,
                      'New Password (optional)',
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textSecondary(context),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length < 4) {
                        return 'Min 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    style: TextStyle(color: AppTheme.textPrimary(context)),
                    decoration: _decoration(
                      context,
                      'Confirm New Password',
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textSecondary(context),
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (_passwordController.text.isNotEmpty &&
                          v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    dropdownColor: AppTheme.cardBg(context),
                    style: TextStyle(color: AppTheme.textPrimary(context)),
                    decoration: _decoration(context, 'Role'),
                    items: [
                      DropdownMenuItem(
                        value: 'staff',
                        child: Text(
                          'Staff',
                          style: TextStyle(color: AppTheme.textPrimary(context)),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text(
                          'Admin',
                          style: TextStyle(color: AppTheme.textPrimary(context)),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? 'staff'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Leave password fields empty to keep the current password.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}