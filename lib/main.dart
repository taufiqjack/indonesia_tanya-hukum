import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:indonesia_law/core/config/env.dart';
import 'package:indonesia_law/core/pages/dashboard/dashboard_view.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const DashboardView(),
    );
  }
}
