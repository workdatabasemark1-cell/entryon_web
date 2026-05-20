import 'package:entryon/navBarScreen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/customer_provider.dart';
import 'providers/purchase_entry_provider.dart';
import 'providers/supplier_provider.dart';


Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();

    Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyAM4Qu9L0ltyhPvHV4kF8J1GgcDXYlZZIE",
          authDomain: "entryon-73577.firebaseapp.com",
          projectId: "entryon-73577",
          storageBucket: "entryon-73577.firebasestorage.app",
          messagingSenderId: "563457634778",
          appId: "1:563457634778:web:a600548729330eb6b0d0e3",
        ),
      );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseEntryProvider()),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false,
        home: MainNavScreen(),
      ),
    );
  }
}
