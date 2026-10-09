import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/pos_provider.dart';
import '../providers/ai_provider.dart';
import '../widgets/desktop_header.dart';
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

  void _onTabSelected(int idx) {
    setState(() => _currentIndex = idx);
    final posProvider = Provider.of<PosProvider>(context, listen: false);
    final aiProvider = Provider.of<AiProvider>(context, listen: false);

    if (idx == 0 || idx == 1) {
      posProvider.loadProducts();
      posProvider.loadSummary();
    } else if (idx == 2) {
      aiProvider.loadAiData();
    } else if (idx == 3) {
      posProvider.loadSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDesktop) {
      // --- DESKTOP LAYOUT (>= 800px) ---
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        body: Column(
          children: [
            // Top Modern Navbar & Bento Stats Header
            DesktopHeader(
              activeIndex: _currentIndex,
              onTabSelected: _onTabSelected,
            ),

            // Active Screen Content
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    // --- MOBILE LAYOUT (< 800px) ---
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          _onTabSelected(0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          indicatorColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale, color: AppColors.primary),
              label: 'Kasir',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
              label: 'Inventori',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome, color: AppColors.accent),
              label: 'AI Radar',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights, color: AppColors.primary),
              label: 'Analitik',
            ),
          ],
        ),
      ),
    ),
  );
}
}
