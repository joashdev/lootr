import 'package:flutter/material.dart';

class RecurringDetailScreen extends StatelessWidget {
  const RecurringDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Recurring Detail')),
    );
  }
}
