import 'package:flutter/material.dart';

class RecurringDetailScreen extends StatelessWidget {
  const RecurringDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Detail')),
      body: Center(child: Text('Recurring Detail — $id')),
    );
  }
}
