import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavItem(
      {required this.label, required this.icon, required this.activeIcon});
}

const List<NavItem> kNavItems = [
  NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded),
  NavItem(
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded),
  NavItem(
      label: 'Transactions',
      icon: Icons.call_received_rounded,
      activeIcon: Icons.call_received_rounded),
  NavItem(
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded),
  NavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded),
];

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const Sidebar(
      {super.key, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrand(),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: kNavItems.length,
                itemBuilder: (context, index) {
                  final item = kNavItems[index];
                  final selected = index == selectedIndex;
                  return _NavTile(
                    item: item,
                    selected: selected,
                    onTap: () => onSelect(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('CBHIMS', style: AppTextStyles.h3),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool active = selected;
    final Color bg = active ? AppColors.primarySoft : Colors.transparent;
    final Color fg = active ? AppColors.primary : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(active ? item.activeIcon : item.icon, size: 19, color: fg),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}