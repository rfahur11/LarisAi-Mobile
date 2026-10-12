import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../data/national_sku_data.dart';
import '../models/product_model.dart';
import '../providers/pos_provider.dart';

/// Dialog Modal Cepat saat Barcode ditemukan di Master SKU Nasional
/// Memungkinkan kasir menambahkan produk baru ke toko dalam 2 detik tanpa mengetik nama produk.
class QuickAddMasterSkuDialog extends StatefulWidget {
  final MasterSkuItem masterItem;
  final String barcode;
  final bool autoAddToCart;

  const QuickAddMasterSkuDialog({
    super.key,
    required this.masterItem,
    required this.barcode,
    this.autoAddToCart = false,
  });

  @override
  State<QuickAddMasterSkuDialog> createState() => _QuickAddMasterSkuDialogState();
}

class _QuickAddMasterSkuDialogState extends State<QuickAddMasterSkuDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.masterItem.name);
    _categoryController = TextEditingController(text: widget.masterItem.category);
    _priceController = TextEditingController(
      text: widget.masterItem.defaultPriceEstimate > 0
          ? widget.masterItem.defaultPriceEstimate.toString()
          : '',
    );
    _stockController = TextEditingController(text: '12'); // default 1 lusin
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final price = int.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final stock = int.tryParse(_stockController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Mohon masukkan harga jual yang valid (> Rp 0)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final posProvider = Provider.of<PosProvider>(context, listen: false);

      final newProduct = Product(
        id: '',
        barcode: widget.barcode,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? 'Umum' : _categoryController.text.trim(),
        price: price,
        stock: stock,
      );

      final success = await posProvider.addNewProduct(newProduct);

      if (!mounted) return;

      if (success) {
        if (widget.autoAddToCart) {
          posProvider.addToCart(newProduct);
        }

        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${newProduct.name}" berhasil ditambahkan ke inventori!'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Gagal menambahkan produk. Periksa koneksi atau duplikasi barcode.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Terjadi kesalahan: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                '⚡ Master SKU Nasional',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Produk Baru Terdeteksi!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Barcode: ${widget.barcode}',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Nama Produk (Auto-filled)
              _buildLabel('Nama Produk', isDark),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration(
                  hint: 'Nama Produk',
                  prefixIcon: Icons.shopping_bag_outlined,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 12),

              // Kategori (Auto-filled)
              _buildLabel('Kategori Produk', isDark),
              TextField(
                controller: _categoryController,
                decoration: _inputDecoration(
                  hint: 'Kategori Produk',
                  prefixIcon: Icons.category_outlined,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 12),

              // Row: Harga Jual & Stok
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Harga Jual (Rp) *', isDark),
                        TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _inputDecoration(
                            hint: 'Contoh: 3500',
                            prefixIcon: Icons.payments_outlined,
                            isDark: isDark,
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
                        _buildLabel('Stok Fisik Awal', isDark),
                        TextField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _inputDecoration(
                            hint: 'Jumlah pcs',
                            prefixIcon: Icons.inventory_2_outlined,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Menyimpan ke Toko...' : '⚡ Tambahkan ke Toko Sekarang',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextMuted : Colors.grey.shade700,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 18, color: isDark ? AppColors.darkTextMuted : Colors.grey.shade500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
