import 'package:entryon/createCustomerScreen.dart';
import 'package:entryon/createSectionScreen.dart';
import 'package:entryon/createSupplierScreen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'purchaseEntryScreen.dart';



class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(centerTitle: true,

        title: const Text("Entryon Menu",style: TextStyle(color: Colors.black,fontWeight: FontWeight.w600,fontSize:22),),
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Main Menu",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // --- MENU GRID ---
            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 5,
                children: [
 _menuCustomButton(
                    context,
                    title: "Create Section",
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                      Icon(LucideIcons.calendarRange, color: Colors.black, size: 30),]
                    ),
                    color: Colors.grey,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PeriodSectionsScreen(),
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

                 

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MENU BUTTON WIDGET ---
  Widget _menuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: color.withOpacity(0.15),
                    ),
                    child: Center(child: Icon(icon, color: color, size: 30)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_right, color: Colors.grey.shade400)
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: color.withOpacity(0.15),
                    ),
                    child: Center(child: child),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_right, color: Colors.grey.shade400)
          ],
        ),
      ),
    );
  }

}

