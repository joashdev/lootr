import 'package:flutter/material.dart';

class AiSettingsScreen extends StatelessWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI & Data')),
      body: const Center(child: Text('AI Settings')),
    );
  }
}
