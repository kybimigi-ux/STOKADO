import "package:flutter/material.dart";
import '../utils/action_card.dart';
import '../utils/info_card.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int> onNavigatetoTab;

  const DashboardScreen({super.key, required this.onNavigatetoTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(   
      appBar: AppBar(
        title: const Text(
          'DASHBOARD',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoCard(
            label: 'TOTAL PRODUCTS',
            value: '0',
          ),
          const SizedBox(height: 16),
          const InfoCard(
            label: 'LOW STOCK ALERT',
            value: '0',
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              ActionTile(
                label: 'Add Product',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              ActionTile(
                label: 'Receive Stock',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              ActionTile(
                label: 'Release Stock',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

