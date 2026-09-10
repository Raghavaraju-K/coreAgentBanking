import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'assistant/assistant_binding.dart';
import 'assistant/assistant_screen.dart';

void main() {
  runApp(const BankingAssistantApp());
}

class BankingAssistantApp extends StatelessWidget {
  const BankingAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Northstar Banking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6E69),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        useMaterial3: true,
        fontFamily: 'sans',
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      initialBinding: AssistantBinding(),
      home: const AssistantScreen(),
    );
  }
}
