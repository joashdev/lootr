import 'package:flutter/material.dart';

class PayeeDetailScreen extends StatelessWidget {
  const PayeeDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payee Detail')),
      body: Center(child: Text('Payee Detail — $id')),
    );
  }
}
