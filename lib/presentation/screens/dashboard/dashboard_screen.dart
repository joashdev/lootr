import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.cloudCheck),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(child: Text('Dashboard')),
    );
  }
}
