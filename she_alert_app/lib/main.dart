import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'widgets/root_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Emulator line removed — now connects to real Firebase
  // FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

  runApp(const SheAlertApp());
}

class SheAlertApp extends StatelessWidget {
  const SheAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SheAlert',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const RootNav(),
    );
  }
}