import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.slidersHorizontal),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(child: Text('Transactions')),
    );
  }
}
