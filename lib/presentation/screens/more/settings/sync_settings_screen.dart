import 'package:flutter/material.dart';

class SyncSettingsScreen extends StatelessWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Sync')),
      body: const Center(child: Text('Sync Settings')),
    );
  }
}
