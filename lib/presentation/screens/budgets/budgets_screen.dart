import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';


class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(child: Text('Budgets')),
    );
  }
}
