import 'package:flutter/material.dart';
import 'package:bookswaphub/core/constants/app_colors.dart';

/// Shown instead of the app when Firebase has not been configured. No fake data, no fake login.
class SetupRequiredApp extends StatelessWidget {
  final String message;
  const SetupRequiredApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📚', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text('Setup required',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SelectableText(message, style: const TextStyle(color: Colors.white70, height: 1.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
