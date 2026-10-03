import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../providers/pos_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/theme_provider.dart';
import '../services/store_profile_service.dart';
import 'order_history_dialog.dart';
import 'settings_dialog.dart';

class DesktopHeader extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabSelected;

  const DesktopHeader({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final posProvider = Provider.of<PosProvider>(context);
    final aiProvider = Provider.of<AiProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final totalRevenue = posProvider.totalRevenueToday;
    final totalOrders = posProvider.totalOrdersToday;
    final lowStock = posProvider.lowStockCount;
    final stockouts = aiProvider.stockouts.length;

    return AnimatedBuilder(
      animation: StoreProfileService.instance,
      builder: (context, _) {
        final profile = StoreProfileService.instance.profile;

        return Container(
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Navbar Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Brand Logo & Title
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/larisai_logo.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'LarisAI',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF115E59) : AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'SMART POS UMKM',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.primaryHover : AppColors.primaryDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          profile.storeName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                // Live Cashier Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Kasir Aktif: Siap Melayani',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Operational Mode Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ApiConstants.currentMode == ConnectionMode.offline
                        ? (isDark ? const Color(0xFF042F2E) : Colors.teal.shade50)
                        : (isDark ? const Color(0xFF1E1B4B) : Colors.indigo.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ApiConstants.currentMode == ConnectionMode.offline
                          ? Colors.teal.shade300
                          : Colors.indigo.shade300,
                    ),
                  ),
                  child: Text(
                    ApiConstants.modeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ApiConstants.currentMode == ConnectionMode.offline
                          ? (isDark ? Colors.teal.shade200 : Colors.teal.shade800)
                          : (isDark ? Colors.indigo.shade200 : Colors.indigo.shade800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Dark / Light Mode Toggle Button
                IconButton(
                  tooltip: themeProvider.isDarkMode ? 'Mode Terang' : 'Mode Malam',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                    ),
                  ),
                  icon: Icon(
                    themeProvider.isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                    size: 18,
                    color: themeProvider.isDarkMode ? Colors.amber : AppColors.accent,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                ),
                const SizedBox(width: 8),

                // Settings Dialog Trigger
                IconButton(
                  tooltip: 'Pengaturan & Backup',
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                    ),
                  ),
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const SettingsDialog(),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // User Profile Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        profile.ownerName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Navigation Tabs Bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildNavTab(
                  index: 0,
                  icon: Icons.point_of_sale_rounded,
                  label: 'Kasir POS',
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildNavTab(
                  index: 1,
                  icon: Icons.inventory_2_rounded,
                  label: 'Katalog Produk',
                  badgeText: posProvider.products.length.toString(),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildNavTab(
                  index: 2,
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Insights & Radar',
                  badgeText: stockouts > 0 ? '$stockouts Alert' : null,
                  badgeColor: AppColors.accent,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildNavTab(
                  index: 3,
                  icon: Icons.analytics_rounded,
                  label: 'Laporan & Analitik',
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // 3. Bento-Box Dashboard Metrics Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            color: isDark ? AppColors.darkBackground : AppColors.background,
            child: Row(
              children: [
                // Bento Card 1: Revenue
                Expanded(
                  child: _buildBentoCard(
                    title: 'UANG MASUK HARI INI',
                    value: CurrencyFormatter.format(totalRevenue),
                    subtitle: 'Klik untuk lihat laporan pembukuan',
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.success,
                    isDark: isDark,
                    onTap: () => onTabSelected(3),
                  ),
                ),
                const SizedBox(width: 12),

                // Bento Card 2: Total Orders
                Expanded(
                  child: _buildBentoCard(
                    title: 'TOTAL TRANSAKSI',
                    value: '$totalOrders Penjualan',
                    subtitle: 'Klik untuk riwayat nota & cetak struk',
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFF0284C7),
                    isDark: isDark,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const OrderHistoryDialog(),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Bento Card 3: Low Stock
                Expanded(
                  child: _buildBentoCard(
                    title: 'STOK MENIPIS',
                    value: '$lowStock Produk',
                    subtitle: lowStock > 0 ? 'Klik untuk cek katalog inventori' : 'Inventori aman • Klik untuk katalog',
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.warning,
                    isDark: isDark,
                    onTap: () => onTabSelected(1),
                  ),
                ),
                const SizedBox(width: 12),

                // Bento Card 4: AI Radar
                Expanded(
                  child: _buildBentoCard(
                    title: 'AI STOCKOUT RADAR',
                    value: '$stockouts Prediksi Habis',
                    subtitle: 'Klik untuk analisis radar cerdas',
                    icon: Icons.auto_awesome_rounded,
                    iconColor: AppColors.accent,
                    isDark: isDark,
                    onTap: () => onTabSelected(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildNavTab({
    required int index,
    required IconData icon,
    required String label,
    String? badgeText,
    Color? badgeColor,
    required bool isDark,
  }) {
    final isSelected = activeIndex == index;
    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF042F2E) : AppColors.primaryLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.primaryHover : AppColors.primary)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                  : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                    : (isDark ? AppColors.darkTextMain : AppColors.textMain),
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? (isDark ? AppColors.primaryHover : AppColors.primaryDark),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: iconColor.withValues(alpha: isDark ? 0.08 : 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(icon, color: iconColor, size: 15),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
