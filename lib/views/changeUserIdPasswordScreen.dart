import 'package:entryon/providers/auth_Provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';

class EditCredentialsScreen extends StatefulWidget {
  const EditCredentialsScreen({super.key});

  @override
  State<EditCredentialsScreen> createState() => _EditCredentialsScreenState();
}

class _EditCredentialsScreenState extends State<EditCredentialsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newUsernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    _newUsernameController.text = auth.currentUsername;
  });
}

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newUsernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final success = await auth.updateCredentials(
      currentPassword: _currentPasswordController.text,
      newUsername: _newUsernameController.text.trim(),
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credentials updated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to update'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final isDark = AppTheme.isDark(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
      prefixIcon: Icon(
        icon,
        color: isDark ? FuturisticColors.neonCyan : Colors.teal,
        size: 22,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppTheme.inputBg(context),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.cardBorderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? FuturisticColors.neonCyan : Colors.teal,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? FuturisticColors.neonCrimson : Colors.red,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Edit Login Credentials',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTheme.textPrimary(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? FuturisticColors.bgSurface : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? FuturisticColors.cyberBorder : Colors.teal.shade100,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isDark ? FuturisticColors.neonCyan : Colors.teal.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter your current password to change username or password.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.textSecondary(context) : Colors.teal.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Form card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(16),
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
                    // Current password
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      style: TextStyle(color: AppTheme.textPrimary(context)),
                      decoration: _inputDecoration(
                        context: context,
                        label: 'Current Password *',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureCurrent
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppTheme.textSecondary(context),
                            size: 22,
                          ),
                          onPressed: () =>
                              setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter current password';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),
                    Divider(color: AppTheme.divider(context)),
                    const SizedBox(height: 8),

                    // New username
                    TextFormField(
                      controller: _newUsernameController,
                      style: TextStyle(color: AppTheme.textPrimary(context)),
                      decoration: _inputDecoration(
                        context: context,
                        label: 'New Username *',
                        icon: Icons.person_outline,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Username cannot be empty';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // New password
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      style: TextStyle(color: AppTheme.textPrimary(context)),
                      decoration: _inputDecoration(
                        context: context,
                        label: 'New Password *',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppTheme.textSecondary(context),
                            size: 22,
                          ),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter new password';
                        }
                        if (v.length < 4) {
                          return 'At least 4 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Confirm password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      style: TextStyle(color: AppTheme.textPrimary(context)),
                      decoration: _inputDecoration(
                        context: context,
                        label: 'Confirm New Password *',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppTheme.textSecondary(context),
                            size: 22,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? FuturisticColors.neonCyan : Colors.teal,
                    foregroundColor: isDark ? FuturisticColors.bgVoid : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: (isDark ? FuturisticColors.neonCyan : Colors.teal).withValues(alpha: 0.3),
                  ),
                  child: auth.isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: isDark ? FuturisticColors.bgVoid : Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}