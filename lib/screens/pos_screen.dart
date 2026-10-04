import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../core/constants/api_constants.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../providers/pos_provider.dart';
import '../widgets/checkout_sheet.dart';
import '../widgets/receipt_dialog.dart';
import '../widgets/settings_dialog.dart';
import 'scanner_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _desktopCashController = TextEditingController();
  final TextEditingController _desktopRefController = TextEditingController();
  String _desktopPaymentType = 'TUNAI';
  String _desktopSelectedBank = 'BCA';
  String _desktopSelectedEwallet = 'GoPay';
  int _desktopCashTendered = 0;
  bool _isProcessingCheckout = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _desktopCashController.dispose();
    _desktopRefController.dispose();
    super.dispose();
  }

  Future<void> _openScanner(BuildContext context) async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (scannedCode != null && mounted) {
      final posProvider = Provider.of<PosProvider>(context, listen: false);
      final product = await posProvider.scanAndAddToCart(scannedCode);

      if (mounted) {
        if (product != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Ditambahkan: ${product.name}'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppColors.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Barcode $scannedCode tidak ditemukan di katalog'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    }
  }

  void _openMobileCheckout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CheckoutSheet(),
    );
  }

  void _showAddProductModal(BuildContext context) {
    final barcodeController = TextEditingController();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    String category = 'Makanan';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_box_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Tambah Produk Cepat (F2)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Barcode / SKU:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: barcodeController,
                  decoration: const InputDecoration(
                    hintText: 'Misal: 8991234567890',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Nama Produk:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'Nama barang',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Harga (Rp):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '5000',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Stok Awal:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '10',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Kategori:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ['Makanan', 'Minuman', 'Sembako', 'Snack', 'Umum']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) => setModalState(() => category = val ?? 'Umum'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final barcode = barcodeController.text.trim().isNotEmpty
                    ? barcodeController.text.trim()
                    : DateTime.now().millisecondsSinceEpoch.toString();
                final price = int.tryParse(priceController.text.trim()) ?? 0;
                final stock = int.tryParse(stockController.text.trim()) ?? 1;

                if (name.isEmpty || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ Nama dan harga produk wajib diisi')),
                  );
                  return;
                }

                final newProd = Product(
                  id: '',
                  barcode: barcode,
                  name: name,
                  category: category,
                  price: price,
                  stock: stock,
                );

                final posProvider = Provider.of<PosProvider>(context, listen: false);
                await posProvider.addNewProduct(newProd);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ $name berhasil ditambahkan!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processDesktopCheckout(BuildContext context, PosProvider posProvider) async {
    if (posProvider.cart.isEmpty || _isProcessingCheckout) return;

    final total = posProvider.totalAmount;
    if (_desktopPaymentType == 'TUNAI' && _desktopCashTendered < total && _desktopCashTendered > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Uang tunai yang dibayarkan kurang dari total belanja!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final effectiveCash = (_desktopPaymentType == 'TUNAI')
        ? (_desktopCashTendered > 0 ? _desktopCashTendered : total)
        : total;

    setState(() => _isProcessingCheckout = true);

    String customerNote = _desktopRefController.text.trim();
    if (_desktopPaymentType == 'TRANSFER') {
      final bankText = 'Transfer $_desktopSelectedBank';
      customerNote = customerNote.isNotEmpty ? '$customerNote ($bankText)' : bankText;
    } else if (_desktopPaymentType == 'EWALLET') {
      final ewText = 'E-Wallet $_desktopSelectedEwallet';
      customerNote = customerNote.isNotEmpty ? '$customerNote ($ewText)' : ewText;
    } else if (_desktopPaymentType == 'DEBIT') {
      const debitText = 'Kartu Debit/EDC';
      customerNote = customerNote.isNotEmpty ? '$customerNote ($debitText)' : debitText;
    }

    final tx = await posProvider.processCheckout(
      paymentType: _desktopPaymentType,
      customerId: customerNote.isNotEmpty ? customerNote : null,
    );

    setState(() => _isProcessingCheckout = false);

    if (!context.mounted) return;

    if (tx != null) {
      showDialog(
        context: context,
        builder: (_) => ReceiptDialog(
          transaction: tx,
          cashTendered: effectiveCash,
        ),
      );
      setState(() {
        _desktopCashTendered = 0;
        _desktopCashController.clear();
        _desktopRefController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);

    // Keyboard Shortcuts (F1, F2, F7, F8, F9, Escape)
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f1): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.f2): () {
          _showAddProductModal(context);
        },
        const SingleActivator(LogicalKeyboardKey.f7): () {
          setState(() {
            _desktopPaymentType = 'TUNAI';
            if (_desktopCashTendered == 0) {
              _desktopCashTendered = posProvider.totalAmount;
              _desktopCashController.text = posProvider.totalAmount.toString();
            }
          });
        },
        const SingleActivator(LogicalKeyboardKey.f8): () {
          setState(() => _desktopPaymentType = 'QRIS');
        },
        const SingleActivator(LogicalKeyboardKey.f9): () {
          _processDesktopCheckout(context, posProvider);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchController.text.isNotEmpty) {
            _searchController.clear();
            posProvider.loadProducts();
          } else {
            posProvider.clearCart();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800;

            if (isDesktop) {
              return _buildDesktopLayout(context, posProvider, constraints.maxWidth);
            } else {
              return _buildMobileLayout(context, posProvider);
            }
          },
        ),
      ),
    );
  }

  // ==========================================
  // DESKTOP / TABLET SPLIT-SCREEN LAYOUT
  // ==========================================
  Widget _buildDesktopLayout(BuildContext context, PosProvider posProvider, double screenWidth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int crossAxisCount = 3;
    if (screenWidth >= 1400) {
      crossAxisCount = 5;
    } else if (screenWidth >= 1100) {
      crossAxisCount = 4;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Row(
        children: [
          // LEFT PANEL: Catalog, Search & Categories (Flex 3)
          Expanded(
            flex: 3,
            child: Container(
              color: isDark ? AppColors.darkBackground : AppColors.background,
              child: Column(
                children: [
                  // Desktop Top Action Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    child: Row(
                      children: [
                        // Search Box (F1)
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (val) => posProvider.loadProducts(search: val),
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                              fontSize: 13.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari produk atau scan barcode... (Tekan F1)',
                              hintStyle: TextStyle(
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                size: 20,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        posProvider.loadProducts();
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // F2 Add Product Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppColors.primaryHover : AppColors.primary,
                            backgroundColor: isDark ? const Color(0xFF042F2E) : Colors.transparent,
                            side: BorderSide(color: isDark ? const Color(0xFF0D9488) : AppColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showAddProductModal(context),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('+ Produk (F2)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),

                        // Scan Barcode Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _openScanner(context),
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: const Text('Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  // Category Chips Bar
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: posProvider.categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final cat = posProvider.categories[idx];
                        final isSelected = posProvider.selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) => posProvider.setCategory(cat),
                          selectedColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                          backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade50,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                                : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? AppColors.darkBorder : AppColors.border),
                            width: isSelected ? 1.5 : 1,
                          ),
                        );
                      },
                    ),
                  ),
                  Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),

                  // Product Grid
                  Expanded(
                    child: posProvider.isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : posProvider.products.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    const Text('Produk tidak ditemukan', style: TextStyle(color: AppColors.textMuted)),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(20),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  childAspectRatio: 1.15,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: posProvider.products.length,
                                itemBuilder: (ctx, idx) {
                                  final product = posProvider.products[idx];
                                  return _buildProductCard(context, product, posProvider);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),

          // RIGHT PANEL: Persistent Cashier Checkout Panel (Fixed 400px)
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(left: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border, width: 1.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Cart Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.shopping_cart_rounded, color: isDark ? AppColors.primaryHover : AppColors.primaryDark, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keranjang Belanja',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                              ),
                            ),
                            Text(
                              '${posProvider.totalItems} item dipilih',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (posProvider.cart.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => posProvider.clearCart(),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppColors.danger),
                          label: const Text('Reset', style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),

                // Cart Item List
                Expanded(
                  child: posProvider.cart.isEmpty
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.all(24),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard.withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.border,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppColors.primaryHover : AppColors.primary).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.point_of_sale_rounded,
                                    size: 32,
                                    color: isDark ? AppColors.primaryHover : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Keranjang Belum Terisi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Pilih barang di katalog atau scan barcode dengan tombol F1',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: posProvider.cart.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                          itemBuilder: (ctx, idx) {
                            final item = posProvider.cart[idx];
                            return _buildDesktopCartRow(item, posProvider);
                          },
                        ),
                ),

                // Payment & Checkout Area
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                    border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Breakdown Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBackground : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Tagihan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(posProvider.totalAmount),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                                ),
                              ],
                            ),
                            if (_desktopPaymentType == 'TUNAI' && _desktopCashTendered > 0) ...[
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Nominal Diterima',
                                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(_desktopCashTendered),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _desktopCashTendered >= posProvider.totalAmount ? 'Kembalian:' : 'Kurang:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _desktopCashTendered >= posProvider.totalAmount ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format((_desktopCashTendered - posProvider.totalAmount).abs()),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: _desktopCashTendered >= posProvider.totalAmount ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Payment Method Selector Pills (Row 1: Tunai, QRIS, Transfer)
                      Row(
                        children: [
                          _buildPaymentPill('TUNAI', '💵 Tunai (F7)', _desktopPaymentType == 'TUNAI', isDark),
                          const SizedBox(width: 6),
                          _buildPaymentPill('QRIS', '📱 QRIS (F8)', _desktopPaymentType == 'QRIS', isDark),
                          const SizedBox(width: 6),
                          _buildPaymentPill('TRANSFER', '🏦 Transfer', _desktopPaymentType == 'TRANSFER', isDark),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Payment Method Selector Pills (Row 2: Debit EDC, E-Wallet)
                      Row(
                        children: [
                          _buildPaymentPill('DEBIT', '💳 Kartu Debit / EDC', _desktopPaymentType == 'DEBIT', isDark),
                          const SizedBox(width: 6),
                          _buildPaymentPill('EWALLET', '📲 E-Wallet (GoPay/OVO/Dana)', _desktopPaymentType == 'EWALLET', isDark),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Dynamic Payment Input Area
                      if (_desktopPaymentType == 'TUNAI') ...[
                        // Manual Nominal Input Field
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _desktopCashController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Input Nominal Uang Diterima (Rp)',
                                  labelStyle: const TextStyle(fontSize: 12),
                                  prefixText: 'Rp ',
                                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  suffixIcon: _desktopCashController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () {
                                            setState(() {
                                              _desktopCashTendered = 0;
                                              _desktopCashController.clear();
                                            });
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (val) {
                                  final numVal = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                  setState(() {
                                    _desktopCashTendered = numVal;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Set Uang Pas Button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryLight,
                                foregroundColor: AppColors.primaryDark,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: posProvider.totalAmount > 0
                                  ? () {
                                      setState(() {
                                        _desktopCashTendered = posProvider.totalAmount;
                                        _desktopCashController.text = posProvider.totalAmount.toString();
                                      });
                                    }
                                  : null,
                              child: const Text('Uang Pas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Quick Cash Buttons
                        if (posProvider.totalAmount > 0)
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              _buildQuickCashChip('10rb', 10000, isDark),
                              _buildQuickCashChip('20rb', 20000, isDark),
                              _buildQuickCashChip('50rb', 50000, isDark),
                              _buildQuickCashChip('100rb', 100000, isDark),
                              _buildQuickCashChip('200rb', 200000, isDark),
                              _buildQuickAddCashChip('+5rb', 5000, posProvider, isDark),
                              _buildQuickAddCashChip('+10rb', 10000, posProvider, isDark),
                              _buildQuickAddCashChip('+20rb', 20000, posProvider, isDark),
                              _buildQuickAddCashChip('+50rb', 50000, posProvider, isDark),
                            ],
                          ),
                      ] else if (_desktopPaymentType == 'QRIS') ...[
                        // QRIS Preview Banner
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1B4B) : AppColors.accentLight.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.qr_code_2_rounded, size: 36, color: AppColors.accent),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('QRIS Toko', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            ApiConstants.isOfflineMode ? '0% MDR' : 'Auto Webhook',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? AppColors.primaryHover : AppColors.primaryDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Minta pelanggan scan QRIS & cek bukti bayar di HP.',
                                      style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_desktopPaymentType == 'TRANSFER') ...[
                        // Bank Selection Chips
                        Text('Pilih Bank Tujuan Toko:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Row(
                          children: ['BCA', 'Mandiri', 'BRI', 'BNI'].map((bank) {
                            final isBankSelected = _desktopSelectedBank == bank;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: ChoiceChip(
                                  label: Text(
                                    bank,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isBankSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isBankSelected
                                          ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                                          : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                    ),
                                  ),
                                  selected: isBankSelected,
                                  selectedColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                                  backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade50,
                                  side: BorderSide(
                                    color: isBankSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
                                  ),
                                  onSelected: (_) => setState(() => _desktopSelectedBank = bank),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Transfer Bank $_desktopSelectedBank toko. Tidak perlu input nomor kartu/rekening.',
                                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_desktopPaymentType == 'EWALLET') ...[
                        // E-Wallet Choice
                        Text('Pilih E-Wallet Pelanggan / Toko:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Row(
                          children: ['GoPay', 'OVO', 'DANA', 'ShopeePay'].map((ew) {
                            final isEwSelected = _desktopSelectedEwallet == ew;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: ChoiceChip(
                                  label: Text(
                                    ew,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: isEwSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isEwSelected
                                          ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                                          : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                    ),
                                  ),
                                  selected: isEwSelected,
                                  selectedColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                                  backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade50,
                                  side: BorderSide(
                                    color: isEwSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
                                  ),
                                  onSelected: (_) => setState(() => _desktopSelectedEwallet = ew),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pembayaran via $_desktopSelectedEwallet toko. Tidak perlu input nomor HP pelanggan.',
                                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_desktopPaymentType == 'DEBIT') ...[
                        // Debit EDC
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Mesin EDC Toko. Gesek atau tap kartu di mesin EDC kasir. Tidak perlu input nomor kartu.',
                                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Optional note field
                      TextField(
                        controller: _desktopRefController,
                        decoration: const InputDecoration(
                          hintText: 'Nama / Catatan Pelanggan (opsional)',
                          prefixIcon: Icon(Icons.edit_note_rounded, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Selesaikan Transaksi (F9) Big Button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: posProvider.cart.isNotEmpty && !_isProcessingCheckout
                              ? () => _processDesktopCheckout(context, posProvider)
                              : null,
                          icon: _isProcessingCheckout
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline, size: 20),
                          label: Text(
                            posProvider.cart.isEmpty ? 'Keranjang Kosong' : 'Selesaikan Transaksi (F9)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentPill(String type, String label, bool isSelected, bool isDark) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _desktopPaymentType = type;
          if (type != 'TUNAI') {
            _desktopCashTendered = 0;
            _desktopCashController.clear();
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF042F2E) : AppColors.primaryLight)
                : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.border),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                  : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashChip(String label, int amount, bool isDark) {
    final isSelected = _desktopCashTendered == amount;
    return InkWell(
      onTap: () => setState(() {
        _desktopCashTendered = amount;
        _desktopCashController.text = amount.toString();
      }),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextMain : AppColors.textMain),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddCashChip(String label, int addAmount, PosProvider posProvider, bool isDark) {
    return InkWell(
      onTap: () => setState(() {
        final base = _desktopCashTendered > 0 ? _desktopCashTendered : posProvider.totalAmount;
        _desktopCashTendered = base + addAmount;
        _desktopCashController.text = _desktopCashTendered.toString();
      }),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B4B) : AppColors.accentLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF4338CA) : AppColors.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFA5B4FC) : AppColors.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCartRow(CartItem item, PosProvider posProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.format(item.product.price),
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Quantity Controls
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.remove_circle_outline,
                  size: 18,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
                onPressed: () => posProvider.decreaseQuantity(item.product),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                onPressed: () => posProvider.addToCart(item.product),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Subtotal
          SizedBox(
            width: 75,
            child: Text(
              CurrencyFormatter.format(item.subtotal),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? const Color(0xFF34D399) : AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE LAYOUT (SMARTPHONE)
  // ==========================================
  Widget _buildMobileLayout(BuildContext context, PosProvider posProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/larisai_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LarisAI Kasir',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Mode POS Kasir Cepat',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const SettingsDialog(),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
              tooltip: 'Scan Barcode Kamera',
              onPressed: () => _openScanner(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (val) => posProvider.loadProducts(search: val),
              style: TextStyle(
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama produk atau barcode...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          posProvider.loadProducts();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          // Category Chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: posProvider.categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final cat = posProvider.categories[idx];
                final isSelected = posProvider.selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => posProvider.setCategory(cat),
                  selectedColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                        : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Product Grid
          Expanded(
            child: posProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : posProvider.products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'Produk tidak ditemukan',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.77,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: posProvider.products.length,
                        itemBuilder: (ctx, idx) {
                          final product = posProvider.products[idx];
                          return _buildProductCard(context, product, posProvider);
                        },
                      ),
          ),
        ],
      ),

      // Mobile Sticky Bottom Cart Bar
      bottomSheet: posProvider.cart.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${posProvider.totalItems} Produk',
                                  style: TextStyle(
                                    color: isDark ? AppColors.primaryHover : AppColors.primaryDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => posProvider.clearCart(),
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(posProvider.totalAmount),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF34D399) : AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _openMobileCheckout(context),
                      child: const Row(
                        children: [
                          Text('Bayar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // ==========================================
  // SHARED PRODUCT CARD WIDGET
  // ==========================================
  Widget _buildProductCard(BuildContext context, Product product, PosProvider posProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartIndex = posProvider.cart.indexWhere((c) => c.product.id == product.id);
    final inCartQty = cartIndex >= 0 ? posProvider.cart[cartIndex].quantity : 0;
    final isOutOfStock = product.stock <= 0;

    // Tactical Semantic Category Anchor
    IconData catIcon;
    Color catAccent;
    switch (product.category.toLowerCase()) {
      case 'minuman':
        catIcon = Icons.local_cafe_rounded;
        catAccent = const Color(0xFF0284C7); // Azure / Sky
        break;
      case 'makanan':
        catIcon = Icons.restaurant_rounded;
        catAccent = const Color(0xFFEA580C); // Warm Orange
        break;
      case 'sembako':
        catIcon = Icons.inventory_2_rounded;
        catAccent = const Color(0xFF16A34A); // Emerald / Green
        break;
      case 'snack':
        catIcon = Icons.cookie_rounded;
        catAccent = const Color(0xFFD97706); // Amber
        break;
      default:
        catIcon = Icons.sell_rounded;
        catAccent = const Color(0xFF6366F1); // Indigo
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inCartQty > 0
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.border),
          width: inCartQty > 0 ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isOutOfStock ? null : () => posProvider.addToCart(product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Icon Pill & Stock Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Category Badge with icon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: catAccent.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: catAccent.withValues(alpha: isDark ? 0.35 : 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(catIcon, size: 12, color: catAccent),
                          const SizedBox(width: 4),
                          Text(
                            product.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: catAccent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stock Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? AppColors.danger.withValues(alpha: 0.12)
                            : (product.stock <= 5
                                ? AppColors.warning.withValues(alpha: 0.12)
                                : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isOutOfStock ? 'Habis' : 'Stok: ${product.stock}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOutOfStock
                              ? AppColors.danger
                              : (product.stock <= 5
                                  ? AppColors.warning
                                  : (isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Product Name (Bold, High Contrast, 2 Lines)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.barcode.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          product.barcode,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontFamily: 'monospace',
                            letterSpacing: 0.3,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Bottom Section: Price & Action Stepper / Add Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Price Tag (Flexibly sized so it never pushes button out)
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(product.price),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF34D399) : AppColors.primaryDark,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Cart Quantity Stepper or Add Button
                    if (isOutOfStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Habis',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                      )
                    else if (inCartQty > 0)
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => posProvider.decreaseQuantity(product),
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.remove_rounded, size: 15, color: AppColors.primary),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 16),
                              alignment: Alignment.center,
                              child: Text(
                                '$inCartQty',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? AppColors.primaryHover : AppColors.primaryDark,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => posProvider.addToCart(product),
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(Icons.add_rounded, size: 15, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF0D9488) : AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 13,
                              color: isDark ? AppColors.primaryHover : AppColors.primaryDark,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Tambah',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.primaryHover : AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
