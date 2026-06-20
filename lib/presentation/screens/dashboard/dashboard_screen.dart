import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';


class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.cloudCheck),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(LucideIcons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: const Center(child: Text('Dashboard')),
    );
  }
}
