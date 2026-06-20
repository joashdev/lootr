import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';


class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.slidersHorizontal),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(LucideIcons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(child: Text('Transactions')),
    );
  }
}
