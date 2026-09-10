import "package:flutter/material.dart";
import "dashboard_screen.dart";
import "inventory_screen.dart";
import "settings_screen.dart";
import "transaction_screen.dart";
import "reports_screen.dart";
import "../theme/app_theme.dart";
import "../utils/sidebar.dart";


class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;

  void setTab(int index) {
    if(index >= 0 && index < _screens.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  late final List<Widget> _screens = [
    DashboardScreen(onNavigatetoTab: setTab),
    const InventoryScreen(),
    const TransactionsScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];


  @override
  Widget build(BuildContext context) {
    final bool showSidebarInline = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: showSidebarInline
          ? null
          : Drawer(
              child: Sidebar(
                selectedIndex: _selectedIndex,
                onSelect: (i) {
                  setState(() => _selectedIndex = i);
                  Navigator.of(context).pop();
                },
              ),
            ),
      body: Row(
        children: [
          if (showSidebarInline)
            Sidebar(
              selectedIndex: _selectedIndex,
              onSelect: (i) => setState(() => _selectedIndex = i),
            ),
          if (showSidebarInline)
            const VerticalDivider(
                width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: Container(
              color: AppColors.background,
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: showSidebarInline
          ? null
          : Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex < 5 ? _selectedIndex : 0,
                onTap: (i) => setState(() => _selectedIndex = i),
                type: BottomNavigationBarType.fixed,
                backgroundColor: AppColors.surface,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textMuted,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                iconSize: 22,
                items: [
                  for (int i = 0; i < 5; i++)
                    BottomNavigationBarItem(
                      icon: Icon(kNavItems[i].icon),
                      activeIcon: Icon(kNavItems[i].activeIcon),
                      label: kNavItems[i].label,
                    ),
                ],
              ),
            ),
    );
  }
}