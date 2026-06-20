import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';


class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.plus),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(child: Text('Budgets')),
    );
  }
}
