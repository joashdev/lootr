import 'package:flutter/material.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Account Detail')),
    );
  }
}
