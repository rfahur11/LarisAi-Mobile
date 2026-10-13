import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../providers/pos_provider.dart';
import '../providers/ai_provider.dart';
import '../services/local_host_server_service.dart';
import '../services/cloud_health_service.dart';
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
  StreamSubscription<String>? _lanSub;
  StreamSubscription<bool>? _healthSub;
  StreamSubscription<void>? _reconnectedSub;

  @override
  void initState() {
    super.initState();
    // Listen to LAN server events (e.g. mobile cashier checked out) to refresh Desktop UI in real-time
    _lanSub = LocalHostServerService.instance.onDataChanged.listen((_) {
      if (mounted) {
        final posProvider = Provider.of<PosProvider>(context, listen: false);
        posProvider.loadProducts();
        posProvider.loadSummary();
      }
    });

    // Proactive Toast when Disconnected
    _healthSub = CloudHealthService.instance.onConnectionChanged.listen((isConnected) {
      if (!mounted) return;
      if (!isConnected && !ApiConstants.isOfflineMode && !LocalHostServerService.instance.isRunning.value) {
        final hostLabel = CloudHealthService.instance.targetHostLabel;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ApiConstants.currentMode == ConnectionMode.wifi
                        ? '⚠️ Terputus dari Kasir Master ($hostLabel)!'
                        : '⚠️ Koneksi ke Server Cloud Terputus!',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    // Proactive Toast and Silent Stock Sync when Reconnected
    _reconnectedSub = CloudHealthService.instance.onReconnected.listen((_) {
      if (!mounted) return;
      if (!ApiConstants.isOfflineMode && !LocalHostServerService.instance.isRunning.value) {
        final hostLabel = CloudHealthService.instance.targetHostLabel;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ApiConstants.currentMode == ConnectionMode.wifi
                        ? '✅ Terhubung kembali ke Kasir Master ($hostLabel)!'
                        : '✅ Terhubung kembali ke Server Cloud!',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 3),
          ),
        );

        // Silent catalog & summary sync
        final posProvider = Provider.of<PosProvider>(context, listen: false);
        posProvider.loadProducts();
        posProvider.loadSummary();
      }
    });
  }

  @override
  void dispose() {
    _lanSub?.cancel();
    _healthSub?.cancel();
    _reconnectedSub?.cancel();
    super.dispose();
  }

  final GlobalKey<AnalyticsScreenState> _analyticsKey = GlobalKey<AnalyticsScreenState>();

  late final List<Widget> _screens = [
    const PosScreen(),
    const InventoryScreen(),
    const AiInsightsScreen(),
    AnalyticsScreen(key: _analyticsKey),
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
      _analyticsKey.currentState?.reloadAll();
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
