import 'package:flutter/material.dart';

class BudgetDetailScreen extends StatelessWidget {
  const BudgetDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget Detail')),
      body: Center(child: Text('Budget Detail — $id')),
    );
  }
}
