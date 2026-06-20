import 'package:flutter/material.dart';

class DebtDetailScreen extends StatelessWidget {
  const DebtDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debt Detail')),
      body: Center(child: Text('Debt Detail — $id')),
    );
  }
}
