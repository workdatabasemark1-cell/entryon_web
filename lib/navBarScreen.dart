// screens/main_nav_screen.dart

import 'package:entryon/customersListScreen.dart';
import 'package:entryon/menuScreen.dart';

import 'package:entryon/purchaseEntriesListScreen.dart';
import 'package:entryon/vatCalculationScreen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    VatCalculationScreen(),
    CustomersListScreen(),
    PurchaseEntriesListScreen(),
    MenuScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:  Colors.grey.shade50,
       

      // ── Body ──────────────────────────────────────────────────────────
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // ── FAB ────────────────────────────────────────────────────────────
      // floatingActionButton:
      //     ( _currentIndex == 1 || _currentIndex == 2)
      //         ? FloatingActionButton(
      //             onPressed: () {
      //               if (_currentIndex == 1) {
      //                 Navigator.push(
      //                   context,
      //                   MaterialPageRoute(
      //                     builder: (context) => const CreateCustomerScreen(),
      //                   ),
      //                 );
      //               } else if (_currentIndex == 2) {
      //                 Navigator.push(
      //                   context,
      //                   MaterialPageRoute(
      //                     builder: (context) => const PurchaseEntryScreen(),
      //                   ),
      //                 );
      //               } else {
      //                 Navigator.pushNamed(context, '/purchase-entry');
      //               }
      //             },
      //             backgroundColor: const Color(0xFF4F8EF7),
      //             foregroundColor: Colors.white,
      //             elevation: 4,
      //             child: const Icon(Icons.add_rounded, size: 28),
      //           )
      //         : null,

      // ── Bottom Navigation Bar (Venzo Style) ────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10,0),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 2,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(
                    icon: LucideIcons.calculator,
                    activeIcon: LucideIcons.calculator,
                    label: 'Calculator',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.people_alt_outlined,
                    activeIcon: Icons.people_alt_rounded,
                    label: 'Customers',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: LucideIcons.menuSquare,
                    activeIcon: LucideIcons.menuSquare,
                    label: 'Entries',
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: LucideIcons.layoutDashboard,
                    activeIcon: LucideIcons.layoutDashboard,
                    label: 'Menu',
                    index: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final bool isActive = _currentIndex == index;
    const activeColor = Color.fromARGB(255, 0, 0, 0);

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive ? activeColor : Colors.grey.shade500,
                size: isActive ? 28 : 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : Colors.grey.shade500,
                fontSize: isActive ? 12 : 11,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}