import 'package:flutter/material.dart';

class InsightDetailScreen extends StatelessWidget {
  const InsightDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insight Detail')),
      body: Center(child: Text('Insight Detail — $id')),
    );
  }
}
