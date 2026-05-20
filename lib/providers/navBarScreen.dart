// // lib/views/screens/nav_bar_screen.dart
// import 'dart:convert';

// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:venzo/controllers/authProvider/authProvider.dart';
// import 'package:venzo/controllers/profileImagePickerController/profileImagePickerController.dart';
// import 'package:venzo/controllers/themeProvider.dart/themeProvider.dart';
// import 'package:venzo/loginScreen/loginScreen.dart';
// import 'package:venzo/views/productScreen/productScreen.dart';
// import 'package:venzo/views/reportsScreen.dart';
// import 'package:venzo/views/settingsScreen/settingsScreen.dart';
// import 'package:venzo/views/transactionListScreen.dart';
// import 'package:lucide_icons_flutter/lucide_icons.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:liquid_glass_ui_design/liquid_glass_ui.dart';
// import 'package:venzo/views/vendorScreen/profileImgPicker.dart';
// import 'package:venzo/views/vendorScreen/purchasesListScreen.dart';
// import 'package:venzo/views/vendorScreen/vendorListScreen.dart';

// class NavBarScreen extends StatefulWidget {
//   const NavBarScreen({super.key});

//   @override
//   State<NavBarScreen> createState() => _NavBarScreenState();
// }

// class _NavBarScreenState extends State<NavBarScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   int _selectedIndex = 0;

//   // Screens List
//   late final List<Widget> _screens;
//   Map<String, dynamic> _userData = {};
//   @override
//   void initState() {
//     super.initState();
//     // Pre-load vendors when app opens
//     // Provider.of<VendorController>(context, listen: false).loadVendors();
//     _loadUserData();
//     _screens = [
//       const VendorsListScreen(),
//       const PurchasesListScreen(),
//       ProductsScreen(), // We'll build this next
//       const ReportScreen(), // Outstanding, Pending Receiving, etc.
//       const SettingsScreen(),
//     ];
//   }

//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userJson = prefs.getString('user_data');
//     if (userJson != null) {
//       setState(() {
//         _userData = json.decode(userJson);
//       });
//     }
//   }

//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isArabic = Localizations.localeOf(context).languageCode == 'ar';
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);

//     return Directionality(
//       textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
//       child: Scaffold(
//         key: _scaffoldKey,
//         backgroundColor: Colors.transparent,
//         extendBodyBehindAppBar: true,
//         extendBody: true,
//         drawer: Drawer(
//           backgroundColor: Colors.transparent,
//           child: SafeArea(
//             child: GlassContainer(
//               blurStrength: 10,
//               margin: const EdgeInsets.all(8),
//               padding: const EdgeInsets.all(16),
//               borderRadius: 24,
//               child: Column(
//                 children: [
//                   Expanded(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Expanded(
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.start,
//                             children: [
//                               const SizedBox(height: 40),
//                               ProfileImagePicker(),
//                               const SizedBox(height: 20),
//                               Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   GlassContainer(
//                                     margin: EdgeInsets.zero,
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 20,
//                                       vertical: 12,
//                                     ),
//                                     borderRadius: 20,
//                                     surfaceOpacity: 0.15,
//                                     child: Center(
//                                       child: Text(
//                                         'Logged in as ${_userData['userType'] ?? 'User'}',
//                                         style: TextStyle(
//                                           fontFamily: 'SF Pro',
//                                           color: themeProvider.themeTextColor
//                                               .withOpacity(0.9),
//                                           fontSize: 14,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 16),
//                               Text(
//                                 _userData['name'] ?? 'User',
//                                 style: TextStyle(
//                                   fontFamily: 'SF Pro',
//                                   fontSize: 28,
//                                   fontWeight: FontWeight.w700,
//                                   color: themeProvider.themeTextColor,
//                                 ),
//                               ),
//                               const SizedBox(height: 12),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.email_outlined,
//                                     color: themeProvider.themeTextColor
//                                         .withOpacity(0.8),
//                                     size: 20,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Flexible(
//                                     child: Text(
//                                       _userData['email'] ?? 'user@gmail.com',
//                                       style: TextStyle(
//                                         fontFamily: 'SF Pro',
//                                         color: themeProvider.themeTextColor
//                                             .withOpacity(0.8),
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 12),
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.phone_outlined,
//                                     color: themeProvider.themeTextColor
//                                         .withOpacity(0.8),
//                                     size: 20,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Text(
//                                     _userData['phoneNumber'] ??
//                                         '+966 000-000-0000',
//                                     style: TextStyle(
//                                       fontFamily: 'SF Pro',
//                                       color: themeProvider.themeTextColor
//                                           .withOpacity(0.8),
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 24),
//                             ],
//                           ),
//                         ),

