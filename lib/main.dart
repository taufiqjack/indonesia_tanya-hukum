import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:indonesia_law/core/config/env.dart';
import 'package:indonesia_law/core/pages/auth_gate.dart';
import 'package:indonesia_law/core/pages/signin_view.dart/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Env.load();
  } on Object catch (error) {
    // A missing `.env` must not block the app — the chat surfaces the problem
    // as a normal error bubble instead.
    debugPrint('Gagal memuat .env: $error');
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Owned here so the signed-in account outlives the pages that show it.
  final AuthController _auth = AuthController();

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hukum AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      builder: FToastBuilder(),
      home: AuthGate(auth: _auth),
    );
  }
}
