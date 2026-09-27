import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../widgets/settings_dialog.dart';
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'ai_insights_screen.dart';
import 'analytics_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    PosScreen(),
    InventoryScreen(),
    AiInsightsScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Top right settings floating button
          Positioned(
            top: 45,
            right: 8,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
                elevation: 1,
              ),
              icon: const Icon(Icons.settings_outlined, size: 20, color: AppColors.textMuted),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const SettingsDialog(),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primaryLight,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale, color: AppColors.primaryDark),
              label: 'Kasir',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: AppColors.primaryDark),
              label: 'Inventori',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome, color: AppColors.accent),
              label: 'AI Radar',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights, color: AppColors.primaryDark),
              label: 'Analitik',
            ),
          ],
        ),
      ),
    );
  }
}
