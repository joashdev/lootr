import 'package:flutter/material.dart';

class AiLogsScreen extends StatelessWidget {
  const AiLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Processing Log')),
      body: const Center(child: Text('AI Logs')),
    );
  }
}
