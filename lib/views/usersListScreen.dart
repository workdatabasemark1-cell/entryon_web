import 'package:entryon/providers/user_provider.dart';
import 'package:entryon/utils/responsive.dart';
import 'package:entryon/views/createUserScreen.dart';
import 'package:entryon/views/usersDetailsScreen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';


class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _filteredUsers(List<AppUser> users) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return users;
    return users.where((u) {
      return u.name.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.role.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _confirmDelete(AppUser user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
          ),
          content: Text(
            'Delete "${user.name}" (@${user.username})?',
            style: TextStyle(color: AppTheme.textSecondary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(context))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? FuturisticColors.neonCrimson : Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final ok = await context.read<UserProvider>().deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'User deleted' : (context.read<UserProvider>().errorMessage ?? 'Failed')),
          backgroundColor: ok
              ? (isDark ? FuturisticColors.neonTeal : Colors.green)
              : (isDark ? FuturisticColors.neonCrimson : Colors.red),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _roleColor(String role, bool isDark) {
    switch (role.toLowerCase()) {
      case 'admin':
        return isDark ? FuturisticColors.neonViolet : Colors.purple;
      default:
        return isDark ? FuturisticColors.neonCyan : Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          'Users',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppTheme.textPrimary(context),
          ),
        ),
        backgroundColor: AppTheme.surfaceBg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.accent(context)),
            tooltip: 'Refresh',
            onPressed: () => context.read<UserProvider>().fetchUsers(),
          ),
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? FuturisticColors.neonCyan.withOpacity(0.12)
                      : Colors.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                  ),
                ),
                child: GestureDetector(
                  onTap: () async {
                    await Responsive.showAdaptiveDialog(
                      context: context,
                      maxWidth: 540,
                      maxHeight: 520,
                      child: const CreateUserScreen(),
                    );
                    if (mounted) {
                      context.read<UserProvider>().fetchUsers();
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add_alt_1,
                        color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add User',
                        style: TextStyle(
                          color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Responsive.showAdaptiveDialog(
                  context: context,
                  maxWidth: 540,
                  maxHeight: 520,
                  child: const CreateUserScreen(),
                );
                if (mounted) {
                  context.read<UserProvider>().fetchUsers();
                }
              },
              backgroundColor: isDark ? FuturisticColors.neonCyan : Colors.teal,
              foregroundColor: isDark ? FuturisticColors.bgVoid : Colors.white,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Add User', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: AppTheme.textPrimary(context)),
              decoration: InputDecoration(
                hintText: 'Search by name, username or role',
                hintStyle: TextStyle(color: AppTheme.textSecondary(context)),
                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary(context)),
                filled: true,
                fillColor: AppTheme.inputBg(context),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
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
                  borderSide: BorderSide(color: AppTheme.accent(context)),
                ),
              ),
            ),
            const SizedBox(height: 8),
        
            Expanded(
              child: Consumer<UserProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.users.isEmpty) {
                    return Center(child: CircularProgressIndicator(color: AppTheme.accent(context)));
                  }
        
                  final filtered = _filteredUsers(provider.users);
        
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 70, color: AppTheme.textSecondary(context)),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }
        
                  return Column(
                    children: [
                     Expanded(
  child: LayoutBuilder(
    builder: (context, constraints) {
      // Dynamically decide number of columns based on width
      int crossAxisCount = constraints.maxWidth > 900
          ? 3
          : constraints.maxWidth > 600
              ? 2
              : 1;

      return GridView.builder(
        itemCount: filtered.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 70, // Adjust height ratio
        ),
        itemBuilder: (context, index) {
          final user = filtered[index];
          final roleColor = _roleColor(user.role, isDark);

          return InkWell(
            onTap: () => Responsive.showAdaptiveDialog(
              context: context,
              maxWidth: 480,
              maxHeight: 520,
              child: UserDetailsScreen(user: user),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
            
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '@${user.username}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            
                  // Role chip
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          
                          // Delete
                         InkWell(
                           onTap: () {
                             _confirmDelete(user);
                           },
                           child: Icon(
                             Icons.delete_outline,
                             color: isDark ? FuturisticColors.neonCrimson : Colors.redAccent,
                           ),
                         ),
                        ],
                      ),
                    if (user.createdAt != null) ...[
                           const SizedBox(height: 4),
                          Text(
                            'Added: ${DateFormat('dd MMM yyyy').format(user.createdAt!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ),
),

        
                      // Bottom count
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBg(context),
                          border: Border(top: BorderSide(color: AppTheme.cardBorderColor(context))),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Total Users: ${filtered.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}