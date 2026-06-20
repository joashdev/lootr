import 'package:flutter/material.dart';

class HouseholdDetailScreen extends StatelessWidget {
  const HouseholdDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Household Detail')),
      body: Center(child: Text('Household Detail — $id')),
    );
  }
}
