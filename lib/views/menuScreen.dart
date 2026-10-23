import 'package:entryon/providers/auth_Provider.dart';
import 'package:entryon/providers/theme_provider.dart';
import 'package:entryon/utils/app_theme.dart';
import 'package:entryon/utils/responsive.dart';
import 'package:entryon/views/changeUserIdPasswordScreen.dart';
import 'package:entryon/views/createCustomerScreen.dart';
import 'package:entryon/views/createSectionScreen.dart';
import 'package:entryon/views/createSupplierScreen.dart';
import 'package:entryon/views/createUserScreen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:entryon/views/servicesListScreen.dart';
import 'package:provider/provider.dart';
import 'profitCalculationsListScreen.dart';
import 'purchaseEntryScreen.dart';
import 'expense_entry_screen.dart';
import 'expense_list_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  int _getColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 650) return 1;
    if (width < 1100) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FuturisticColors.bgVoid : Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        title: Text(
          "Entryon Menu",
          style: TextStyle(
            color: isDark ? FuturisticColors.textPrimary : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
            letterSpacing: isDark ? 0.3 : 0,
          ),
        ),
        backgroundColor: isDark ? FuturisticColors.bgSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: isDark
                ? 'Switch to Classic Light'
                : 'Switch to Dark Futuristic',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.nights_stay_rounded,
              color: isDark ? FuturisticColors.neonCyan : Colors.indigo,
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- MENU GRID ---
            Expanded(
              child: GridView.count(
                crossAxisCount: _getColumns(context),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 56,
                children: [
                  _menuCustomButton(
                    context,
                    title: isDark
                        ? "Theme: Cyber Dark"
                        : "Theme: Classic Light",
                    child: Icon(
                      isDark
                          ? Icons.nights_stay_rounded
                          : Icons.wb_sunny_rounded,
                      color: isDark
                          ? FuturisticColors.neonCyan
                          : Colors.amber.shade800,
                      size: 20,
                    ),
                    color: isDark ? FuturisticColors.neonCyan : Colors.amber,
                    onTap: () {
                      context.read<ThemeProvider>().toggleTheme();
                    },
                  ),
                  _menuCustomButton(
                    context,
                    title: "Create Section",
                    child: Icon(
                      LucideIcons.calendarRange,
                      color: isDark ? FuturisticColors.neonCyan : Colors.black,
                      size: 20,
                    ),
                    color: isDark ? FuturisticColors.neonCyan : Colors.grey,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PeriodSectionsScreen(),
                        ),
                      );
                    },
                  ),
                  _menuCustomButton(
                    context,
                    title: "Profit Calculations",
                    child: Icon(
                      LucideIcons.calculator,
                      color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                      size: 20,
                    ),
                    color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfitCalculationsListScreen(),
                        ),
                      );
                    },
                  ),
                  _menuButton(
                    context,
                    title: "Create Purchase",
                    icon: Icons.add_shopping_cart,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PurchaseEntryScreen(),
                        ),
                      );
                    },
                  ),
                  _menuButton(
                    context,
                    title: "Create Expense",
                    icon: Icons.receipt_long_rounded,
                    color: Colors.amber.shade800,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExpenseEntryScreen(),
                        ),
                      );
                    },
                  ),
                  _menuButton(
                    context,
                    title: "Expenses List",
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.cyan.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExpenseListScreen(),
                        ),
                      );
                    },
                  ),

                  _menuButton(
                    context,
                    title: "Create Customer",
                    icon: Icons.list_alt_rounded,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateCustomerScreen(),
                        ),
                      );
                    },
                  ),

                  _menuButton(
                    context,
                    title: "Create Supplier",
                    icon: Icons.store,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateSupplierScreen(),
                        ),
                      );
                    },
                  ),

                  _menuButton(
                    context,
                    title: "Services",
                    icon: Icons.build,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ServicesListScreen(),
                        ),
                      );
                    },
                  ),

                  _menuButton(
                    context,
                    title: "Create Users Screen",
                    icon: Icons.bar_chart,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateUserScreen(),
                        ),
                      );
                    },
                  ),
                  authProvider.currentUserName == 'Administrator'
                      ? _menuButton(
                          context,
                          title: "Change UserId & Password ",
                          icon: Icons.bar_chart,
                          color: Colors.orange,
                          onTap: () {
                            _showPasswordGate(context);
                          },
                        )
                      : Container(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPasswordGate(BuildContext context) async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Enter Password',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter your current password to continue',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.teal,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.teal,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      // handled by button
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final auth = context.read<AuthProvider>();

                    // Check against current stored password
                    // We verify by trying login logic without logging out
                    if (passwordController.text == auth.masterPassword) {
                      Navigator.pop(dialogContext, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Incorrect password'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true && context.mounted) {
      Responsive.showAdaptiveDialog(
        context: context,
        maxWidth: 600,
        maxHeight: 750,
        child: const EditCredentialsScreen(),
      );
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => const ReportsScreen(),
      //   ),
      // );
    }
  }

  // --- MENU BUTTON WIDGET ---
  Widget _menuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? FuturisticColors.bgCard : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isDark
              ? Border.all(color: FuturisticColors.borderSubtle, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 35,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: color.withValues(alpha: isDark ? 0.22 : 0.15),
                      border: isDark
                          ? Border.all(
                              color: color.withValues(alpha: 0.35),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Center(child: Icon(icon, color: color, size: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.start,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? FuturisticColors.textPrimary
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right,
              color: isDark
                  ? FuturisticColors.textSecondary
                  : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCustomButton(
    BuildContext context, {
    required String title,
    required Widget child,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? FuturisticColors.bgCard : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isDark
              ? Border.all(color: FuturisticColors.borderSubtle, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 35,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: color.withValues(alpha: isDark ? 0.22 : 0.15),
                      border: isDark
                          ? Border.all(
                              color: color.withValues(alpha: 0.35),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Center(child: child),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.start,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? FuturisticColors.textPrimary
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right,
              color: isDark
                  ? FuturisticColors.textSecondary
                  : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
