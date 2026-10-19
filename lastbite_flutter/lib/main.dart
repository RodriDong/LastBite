import 'package:flutter/material.dart';
import 'models/mock_data.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(const LastBiteApp());
}

class LastBiteApp extends StatelessWidget {
  const LastBiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LastBite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green),
        scaffoldBackgroundColor: AppColors.app,
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}