// screens/main_nav_screen.dart

import 'package:entryon/providers/auth_Provider.dart';
import 'package:entryon/providers/theme_provider.dart';
import 'package:entryon/utils/app_theme.dart';
import 'package:entryon/utils/responsive.dart';
import 'package:entryon/views/customersListScreen.dart';
import 'package:entryon/views/login_screen.dart';
import 'package:entryon/views/logsListScreen.dart';
import 'package:entryon/views/menuScreen.dart';
import 'package:entryon/views/profitCalculationsListScreen.dart';
import 'package:entryon/views/profitCalculatorScreen.dart';
import 'package:entryon/views/purchaseEntriesListScreen.dart';
import 'package:entryon/views/serviceTransactionsReportScreen.dart';
import 'package:entryon/views/servicesListScreen.dart';
import 'package:entryon/views/transactionListScreen.dart';
import 'package:entryon/views/usersListScreen.dart';
import 'package:entryon/views/expense_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

 

  List<_NavItemData> get _navItems => [
    _NavItemData(
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
      label: 'Customers',
    ),
    _NavItemData(
      icon: Icons.build_outlined,
      activeIcon: Icons.build_rounded,
      label: 'Services',
    ),
    _NavItemData(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Transactions',
    ),
    _NavItemData(
      icon: LucideIcons.menuSquare,
      activeIcon: LucideIcons.menuSquare,
      label: 'Entries',
    ),
    _NavItemData(
      icon: LucideIcons.walletCards,
      activeIcon: LucideIcons.walletCards,
      label: 'Expenses',
    ),
      _NavItemData(
      icon: LucideIcons.listChecks,
      activeIcon: LucideIcons.listChecks,
      label: 'Reports',
    ),
    if (context.read<AuthProvider>().currentUserName == 'Administrator')
      _NavItemData(
        icon: LucideIcons.users,
        activeIcon: LucideIcons.users,
        label: 'Users',
      ),
    if (context.read<AuthProvider>().currentUserName == 'Administrator')
      _NavItemData(
        icon: LucideIcons.fileClock,
        activeIcon: LucideIcons.fileClock,
        label: 'Logs',
      ),
      _NavItemData(
      icon: LucideIcons.layoutList,
      activeIcon: LucideIcons.layoutList
      ,
      label: 'Calculations',
    ),
    _NavItemData(
      icon: LucideIcons.layoutDashboard,
      activeIcon: LucideIcons.layoutDashboard,
      label: 'Menu',
    ),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openProfitCalculator() {
    Responsive.showAdaptiveDialog(
      context: context,
      maxWidth: 1000,
      maxHeight:850,
      child: const ProfitCalculatorScreen(),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      context.read<AuthProvider>().logout();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final List<Widget> screens = [
      CustomersListScreen(),
      ServicesListScreen(),
      TransactionsListScreen(),
      PurchaseEntriesListScreen(),
      const ExpenseListScreen(),
      ServiceTransactionReportScreen(),
      if (authProvider.currentUserName == 'Administrator') UsersListScreen(),
      if (authProvider.currentUserName == 'Administrator') LogsListScreen(),
      ProfitCalculationsListScreen(),
      MenuScreen(),
    ];
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FuturisticColors.bgVoid : Colors.grey.shade50,
      drawer: isMobile ? _buildMobileDrawer(context) : null,
      appBar: isMobile
          ? AppBar(
              backgroundColor: isDark ? FuturisticColors.bgSurface : Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(
                    Icons.menu_rounded,
                    color: isDark ? FuturisticColors.neonCyan : Colors.black87,
                  ),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              title: Row(
                children: [
                  Image.asset('assets/ic_launcher.png', width: 28, height: 28),
                  const SizedBox(width: 8),
                  Text(
                    _navItems[_currentIndex].label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? FuturisticColors.textPrimary : Colors.black87,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: isDark ? 'Classic Light' : 'Dark Futuristic',
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.nights_stay_rounded,
                    color: isDark ? FuturisticColors.neonCyan : Colors.indigo,
                  ),
                  onPressed: () => context.read<ThemeProvider>().toggleTheme(),
                ),
                IconButton(
                  tooltip: 'Profit Calculator',
                  icon: Icon(
                    LucideIcons.calculator,
                    color: isDark ? FuturisticColors.neonTeal : Colors.teal,
                  ),
                  onPressed: _openProfitCalculator,
                ),
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(LucideIcons.logOut, color: Colors.redAccent),
                  onPressed: () => _logout(context),
                ),
                const SizedBox(width: 4),
              ],
            )
          : null,
      body: Row(
        children: [
          // Desktop & Tablet Navigation Shell
          if (!isMobile)
            isTablet
                ? _buildTabletNavigationRail(context)
                : _buildDesktopSidebar(context),

          // Main View Content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),

      // Mobile Bottom Navigation Bar
      bottomNavigationBar: isMobile ? _buildMobileBottomNav(context) : null,
    );
  }

  Widget _buildMobileBottomNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuIndex = _navItems.length - 1;
    final primaryIndices = [0, 1, 2, 3, menuIndex];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? FuturisticColors.cyberBorder : Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? FuturisticColors.glowShadow
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: primaryIndices.map((targetIndex) {
              final isMenuTab = targetIndex == menuIndex;
              final item = isMenuTab
                  ? _NavItemData(
                      icon: LucideIcons.layoutGrid,
                      activeIcon: LucideIcons.layoutGrid,
                      label: 'More',
                    )
                  : _navItems[targetIndex];

              final isActive = isMenuTab
                  ? _currentIndex >= 4
                  : _currentIndex == targetIndex;

              final activeColor = isDark ? FuturisticColors.neonCyan : Colors.teal;
              final inactiveColor = isDark ? FuturisticColors.textSecondary : Colors.grey.shade600;

              return Expanded(
                child: InkWell(
                  onTap: () => _onTabTapped(targetIndex),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark
                                    ? FuturisticColors.neonCyan.withValues(alpha: 0.16)
                                    : Colors.teal.withValues(alpha: 0.12))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: isActive && isDark
                                ? Border.all(
                                    color: FuturisticColors.neonCyan.withValues(alpha: 0.4),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive ? activeColor : inactiveColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.isSmallMobile ? 10 : 11,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? activeColor : inactiveColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Desktop Sidebar ────────────────────────────────────────────────────────
  Widget _buildDesktopSidebar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 156,
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgSurface : Colors.grey.shade100,
        border: Border(
          right: BorderSide(
            color: isDark ? FuturisticColors.cyberBorder : Colors.grey.shade200,
            width: isDark ? 1.2 : 1,
          ),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(2, 0),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            // Logo & App Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  Container(
                    decoration: isDark
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: FuturisticColors.neonCyan.withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          )
                        : null,
                    child: Image.asset('assets/ic_launcher.png', width: 34, height: 34),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'EntryOn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: isDark ? FuturisticColors.textPrimary : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark ? FuturisticColors.borderSubtle : Colors.grey.shade300,
            ),
            const SizedBox(height: 10),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: List.generate(_navItems.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildSidebarItem(
                      icon: _navItems[i].icon,
                      activeIcon: _navItems[i].activeIcon,
                      label: _navItems[i].label,
                      index: i,
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 6),
            // Cyber Theme Switcher
            _buildThemeSwitcher(context, isDark),
            const SizedBox(height: 6),
                                
            _buildSidebarActionButton(
              icon: LucideIcons.calculator,
              label: 'Profit Calc',
              color: isDark ? FuturisticColors.neonTeal : Colors.teal.shade700,
              onTap: _openProfitCalculator,
            ),

            // Bottom Actions
            const SizedBox(height: 6),
            Divider(
              height: 1,
              color: isDark ? FuturisticColors.borderSubtle : Colors.grey.shade300,
            ),
            const SizedBox(height: 6),
            _buildUserIdentity(context),
            const SizedBox(height: 8),

            _buildSidebarActionButton(
              icon: LucideIcons.logOut,
              label: 'Logout',
              color: isDark ? FuturisticColors.neonCrimson : Colors.red.shade700,
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Theme Switcher Widget ──────────────────────────────────────────────────
  Widget _buildThemeSwitcher(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? FuturisticColors.cyberBorder : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: FuturisticColors.neonCyan.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.read<ThemeProvider>().toggleTheme(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                    key: ValueKey(isDark),
                    color: isDark ? FuturisticColors.neonCyan : Colors.amber.shade800,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDark ? 'Cyber Dark' : 'Classic Light',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? FuturisticColors.neonCyan : Colors.grey.shade800,
                      letterSpacing: isDark ? 0.3 : 0,
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark
                        ? FuturisticColors.neonCyan.withValues(alpha: 0.25)
                        : Colors.grey.shade400,
                    border: Border.all(
                      color: isDark ? FuturisticColors.neonCyan : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                  padding: const EdgeInsets.all(1.5),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? FuturisticColors.neonCyan : Colors.white,
                      boxShadow: isDark
                          ? [
                              const BoxShadow(
                                color: FuturisticColors.neonCyan,
                                blurRadius: 4,
                              )
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tablet Navigation Rail ──────────────────────────────────────────────────
  Widget _buildTabletNavigationRail(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgSurface : Colors.grey.shade100,
        border: Border(
          right: BorderSide(
            color: isDark ? FuturisticColors.cyberBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            decoration: isDark
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: FuturisticColors.neonCyan.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  )
                : null,
            child: Image.asset('assets/ic_launcher.png', width: 34, height: 34),
          ),
          const SizedBox(height: 12),
          Tooltip(
            message: authProvider.currentUserName,
            child: CircleAvatar(
              radius: 15,
              backgroundColor: isDark
                  ? FuturisticColors.neonCyan.withValues(alpha: 0.18)
                  : Colors.teal.withValues(alpha: 0.12),
              child: Text(
                authProvider.currentUserName.isNotEmpty
                    ? authProvider.currentUserName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: isDark ? FuturisticColors.neonCyan : Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Tablet Theme Switcher
          Tooltip(
            message: isDark ? 'Switch to Classic Light' : 'Switch to Dark Futuristic',
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.nights_stay_rounded,
                color: isDark ? FuturisticColors.neonCyan : Colors.indigo,
                size: 20,
              ),
              onPressed: () => context.read<ThemeProvider>().toggleTheme(),
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            color: isDark ? FuturisticColors.borderSubtle : Colors.grey.shade300,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _navItems.length,
              itemBuilder: (context, i) {
                final item = _navItems[i];
                final isActive = _currentIndex == i;
                return Tooltip(
                  message: item.label,
                  preferBelow: false,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Material(
                      color: isActive
                          ? (isDark
                              ? FuturisticColors.neonCyan.withValues(alpha: 0.18)
                              : Colors.teal.withValues(alpha: 0.12))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _onTabTapped(i),
                        child: Container(
                          decoration: isActive && isDark
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: FuturisticColors.neonCyan.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                )
                              : null,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive
                                ? (isDark ? FuturisticColors.neonCyan : Colors.teal)
                                : (isDark ? FuturisticColors.textSecondary : Colors.grey.shade600),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? FuturisticColors.borderSubtle : Colors.grey.shade300,
          ),
          const SizedBox(height: 6),
          Tooltip(
            message: 'Profit Calculator',
            child: IconButton(
              icon: Icon(
                LucideIcons.calculator,
                color: isDark ? FuturisticColors.neonTeal : Colors.teal,
              ),
              onPressed: _openProfitCalculator,
            ),
          ),
          Tooltip(
            message: 'Logout',
            child: IconButton(
              icon: const Icon(LucideIcons.logOut, color: Colors.redAccent),
              onPressed: () => _logout(context),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ── Mobile Drawer ──────────────────────────────────────────────────────────
  Widget _buildMobileDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? FuturisticColors.bgSurface : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Image.asset('assets/ic_launcher.png', width: 36, height: 36),
                  const SizedBox(width: 10),
                  Text(
                    'EntryOn',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? FuturisticColors.textPrimary : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(
              height: 1,
              color: isDark ? FuturisticColors.borderSubtle : Colors.grey.shade300,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ...List.generate(_navItems.length, (i) {
                    final item = _navItems[i];
                    final isActive = _currentIndex == i;
                    final activeColor = isDark ? FuturisticColors.neonCyan : Colors.teal;
                    final inactiveColor = isDark ? FuturisticColors.textSecondary : Colors.grey.shade700;

                    return ListTile(
                      leading: Icon(
                        isActive ? item.activeIcon : item.icon,
                        color: isActive ? activeColor : inactiveColor,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? activeColor : (isDark ? FuturisticColors.textPrimary : Colors.black87),
                        ),
                      ),
                      selected: isActive,
                      selectedTileColor: isDark
                          ? FuturisticColors.neonCyan.withValues(alpha: 0.12)
                          : Colors.teal.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        Navigator.pop(context);
                        _onTabTapped(i);
                      },
                    );
                  }),
                  Divider(
                    color: isDark ? FuturisticColors.borderSubtle : Colors.grey.shade300,
                  ),
                  // Theme switch tile in drawer
                  ListTile(
                    leading: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.nights_stay_rounded,
                      color: isDark ? FuturisticColors.neonCyan : Colors.indigo,
                    ),
                    title: Text(
                      isDark ? 'Classic Light Theme' : 'Dark Futuristic Theme',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? FuturisticColors.textPrimary : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.read<ThemeProvider>().toggleTheme();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      LucideIcons.calculator,
                      color: isDark ? FuturisticColors.neonTeal : Colors.teal,
                    ),
                    title: Text(
                      'Profit Calculator',
                      style: TextStyle(
                        color: isDark ? FuturisticColors.textPrimary : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openProfitCalculator();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildUserIdentity(context),
            ),
            Divider(
              height: 1,
              color: isDark ? FuturisticColors.borderSubtle : Colors.grey.shade300,
            ),
            
            ListTile(
              leading: Icon(LucideIcons.logOut, color: isDark ? FuturisticColors.neonCrimson : Colors.red),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: isDark ? FuturisticColors.neonCrimson : Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserIdentity(BuildContext context) {
    final userName = context.read<AuthProvider>().currentUserName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? FuturisticColors.bgCard : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: isDark ? Border.all(color: FuturisticColors.cyberBorder, width: 1) : null,
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.userCircle,
            color: isDark ? FuturisticColors.neonCyan : Colors.black,
            size: 20,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? FuturisticColors.textPrimary : const Color(0xFF0F172A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isDark)
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: FuturisticColors.neonTeal,
                          boxShadow: [
                            BoxShadow(color: FuturisticColors.neonTeal, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'ONLINE',
                        style: TextStyle(
                          color: FuturisticColors.neonTeal,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isActive = _currentIndex == index;

    final activeBg = isDark
        ? FuturisticColors.neonCyan.withValues(alpha: 0.16)
        : Colors.teal.withValues(alpha: 0.12);
    final activeColor = isDark ? FuturisticColors.neonCyan : Colors.teal;
    final inactiveColor = isDark ? FuturisticColors.textSecondary : Colors.grey.shade600;
    final labelInactiveColor = isDark ? FuturisticColors.textSecondary : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive && isDark
            ? Border.all(color: FuturisticColors.neonCyan.withValues(alpha: 0.4), width: 1)
            : null,
        boxShadow: isActive && isDark
            ? [
                BoxShadow(
                  color: FuturisticColors.neonCyan.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onTabTapped(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? activeColor : inactiveColor,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? activeColor : labelInactiveColor,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: isDark && isActive ? 0.2 : 0,
                    ),
                  ),
                ),
                if (isActive && isDark)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: FuturisticColors.neonCyan,
                      boxShadow: [
                        BoxShadow(color: FuturisticColors.neonCyan, blurRadius: 4),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: isDark ? Border.all(color: color.withValues(alpha: 0.3), width: 1) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}