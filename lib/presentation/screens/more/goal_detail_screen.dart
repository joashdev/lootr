import 'package:flutter/material.dart';

class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Goal Detail')),
    );
  }
}
