import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../providers/pos_provider.dart';
import '../widgets/checkout_sheet.dart';
import '../widgets/receipt_dialog.dart';
import 'scanner_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _desktopPaymentType = 'TUNAI';
  int _desktopCashTendered = 0;
  bool _isProcessingCheckout = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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

    setState(() => _isProcessingCheckout = true);

    final tx = await posProvider.processCheckout(
      paymentType: _desktopPaymentType,
    );

    setState(() => _isProcessingCheckout = false);

    if (!context.mounted) return;

    if (tx != null) {
      showDialog(
        context: context,
        builder: (_) => ReceiptDialog(
          transaction: tx,
          cashTendered: _desktopPaymentType == 'TUNAI' ? _desktopCashTendered : tx.totalAmount,
        ),
      );
      setState(() {
        _desktopCashTendered = 0;
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
          setState(() => _desktopPaymentType = 'TUNAI');
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
    int crossAxisCount = 3;
    if (screenWidth >= 1400) {
      crossAxisCount = 5;
    } else if (screenWidth >= 1100) {
      crossAxisCount = 4;
    }

    return Scaffold(
      body: Row(
        children: [
          // LEFT PANEL: Catalog, Search & Categories (Flex 3)
          Expanded(
            flex: 3,
            child: Container(
              color: AppColors.background,
              child: Column(
                children: [
                  // Desktop Top Action Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    color: Colors.white,
                    child: Row(
                      children: [
                        // Search Box (F1)
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (val) => posProvider.loadProducts(search: val),
                            decoration: InputDecoration(
                              hintText: 'Cari produk atau scan barcode... (Tekan F1)',
                              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
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
                    color: Colors.white,
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
                          selectedColor: AppColors.primaryLight,
                          backgroundColor: Colors.grey.shade50,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),

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
                                  childAspectRatio: 0.88,
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
              color: Colors.white,
              border: const Border(left: BorderSide(color: AppColors.border, width: 1.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shopping_cart_rounded, color: AppColors.primaryDark, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Keranjang Belanja', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${posProvider.totalItems} item dipilih', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_shopping_cart_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 10),
                              const Text('Keranjang Masih Kosong', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              const Text('Pilih barang di katalog atau scan barcode', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: posProvider.cart.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (ctx, idx) {
                            final item = posProvider.cart[idx];
                            return _buildDesktopCartRow(item, posProvider);
                          },
                        ),
                ),

                // Payment & Checkout Area
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: const Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      // Total Breakdown Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Tagihan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                Text(
                                  CurrencyFormatter.format(posProvider.totalAmount),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                                ),
                              ],
                            ),
                            if (_desktopPaymentType == 'TUNAI' && _desktopCashTendered > 0) ...[
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Diterima', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                  Text(CurrencyFormatter.format(_desktopCashTendered), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Kembalian', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                                  Text(
                                    CurrencyFormatter.format((_desktopCashTendered - posProvider.totalAmount).clamp(0, 99999999)),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.success),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Payment Method Selector Pills (F7 Tunai, F8 QRIS)
                      Row(
                        children: [
                          _buildPaymentPill('TUNAI', '💵 Tunai (F7)', _desktopPaymentType == 'TUNAI'),
                          const SizedBox(width: 8),
                          _buildPaymentPill('QRIS', '📱 QRIS (F8)', _desktopPaymentType == 'QRIS'),
                          const SizedBox(width: 8),
                          _buildPaymentPill('DEBIT', '💳 Debit', _desktopPaymentType == 'DEBIT'),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Quick Cash Buttons if Tunai
                      if (_desktopPaymentType == 'TUNAI' && posProvider.totalAmount > 0)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildQuickCashChip('Uang Pas', posProvider.totalAmount),
                            _buildQuickCashChip('10k', 10000),
                            _buildQuickCashChip('20k', 20000),
                            _buildQuickCashChip('50k', 50000),
                            _buildQuickCashChip('100k', 100000),
                          ],
                        ),

                      const SizedBox(height: 14),

                      // Selesaikan Transaksi (F9) Big Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
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

  Widget _buildPaymentPill(String type, String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _desktopPaymentType = type;
          if (type != 'TUNAI') _desktopCashTendered = 0;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primaryDark : AppColors.textMain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCashChip(String label, int amount) {
    return InkWell(
      onTap: () => setState(() => _desktopCashTendered = amount),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _desktopCashTendered == amount ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _desktopCashTendered == amount ? Colors.white : AppColors.textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCartRow(CartItem item, PosProvider posProvider) {
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.format(item.product.price),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.textMuted),
                onPressed: () => posProvider.decreaseQuantity(item.product),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LarisAI Kasir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Mode POS Kasir Cepat', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => _openScanner(context),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Scan', style: TextStyle(fontSize: 13)),
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
              decoration: InputDecoration(
                hintText: 'Cari nama produk atau barcode...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
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
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final cat = posProvider.categories[idx];
                final isSelected = posProvider.selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => posProvider.setCategory(cat),
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
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
                            const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'Produk tidak ditemukan',
                              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
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
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${posProvider.totalItems} Produk',
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onPressed: () => _openMobileCheckout(context),
                      child: const Row(
                        children: [
                          Text('Bayar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 18),
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
    final cartIndex = posProvider.cart.indexWhere((c) => c.product.id == product.id);
    final inCartQty = cartIndex >= 0 ? posProvider.cart[cartIndex].quantity : 0;
    final isOutOfStock = product.stock <= 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: inCartQty > 0 ? AppColors.primary : AppColors.border,
          width: inCartQty > 0 ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: isOutOfStock ? null : () => posProvider.addToCart(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge Area
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'Stok: ${product.stock}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: product.stock <= 5 ? AppColors.danger : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Middle Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textMain,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.format(product.price),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        if (product.barcode.isNotEmpty)
                          Text(
                            product.barcode,
                            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Cart Button or Quantity Counter
            if (isOutOfStock)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Text(
                  'Habis',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                ),
              )
            else if (inCartQty > 0)
              Container(
                color: AppColors.primaryLight,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => posProvider.decreaseQuantity(product),
                      child: const Icon(Icons.remove, size: 18, color: AppColors.primaryDark),
                    ),
                    Text(
                      '$inCartQty di Keranjang',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    InkWell(
                      onTap: () => posProvider.addToCart(product),
                      child: const Icon(Icons.add, size: 18, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: AppColors.primary.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_shopping_cart, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Tambah',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
