import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../providers/pos_provider.dart';
import '../widgets/checkout_sheet.dart';
import 'scanner_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();

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

  void _openCheckout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CheckoutSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);

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
          // Tombol Pindai Barcode Kamera
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
              onChanged: (val) => posProvider.loadProducts(search: val),
              decoration: InputDecoration(
                hintText: 'Cari nama produk atau kode barcode...',
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
                            Text(
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

      // Sticky Bottom Cart Bar
      bottomSheet: posProvider.cart.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Badge & Total
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
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tombol Bayar
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onPressed: () => _openCheckout(context),
                      child: const Row(
                        children: [
                          Text('Bayar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 16),
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

  Widget _buildProductCard(BuildContext context, Product product, PosProvider posProvider) {
    // Check if in cart
    final cartItem = posProvider.cart.cast<CartItem?>().firstWhere(
          (item) => item?.product.id == product.id,
          orElse: () => null,
        );

    final isLowStock = product.stock <= 5;
    final isOutOfStock = product.stock <= 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cartItem != null ? AppColors.primary : AppColors.border,
          width: cartItem != null ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isOutOfStock ? null : () => posProvider.addToCart(product),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top tag (Stock & Category)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? AppColors.danger.withOpacity(0.1)
                          : isLowStock
                              ? AppColors.warning.withOpacity(0.15)
                              : AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOutOfStock ? 'Habis' : 'Stok: ${product.stock}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? AppColors.danger
                            : isLowStock
                                ? AppColors.warning
                                : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Name
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMain),
              ),
              const SizedBox(height: 6),
              // Price
              Text(
                CurrencyFormatter.format(product.price),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const SizedBox(height: 8),

              // Cart Quantity control / Add button
              if (cartItem != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => posProvider.decreaseQuantity(product),
                        child: const Icon(Icons.remove_circle, size: 22, color: AppColors.primaryDark),
                      ),
                      Text(
                        '${cartItem.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                      ),
                      InkWell(
                        onTap: () => posProvider.addToCart(product),
                        child: const Icon(Icons.add_circle, size: 22, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: isOutOfStock ? AppColors.border : AppColors.primary),
                    ),
                    onPressed: isOutOfStock ? null : () => posProvider.addToCart(product),
                    child: Text(
                      isOutOfStock ? 'Stok Habis' : '+ Tambah',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock ? AppColors.textMuted : AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