//                         // Company Info
//                         Column(
//                           children: [
//                             Text(
//                               _userData['companyName'] ?? 'Company Name',
//                               style: TextStyle(
//                                 fontFamily: 'SF Pro',
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.w700,
//                                 color: themeProvider.themeTextColor,
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               _userData['companyAddress'] ??
//                                   'Company Address', // You can add address in Firestore later
//                               style: TextStyle(
//                                 fontFamily: 'SF Pro',
//                                 fontSize: 16,
//                                 color: themeProvider.themeTextColor.withOpacity(
//                                   0.8,
//                                 ),
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                             const SizedBox(height: 12),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.phone,
//                                   color: themeProvider.themeTextColor
//                                       .withOpacity(0.9),
//                                   size: 20,
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Text(
//                                   _userData['companyPhone'] ??
//                                       '+1 000-000-0000',
//                                   style: TextStyle(
//                                     fontFamily: 'SF Pro',
//                                     fontSize: 16,
//                                     color: themeProvider.themeTextColor
//                                         .withOpacity(0.9),
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                             const SizedBox(height: 12),
//                             Text(
//                               "GST No: ${_userData['gstNo'] ?? '00XXXXXX000XXXX'}",
//                               style: TextStyle(
//                                 fontFamily: 'SF Pro',
//                                 fontSize: 16,
//                                 color: themeProvider.themeTextColor.withOpacity(
//                                   0.8,
//                                 ),
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                             const SizedBox(height: 12),
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.email,
//                                   color: themeProvider.themeTextColor
//                                       .withOpacity(0.9),
//                                   size: 20,
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Flexible(
//                                   child: Text(
//                                     _userData['companyEmail'] ??
//                                         'contact@example.com',
//                                     style: TextStyle(
//                                       fontFamily: 'SF Pro',
//                                       fontSize: 16,
//                                       color: themeProvider.themeTextColor
//                                           .withOpacity(0.9),
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   Column(
//                     children: [
//                       Divider(
//                         color: themeProvider.themeTextColor.withOpacity(0.2),
//                       ),
//                       ListTile(
//                         leading: Icon(Icons.logout, color: Colors.red[300]),
//                         title: Text(
//                           'Logout',
//                           style: TextStyle(
//                             fontFamily: 'SF Pro',
//                             fontWeight: FontWeight.w600,
//                             color: themeProvider.themeTextColor,
//                           ),
//                         ),
//                         onTap: () async {
//                           Navigator.of(context).pop();
//                           await authProvider.logout();
//                           if (!context.mounted) return;
//                           Navigator.of(context).pushAndRemoveUntil(
//                             CupertinoPageRoute(
//                               builder: (_) => const LoginScreen(),
//                             ),
//                             (route) => false,
//                           );
//                         },
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//         // AppBar(
//         //   title: Text(isArabic ? 'الموردين' : 'Vendors'),
//         //   backgroundColor: const Color(0xFF00695C),
//         //   foregroundColor: Colors.white,
//         //  scrolledUnderElevation: 0,
//         // ),
//         body: Consumer<ThemeProvider>(
//           builder: (contex, themeProvider, child) {
//             return Container(
//               decoration: BoxDecoration(
//                 gradient: themeProvider.themeGradientBGColor,
//               ),
//               child: SafeArea(
//                 child: Column(
//                   children: [
//                     Container(
//                       margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                       height: 70,
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(
//                               0.1,
//                             ), // shadow color
//                             spreadRadius: 2, // how wide the shadow spreads
//                             blurRadius: 6, // softening effect
//                             offset: Offset(0, 0), // horizontal, vertical shift
//                           ),
//                         ],
//                         borderRadius: BorderRadius.circular(
//                           16,
//                         ), // optional rounded corners
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Row(
//                             children: [
//                               Container(
//                                 margin: EdgeInsets.symmetric(
//                                   horizontal: 10,
//                                   vertical: 5,
//                                 ),
//                                 height: 55,
//                                 width: 55,
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey.shade200,
//                                   borderRadius: BorderRadius.circular(16),
//                                 ),
//                                 child: InkWell(
//                                   onTap: () {
//                                     _scaffoldKey.currentState?.openDrawer();
//                                   },
//                                   child: ProfileAvatar(),
//                                 ),
//                                 // Center(child: Icon(FontAwesomeIcons.user)),
//                               ),
//                               // SizedBox(width: 2),
//                               Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     _userData['name'] ?? 'User Name',
//                                     style: TextStyle(
//                                       color: Colors.black,
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   Text(
//                                     _userData['email'] ?? 'user@gmail.com',
//                                     style: TextStyle(
//                                       color: Colors.grey,
//                                       fontSize: 15,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                           Padding(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 10.0,
//                             ),
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               children: [
//                                 SizedBox(height: 4),
//                                 Image.asset(
//                                   'assets/appIconLogo.png',
//                                   scale: 12,
//                                 ),
//                                 Text(
//                                   'Venzo',
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     Expanded(child: _screens[_selectedIndex]),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),

//         // Replace your BottomNavigationBar with this Container version
//         bottomNavigationBar: Padding(
//           padding: const EdgeInsets.all(12.0),
//           child: Container(
//             height: 70,
//             decoration: const BoxDecoration(
//               borderRadius: BorderRadius.all(Radius.circular(16)),
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black12,
//                   blurRadius: 10,
//                   offset: Offset(0, -2),
//                 ),
//               ],
//             ),
//             child: Padding(
//               padding: const EdgeInsets.all(4.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _buildNavItem(
//                     icon: LucideIcons.usersRound,
//                     label: isArabic ? 'الموردين' : 'Vendors',
//                     index: 0,
//                     currentIndex: _selectedIndex,
//                     onTap: _onItemTapped,
//                   ),
//                   _buildNavItem(
//                     icon: LucideIcons.shoppingCart,
//                     label: isArabic ? 'أوامر الشراء' : 'Purchases',
//                     index: 1,
//                     currentIndex: _selectedIndex,
//                     onTap: _onItemTapped,
//                   ),
//                   _buildNavItem(
//                     icon: Icons.account_balance_outlined,
//                     label: isArabic ? 'منتجات' : 'Products',
//                     index: 2,
//                     currentIndex: _selectedIndex,
//                     onTap: _onItemTapped,
//                   ),
//                   _buildNavItem(
//                     icon: LucideIcons.chartColumn,
//                     label: isArabic ? 'التقارير' : 'Reports',
//                     index: 3,
//                     currentIndex: _selectedIndex,
//                     onTap: _onItemTapped,
//                   ),
//                   _buildNavItem(
//                     icon: LucideIcons.settings,
//                     label: isArabic ? 'الإعدادات' : 'Settings',
//                     index: 4,
//                     currentIndex: _selectedIndex,
//                     onTap: _onItemTapped,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildNavItem({
//     required IconData icon,
//     required String label,
//     required int index,
//     required int currentIndex,
//     required Function(int) onTap,
//   }) {
//     final bool isActive = currentIndex == index;

//     return GestureDetector(
//       onTap: () => onTap(index),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
//         decoration: BoxDecoration(
//           color: isActive ? Colors.black.withOpacity(0.08) : Colors.transparent,
//           borderRadius: BorderRadius.circular(16),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           // mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(
//               icon,
//               color: isActive ? Colors.black : Colors.grey.shade600,
//               size: isActive ? 28 : 24,
//             ),
//             const SizedBox(width: 4),
//             Text(
//               label,
//               style: TextStyle(
//                 color: isActive ? Colors.black : Colors.grey.shade600,
//                 fontSize: isActive ? 12 : 11,
//                 fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class GlassContainer extends StatelessWidget {
//   final Widget? child;
//   final Color? bgcolor;
//   final double borderRadius;
//   final double blurStrength;
//   final double surfaceOpacity;
//   final double reflectionIntensity;
//   final EdgeInsets margin;
//   final EdgeInsets padding;

//   const GlassContainer({
//     super.key,
//     this.child,
//     this.bgcolor,
//     this.borderRadius = 32,
//     this.blurStrength = 0,
//     this.surfaceOpacity = 0.0,
//     this.reflectionIntensity = 0.3,
//     this.margin = const EdgeInsets.symmetric(horizontal: 0),
//     this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<ThemeProvider>(
//       builder: (context, themeProvider, ChildBackButtonDispatcher) {
//         return themeProvider.selectedTheme == "Light"
//             ? Container(
//                 margin: margin,
//                 decoration: BoxDecoration(
//                   color: bgcolor ?? Colors.white,
//                   borderRadius: BorderRadius.circular(borderRadius),
//                   border: Border.all(
//                     color: Colors.grey.withOpacity(0.2),
//                     width: 1,
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.05),
//                       blurRadius: 10,
//                       spreadRadius: 0,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: Padding(padding: padding, child: child),
//               )
//             : LiquidGlassEffect(
//                 borderRadius: borderRadius,
//                 blurStrength: blurStrength,
//                 surfaceOpacity: surfaceOpacity,
//                 reflectionIntensity: reflectionIntensity,
//                 margin: margin,
//                 padding: padding,
//                 baseColor: Colors.transparent,
//                 child: child ?? _defaultContent(context),
//               );
//       },
//     );
//   }

//   Widget _defaultContent(BuildContext context) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Expanded(
//               child: Text(
//                 'Now Playing',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.95),
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//             Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.7)),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Container(
//               width: 56,
//               height: 56,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12),
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
//                 ),
//               ),
//               child: const Center(
//                 child: Icon(Icons.music_note, color: Colors.white, size: 28),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'All Of Me',
//                     style: TextStyle(
//                       color: Colors.white.withOpacity(0.95),
//                       fontSize: 15,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Nao',
//                     style: TextStyle(
//                       color: Colors.white.withOpacity(0.7),
//                       fontSize: 13,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Container(
//               width: 44,
//               height: 44,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.black.withOpacity(0.08),
//               ),
//               child: const Icon(Icons.play_arrow, color: Colors.white),
//             ),
//           ],
//         ),
//         const SizedBox(height: 14),
//         // simple progress bar
//         ClipRRect(
//           borderRadius: BorderRadius.circular(20),
//           child: Container(
//             height: 6,
//             color: Colors.white.withOpacity(0.08),
//             child: FractionallySizedBox(
//               alignment: Alignment.centerLeft,
//               widthFactor: 0.45,
//               child: Container(color: Colors.white.withOpacity(0.9)),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class ProfileAvatar extends StatelessWidget {
//   final double size;
//   final bool showBorder;
//   final VoidCallback? onTap;

//   const ProfileAvatar({
//     super.key,
//     this.size = 44,
//     this.showBorder = true,
//     this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     return Consumer<ProfileImageProvider>(
//       builder: (context, profileProvider, child) {
//         if (profileProvider.isLoading) {
//           return GlassContainer(
//             margin: EdgeInsets.zero,
//             padding: EdgeInsets.zero,
//             borderRadius: 16,
//             child: Icon(Icons.person, size: size / 2, color: Colors.black54),
//           );
//         }

//         return GestureDetector(
//           onTap: onTap,
//           child: GlassContainer(
//             margin: EdgeInsets.zero,
//             padding: EdgeInsets.zero,
//             borderRadius: 16,
//             child:Container(
//   width: 32, // diameter = radius * 2
//   height: 32,
//   decoration: BoxDecoration(
//     borderRadius: BorderRadius.circular(12),  
//     color: profileProvider.hasImage
//         ? Colors.transparent
//         : Colors.white.withOpacity(0),
//     image: profileProvider.hasImage
//         ? DecorationImage(
//             image: MemoryImage(profileProvider.profileImageBytes!),
//             fit: BoxFit.cover,
//           )
//         : null,
//   ),
//   child: !profileProvider.hasImage
//       ? Center(
//           child: Icon(
//             FontAwesomeIcons.user,
//             size: size / 2,
//             color: themeProvider.themeTextColor.withOpacity(0.6),
//           ),
//         )
//       : null,
// )
//           ),
//         );
//       },
//     );
//   }
// }
