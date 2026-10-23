import 'package:entryon/providers/user_provider.dart';
import 'package:entryon/views/editUserDetailsScreen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';

class UserDetailsScreen extends StatelessWidget {
  final AppUser user;

  const UserDetailsScreen({super.key, required this.user});

  Color _roleColor(String role, bool isDark) {
    switch (role.toLowerCase()) {
      case 'admin':
        return isDark ? FuturisticColors.neonCyan : Colors.purple;
      default:
        return isDark ? FuturisticColors.neonTeal : Colors.teal;
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final isDark = AppTheme.isDark(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.dialogBg(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.cardBorderColor(context)),
          ),
          title: Text(
            'Delete User',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          content: Text(
            'Delete "${user.name}" (@${user.username})?',
            style: TextStyle(color: AppTheme.textSecondary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary(context)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? FuturisticColors.neonCrimson : Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final ok = await context.read<UserProvider>().deleteUser(user.id);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'User deleted'
                : (context.read<UserProvider>().errorMessage ?? 'Failed'),
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final roleColor = _roleColor(user.role, isDark);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'User Details',
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
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: AppTheme.dialogBg(context),
                insetPadding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: 500,
                  height: 540,
                  child: EditUserScreen(user: user),
                ),
              ),
            ),
            icon: Icon(
              LucideIcons.edit,
              color: isDark ? FuturisticColors.neonCyan : Colors.blue,
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
            icon: Icon(
              Icons.delete_outline,
              color: isDark ? FuturisticColors.neonCrimson : Colors.redAccent,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ── Header card ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Account info ──────────────────────────────────────────────
            _SectionCard(
              title: 'Account Information',
              child: Column(
                children: [
                  _InfoRow(label: 'Full Name', value: user.name),
                  Divider(height: 20, color: AppTheme.divider(context)),
                  _InfoRow(label: 'Username', value: user.username),
                  Divider(height: 20, color: AppTheme.divider(context)),
                  _InfoRow(label: 'Role', value: user.role.toUpperCase()),
                  if (user.id.isNotEmpty) ...[
                    Divider(height: 20, color: AppTheme.divider(context)),
                    _InfoRow(label: 'User ID', value: user.id),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Timestamps ────────────────────────────────────────────────
            if (user.createdAt != null)
              _SectionCard(
                title: 'Activity',
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Created',
                      value: DateFormat('dd MMM yyyy • HH:mm')
                          .format(user.createdAt!),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary(context),
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}