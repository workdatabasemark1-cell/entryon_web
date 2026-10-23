import 'package:entryon/firebase_options.dart';
import 'package:entryon/providers/transaction_provider.dart';
import 'package:entryon/views/transactionListScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  });

  testWidgets('Transactions list screen shows the title', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(),
        child: const MaterialApp(home: TransactionsListScreen()),
      ),
    );

    expect(find.text('Transactions'), findsOneWidget);
  });
}
