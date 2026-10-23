import 'package:entryon/firebase_options.dart';
import 'package:entryon/providers/auth_Provider.dart';
import 'package:entryon/providers/user_provider.dart';
import 'package:entryon/views/login_screen.dart';
import 'package:entryon/views/navBarScreen.dart';
import 'package:entryon/providers/editPurchaseEntryProvider.dart';
import 'package:window_size/window_size.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/customer_provider.dart';
import 'providers/purchase_entry_provider.dart';
import 'providers/service_entry_provider.dart';
import 'providers/edit_service_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/profit_calculation_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/app_theme.dart';

// === Notification imports ===
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Timezone
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  // 2. Initialize Local Notifications
  const InitializationSettings initializationSettings = InitializationSettings();

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      debugPrint('Notification clicked → payload: ${details.payload}');
    },
  );

  // 3. Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 4. Window size (desktop)
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    setWindowTitle('Entry On');

    getWindowInfo().then((info) {
      final screenFrame = info.screen?.visibleFrame;
      if (screenFrame != null) {
        final fullScreenSize = Size(screenFrame.width, screenFrame.height);
        final fullScreenOffset = Offset(screenFrame.left, screenFrame.top);

        setWindowFrame(Rect.fromLTWH(
          fullScreenOffset.dx,
          fullScreenOffset.dy,
          fullScreenSize.width,
          fullScreenSize.height,
        ));

        setWindowMinSize(const Size(480, 600));
        setWindowMaxSize(Size.infinite);
      }
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadCredentials()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseEntryProvider()),
        ChangeNotifierProvider(create: (_) => EditPurchaseEntryProvider()),
        ChangeNotifierProvider(create: (_) => ServiceEntryProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => ProfitCalculationProvider()),
        ChangeNotifierProvider(create: (_) => EditServiceProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkFuturisticTheme,
            themeMode: themeProvider.isDarkFuturistic ? ThemeMode.dark : ThemeMode.light,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isInitializing) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0D9488),
                strokeWidth: 2.5,
              ),
            ),
          );
        }
        if (auth.isLoggedIn) {
          return const MainNavScreen();
        }
        return const LoginScreen();
      },
    );
  }
}


