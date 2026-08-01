import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';

class VaDeRumbaApp extends StatelessWidget {
  const VaDeRumbaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Va de Rumba',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B1FA2),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F6FA),
      ),
      home: const AuthGate(),
    );
  }
}
