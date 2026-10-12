import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/product_model.dart';
import '../providers/pos_provider.dart';
import '../widgets/settings_dialog.dart';
import '../services/image_storage_service.dart';
import '../widgets/product_image_thumbnail.dart';
import 'scanner_screen.dart';
import '../data/national_sku_data.dart';
import '../widgets/quick_add_master_sku_dialog.dart';

enum StockFilterType { all, outOfStock, lowStock, inStock, custom }
enum StockOperator { lte, eq, gte }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _stockInputController = TextEditingController();
  StockFilterType _selectedStockFilter = StockFilterType.all;
  StockOperator _customStockOperator = StockOperator.lte;
  String _selectedCategory = 'Semua';
  int _customStockThreshold = 10;

  @override
  void dispose() {
    _searchController.dispose();
    _stockInputController.dispose();
    super.dispose();
  }

  void _showAddProductDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barcodeController = TextEditingController();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    String category = 'Makanan';
    String? selectedImagePath;
    String? nameError;
    String? priceError;
    String? stockError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.add_box_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Tambah Produk Baru',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Picker
                _buildImagePickerSection(
                  context: context,
                  setModalState: setModalState,
                  imagePath: selectedImagePath,
                  onImageChanged: (path) => selectedImagePath = path,
                  isDark: isDark,
                ),

                // Barcode input with scan button
                Text('Barcode / SKU (Opsional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: barcodeController,
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                        decoration: InputDecoration(
                          hintText: 'Kode barcode / auto-generate',
                          hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () async {
                        final code = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(builder: (_) => const ScannerScreen()),
                        );
                        if (code != null) {
                          setModalState(() {
                            barcodeController.text = code;
                            final master = NationalSkuLookup.findByBarcode(code);
                            if (master != null) {
                              if (nameController.text.trim().isEmpty) {
                                nameController.text = master.name;
                              }
                              if (category == 'Umum') {
                                category = master.category;
                              }
                              if (priceController.text.trim().isEmpty && master.defaultPriceEstimate > 0) {
                                priceController.text = master.defaultPriceEstimate.toString();
                              }
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 20, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Name (Required)
                Row(
                  children: [
                    Text('Nama Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                    const SizedBox(width: 4),
                    const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                  onChanged: (_) {
                    if (nameError != null) setModalState(() => nameError = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Contoh: Teh Botol Sosro 450ml',
                    errorText: nameError,
                    hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                Text('Kategori', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                  style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                  ),
                  items: ['Makanan', 'Minuman', 'Sembako', 'Snack', 'Umum']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextMain : AppColors.textMain))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),

                // Price & Stock (Both Required)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Harga Jual (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                              const SizedBox(width: 4),
                              const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              ThousandsSeparatorInputFormatter(),
                            ],
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                            onChanged: (_) {
                              if (priceError != null) setModalState(() => priceError = null);
                            },
                            decoration: InputDecoration(
                              hintText: '0',
                              errorText: priceError,
                              prefixText: 'Rp ',
                              prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.primary),
                              hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                              filled: true,
                              fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
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
                          Row(
                            children: [
                              Text('Jumlah Stok', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                              const SizedBox(width: 4),
                              const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                            onChanged: (_) {
                              if (stockError != null) setModalState(() => stockError = null);
                            },
                            decoration: InputDecoration(
                              hintText: '0',
                              errorText: stockError,
                              suffixText: 'pcs',
                              suffixStyle: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                              hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                              filled: true,
                              fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final barcode = barcodeController.text.trim();
                final price = CurrencyFormatter.parseClean(priceController.text);
                final stockStr = stockController.text.trim();
                final stock = int.tryParse(stockStr);

                bool hasError = false;
                String? newNameErr;
                String? newPriceErr;
                String? newStockErr;

                if (name.isEmpty) {
                  newNameErr = 'Wajib diisi';
                  hasError = true;
                }
                if (price <= 0) {
                  newPriceErr = 'Harus > 0';
                  hasError = true;
                }
                if (stockStr.isEmpty || stock == null || stock < 0) {
                  newStockErr = 'Harus >= 0';
                  hasError = true;
                }

                if (hasError) {
                  setModalState(() {
                    nameError = newNameErr;
                    priceError = newPriceErr;
                    stockError = newStockErr;
                  });
                  return;
                }

                final product = Product(
                  id: '',
                  barcode: barcode.isNotEmpty ? barcode : DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  category: category,
                  price: price,
                  stock: stock!,
                  imagePath: selectedImagePath ?? '',
                );

                final posProv = Provider.of<PosProvider>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                await posProv.addNewProduct(product);
                messenger.showSnackBar(
                  SnackBar(content: Text('✅ $name berhasil ditambahkan ke katalog!'), backgroundColor: AppColors.primary),
                );
              },
              child: const Text('Simpan Produk'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barcodeController = TextEditingController(text: product.barcode);
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: CurrencyFormatter.formatNumber(product.price));
    final stockController = TextEditingController(text: product.stock.toString());
    String category = ['Makanan', 'Minuman', 'Sembako', 'Snack', 'Umum'].contains(product.category)
        ? product.category
        : 'Umum';
    String? nameError;
    String? priceError;
    String? stockError;
    String? selectedImagePath = product.displayImagePath.isNotEmpty ? product.displayImagePath : product.imagePath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Edit Produk',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image Picker
                _buildImagePickerSection(
                  context: context,
                  setModalState: setModalState,
                  imagePath: selectedImagePath,
                  productName: product.name,
                  barcode: product.barcode,
                  onImageChanged: (path) => selectedImagePath = path,
                  isDark: isDark,
                ),

                Text('Barcode / SKU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: barcodeController,
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                        decoration: InputDecoration(
                          hintText: 'Kode barcode',
                          hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () async {
                        final code = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(builder: (_) => const ScannerScreen()),
                        );
                        if (code != null) {
                          setModalState(() {
                            barcodeController.text = code;
                            final master = NationalSkuLookup.findByBarcode(code);
                            if (master != null) {
                              if (nameController.text.trim().isEmpty) {
                                nameController.text = master.name;
                              }
                              if (category == 'Umum') {
                                category = master.category;
                              }
                              if (priceController.text.trim().isEmpty && master.defaultPriceEstimate > 0) {
                                priceController.text = master.defaultPriceEstimate.toString();
                              }
                            }
                          });
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 20, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Nama Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                    const SizedBox(width: 4),
                    const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                  onChanged: (_) {
                    if (nameError != null) setModalState(() => nameError = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Contoh: Teh Botol Sosro 450ml',
                    errorText: nameError,
                    hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Kategori', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                  style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                  ),
                  items: ['Makanan', 'Minuman', 'Sembako', 'Snack', 'Umum']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextMain : AppColors.textMain))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Harga Jual (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                              const SizedBox(width: 4),
                              const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              ThousandsSeparatorInputFormatter(),
                            ],
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                            onChanged: (_) {
                              if (priceError != null) setModalState(() => priceError = null);
                            },
                            decoration: InputDecoration(
                              hintText: '0',
                              errorText: priceError,
                              prefixText: 'Rp ',
                              prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.primary),
                              hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                              filled: true,
                              fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
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
                          Row(
                            children: [
                              Text('Jumlah Stok', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                              const SizedBox(width: 4),
                              const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                            onChanged: (_) {
                              if (stockError != null) setModalState(() => stockError = null);
                            },
                            decoration: InputDecoration(
                              hintText: '0',
                              errorText: stockError,
                              suffixText: 'pcs',
                              suffixStyle: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                              hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : null),
                              filled: true,
                              fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final barcode = barcodeController.text.trim();
                final price = CurrencyFormatter.parseClean(priceController.text);
                final stockStr = stockController.text.trim();
                final stock = int.tryParse(stockStr);

                bool hasError = false;
                String? newNameErr;
                String? newPriceErr;
                String? newStockErr;

                if (name.isEmpty) {
                  newNameErr = 'Wajib diisi';
                  hasError = true;
                }
                if (price <= 0) {
                  newPriceErr = 'Harus > 0';
                  hasError = true;
                }
                if (stockStr.isEmpty || stock == null || stock < 0) {
                  newStockErr = 'Harus >= 0';
                  hasError = true;
                }

                if (hasError) {
                  setModalState(() {
                    nameError = newNameErr;
                    priceError = newPriceErr;
                    stockError = newStockErr;
                  });
                  return;
                }

                if (product.imagePath.isNotEmpty && product.imagePath != selectedImagePath) {
                  ImageStorageService.instance.deleteProductImage(product.imagePath);
                }

                final updated = product.copyWith(
                  barcode: barcode.isNotEmpty ? barcode : product.barcode,
                  name: name,
                  category: category,
                  price: price,
                  stock: stock!,
                  imagePath: selectedImagePath ?? '',
                );

                final posProv = Provider.of<PosProvider>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                await posProv.updateProduct(updated);
                messenger.showSnackBar(
                  SnackBar(content: Text('✅ $name berhasil diperbarui!'), backgroundColor: AppColors.primary),
                );
              },
              child: const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteProductDialog(BuildContext context, Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Text(
              'Hapus Produk?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
            ),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus "${product.name}" dari katalog produk? Tindakan ini akan menghapus data produk secara permanen.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final posProv = Provider.of<PosProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              await posProv.deleteProduct(product.id);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('🗑️ ${product.name} berhasil dihapus dari inventori.'),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            },
            child: const Text('Hapus Produk'),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerSection({
    required BuildContext context,
    required void Function(void Function()) setModalState,
    required String? imagePath,
    String? productName,
    String? barcode,
    required ValueChanged<String?> onImageChanged,
    required bool isDark,
  }) {
    final hasImage = imagePath != null && imagePath.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Foto Produk (Opsional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
            ),
          ),
          const SizedBox(height: 6),
          if (hasImage)
            Container(
              constraints: const BoxConstraints(minHeight: 90),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ProductImageThumbnail(
                      imagePath: imagePath,
                      productName: productName,
                      barcode: barcode,
                      width: 74,
                      height: 74,
                      borderRadius: 10,
                      fallback: Container(
                        width: 74,
                        height: 74,
                        color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                        child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: BorderSide(color: isDark ? AppColors.primaryHover : AppColors.primary),
                          ),
                          onPressed: () async {
                            final newPath = await ImageStorageService.instance.pickAndSaveProductImage('img');
                            if (newPath != null) {
                              setModalState(() => onImageChanged(newPath));
                            }
                          },
                          icon: const Icon(Icons.photo_camera_rounded, size: 14),
                          label: const Text('Ganti Foto', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            foregroundColor: AppColors.danger,
                          ),
                          onPressed: () {
                            setModalState(() => onImageChanged(''));
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 14),
                          label: const Text('Hapus Foto', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: () async {
                final newPath = await ImageStorageService.instance.pickAndSaveProductImage('new');
                if (newPath != null) {
                  setModalState(() => onImageChanged(newPath));
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.primaryHover : AppColors.primary).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_a_photo_rounded,
                        size: 18,
                        color: isDark ? AppColors.primaryHover : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Pilih Foto dari Galeri / File',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// High-resolution preview dialog with hero animation and product details
  void _showProductImagePreviewModal(BuildContext context, Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Image Preview Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                    child: Hero(
                      tag: 'product_img_${product.id}',
                      child: ProductImageThumbnail(
                        imagePath: product.displayImagePath,
                        productName: product.name,
                        barcode: product.barcode,
                        width: double.infinity,
                        height: 220,
                        borderRadius: 16,
                        fit: BoxFit.contain,
                        fallback: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_rounded, size: 56, color: isDark ? AppColors.darkTextMuted : Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada foto produk',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Product Info & Quick Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Barcode: ${product.barcode.isNotEmpty ? product.barcode : '-'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CurrencyFormatter.format(product.price),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.stock > 5
                                ? (isDark ? const Color(0xFF042F2E) : AppColors.primaryLight)
                                : (isDark ? const Color(0xFF451A03) : Colors.amber.shade50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Stok: ${product.stock} pcs',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: product.stock > 5 ? AppColors.primaryDark : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditProductDialog(context, product);
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit Produk / Ganti Foto', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomStockFilterDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int tempVal = _customStockThreshold;
    StockOperator tempOp = _customStockOperator;
    final textEditCtrl = TextEditingController(text: tempVal.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          String opSymbol = tempOp == StockOperator.eq ? '=' : (tempOp == StockOperator.gte ? '≥' : '≤');
          String opLabel = tempOp == StockOperator.eq 
              ? 'Tepat Sama Dengan' 
              : (tempOp == StockOperator.gte ? 'Lebih Dari / Sama Dengan' : 'Kurang Dari / Sama Dengan');

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Filter Jumlah Stok Kustom',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih operator dan masukkan jumlah target stok:',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),

                  // 1. Operator Selector Chips
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('≤ Kurang / Sama', style: TextStyle(fontSize: 11)),
                          selected: tempOp == StockOperator.lte,
                          selectedColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                          onSelected: (_) => setDialogState(() => tempOp = StockOperator.lte),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('= Tepat Sama', style: TextStyle(fontSize: 11)),
                          selected: tempOp == StockOperator.eq,
                          selectedColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                          onSelected: (_) => setDialogState(() => tempOp = StockOperator.eq),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('≥ Lebih / Sama', style: TextStyle(fontSize: 11)),
                          selected: tempOp == StockOperator.gte,
                          selectedColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                          onSelected: (_) => setDialogState(() => tempOp = StockOperator.gte),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Value Indicator + Numeric Input Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opLabel, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                            Text(
                              'Stok $opSymbol $tempVal unit',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? AppColors.primaryHover : AppColors.primaryDark),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: textEditCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppColors.darkTextMain : AppColors.textMain),
                            decoration: InputDecoration(
                              hintText: '0',
                              filled: true,
                              fillColor: isDark ? AppColors.darkCard : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                            ),
                            onChanged: (val) {
                              final numVal = int.tryParse(val) ?? 0;
                              setDialogState(() {
                                tempVal = numVal.clamp(0, 9999);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Interactive Slider
                  Slider(
                    value: tempVal.clamp(0, 100).toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setDialogState(() {
                        tempVal = val.round();
                        textEditCtrl.text = tempVal.toString();
                      });
                    },
                  ),

                  // 4. Quick Presets
                  Text('Pilihan Cepat:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('🔴 Habis (= 0)', style: TextStyle(fontSize: 10)),
                        backgroundColor: isDark ? AppColors.darkSurface : null,
                        onPressed: () => setDialogState(() {
                          tempOp = StockOperator.eq;
                          tempVal = 0;
                          textEditCtrl.text = '0';
                        }),
                      ),
                      ActionChip(
                        label: const Text('🟡 Menipis (≤ 5)', style: TextStyle(fontSize: 10)),
                        backgroundColor: isDark ? AppColors.darkSurface : null,
                        onPressed: () => setDialogState(() {
                          tempOp = StockOperator.lte;
                          tempVal = 5;
                          textEditCtrl.text = '5';
                        }),
                      ),
                      ActionChip(
                        label: const Text('🟠 Kritis (≤ 10)', style: TextStyle(fontSize: 10)),
                        backgroundColor: isDark ? AppColors.darkSurface : null,
                        onPressed: () => setDialogState(() {
                          tempOp = StockOperator.lte;
                          tempVal = 10;
                          textEditCtrl.text = '10';
                        }),
                      ),
                      ActionChip(
                        label: const Text('🟢 Stok (≥ 20)', style: TextStyle(fontSize: 10)),
                        backgroundColor: isDark ? AppColors.darkSurface : null,
                        onPressed: () => setDialogState(() {
                          tempOp = StockOperator.gte;
                          tempVal = 20;
                          textEditCtrl.text = '20';
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: TextStyle(color: isDark ? AppColors.darkTextMuted : null)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _customStockThreshold = tempVal;
                    _customStockOperator = tempOp;
                    _selectedStockFilter = StockFilterType.custom;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Terapkan Filter'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Product> _getFilteredProducts(List<Product> allProducts) {
    final query = _searchController.text.trim().toLowerCase();

    return allProducts.where((p) {
      // 1. Search Query (Name or Barcode)
      if (query.isNotEmpty) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesBarcode = p.barcode.toLowerCase().contains(query);
        if (!matchesName && !matchesBarcode) return false;
      }

      // 2. Category Filter
      if (_selectedCategory != 'Semua') {
        if (p.category != _selectedCategory) return false;
      }

      // 3. Stock Status Filter
      switch (_selectedStockFilter) {
        case StockFilterType.all:
          return true;
        case StockFilterType.outOfStock:
          return p.stock <= 0;
        case StockFilterType.lowStock:
          return p.stock > 0 && p.stock <= 5;
        case StockFilterType.inStock:
          return p.stock > 5;
        case StockFilterType.custom:
          if (_customStockOperator == StockOperator.eq) {
            return p.stock == _customStockThreshold;
          } else if (_customStockOperator == StockOperator.gte) {
            return p.stock >= _customStockThreshold;
          } else {
            return p.stock <= _customStockThreshold;
          }
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final posProvider = Provider.of<PosProvider>(context);
    final allProducts = posProvider.products;
    final filteredProducts = _getFilteredProducts(allProducts);

    final isMobile = MediaQuery.of(context).size.width < 700;
    final totalStockUnits = allProducts.fold<int>(0, (sum, p) => sum + p.stock);
    final totalInventoryValue = allProducts.fold<int>(0, (sum, p) => sum + (p.price * p.stock));
    final outOfStockCount = allProducts.where((p) => p.stock <= 0).length;
    final lowStockCount = allProducts.where((p) => p.stock > 0 && p.stock <= 5).length;
    final inStockCount = allProducts.where((p) => p.stock > 5).length;
    final isCustomFilterActive = _selectedStockFilter == StockFilterType.custom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Katalog & Manajemen Stok',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
              ),
            ),
            Text(
              'Pencarian, Filter Stok & Kontrol Inventori',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
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
            child: isMobile
                ? IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                    tooltip: 'Tambah Produk',
                    onPressed: () => _showAddProductDialog(context),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => _showAddProductDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Overview Metric Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
            ),
            child: isMobile
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildMobileMetricCard(
                          label: 'Total Produk',
                          value: '${allProducts.length} Item',
                          icon: Icons.inventory_2_outlined,
                          color: Colors.blue,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildMobileMetricCard(
                          label: 'Total Stok Fisik',
                          value: '$totalStockUnits Unit',
                          icon: Icons.layers_outlined,
                          color: AppColors.primary,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildMobileMetricCard(
                          label: 'Nilai Aset Stok',
                          value: CurrencyFormatter.format(totalInventoryValue),
                          icon: Icons.account_balance_wallet_outlined,
                          color: Colors.purple,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      _buildHeaderMiniStat(
                        label: 'Total Produk',
                        value: '${allProducts.length} Item',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.blue,
                        isDark: isDark,
                      ),
                      _buildVerticalDivider(isDark),
                      _buildHeaderMiniStat(
                        label: 'Total Stok Fisik',
                        value: '$totalStockUnits Unit',
                        icon: Icons.layers_outlined,
                        color: AppColors.primary,
                        isDark: isDark,
                      ),
                      _buildVerticalDivider(isDark),
                      _buildHeaderMiniStat(
                        label: 'Nilai Aset Stok',
                        value: CurrencyFormatter.format(totalInventoryValue),
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.purple,
                        isDark: isDark,
                      ),
                    ],
                  ),
          ),

          // 2. Search Box, Quick Scan & Custom Filter
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            color: isDark ? AppColors.darkBackground : AppColors.background,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk, SKU, barcode...',
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Scan Barcode Kamera',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final code = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const ScannerScreen()),
                    );
                    if (code != null && mounted) {
                      _searchController.text = code;
                      setState(() {});
                      final posProvider = Provider.of<PosProvider>(context, listen: false);
                      final existing = posProvider.products.where((p) => p.barcode == code).firstOrNull;
                      if (existing == null) {
                        final masterItem = NationalSkuLookup.findByBarcode(code);
                        if (masterItem != null) {
                          showDialog<bool>(
                            context: context,
                            builder: (_) => QuickAddMasterSkuDialog(
                              masterItem: masterItem,
                              barcode: code,
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 8),
                // Custom Filter Button with Active Indicator
                IconButton.filledTonal(
                  tooltip: 'Filter Stok Kustom',
                  style: IconButton.styleFrom(
                    backgroundColor: isCustomFilterActive
                        ? AppColors.accent
                        : (isDark ? AppColors.darkCard : Colors.grey.shade200),
                    foregroundColor: isCustomFilterActive
                        ? Colors.white
                        : (isDark ? AppColors.darkTextMain : AppColors.textMain),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isCustomFilterActive
                            ? AppColors.accent
                            : (isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                    ),
                  ),
                  onPressed: () => _showCustomStockFilterDialog(context),
                  icon: Badge(
                    isLabelVisible: isCustomFilterActive,
                    smallSize: 8,
                    backgroundColor: Colors.amber,
                    child: Icon(
                      isCustomFilterActive ? Icons.filter_alt_rounded : Icons.tune_rounded,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Custom Filter Pill Banner (if engaged)
          if (isCustomFilterActive)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? AppColors.accent : Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 15, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filter Kustom: Stok ${_customStockOperator == StockOperator.eq ? '=' : (_customStockOperator == StockOperator.gte ? '≥' : '≤')} $_customStockThreshold unit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStockFilter = StockFilterType.all;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.close_rounded, size: 13, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. Stock Status Segmented Bar (Zero Horizontal Scroll)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Row(
              children: [
                _buildStockSegment(
                  title: 'Semua',
                  count: allProducts.length,
                  filterType: StockFilterType.all,
                  isDark: isDark,
                ),
                _buildStockSegment(
                  title: 'Habis',
                  count: outOfStockCount,
                  filterType: StockFilterType.outOfStock,
                  dotColor: AppColors.danger,
                  isDark: isDark,
                ),
                _buildStockSegment(
                  title: 'Menipis',
                  count: lowStockCount,
                  filterType: StockFilterType.lowStock,
                  dotColor: AppColors.warning,
                  isDark: isDark,
                ),
                _buildStockSegment(
                  title: 'Aman',
                  count: inStockCount,
                  filterType: StockFilterType.inStock,
                  dotColor: AppColors.success,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // 4. Category Filter Bar
          Container(
            height: 38,
            padding: const EdgeInsets.only(bottom: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: posProvider.categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (ctx, idx) {
                final cat = posProvider.categories[idx];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 11,
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
          const SizedBox(height: 4),

          // 5. Product List with Stock Indicators
          Expanded(
            child: posProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 54, color: isDark ? AppColors.darkTextMuted : Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada produk yang cocok dengan filter',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Coba ubah kata kunci pencarian atau reset filter stok',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _selectedStockFilter = StockFilterType.all;
                                  _selectedCategory = 'Semua';
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Reset Filter'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: filteredProducts.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final product = filteredProducts[idx];
                          final isOutOfStock = product.stock <= 0;
                          final isLowStock = product.stock > 0 && product.stock <= 5;

                          return Material(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _showEditProductDialog(context, product),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.border,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    // Product Image Thumbnail with Tap-to-Preview Modal & Hero Zoom
                                    InkResponse(
                                      onTap: () => _showProductImagePreviewModal(context, product),
                                      radius: 30,
                                      child: Hero(
                                        tag: 'product_img_${product.id}',
                                        child: ProductImageThumbnail(
                                          imagePath: product.displayImagePath,
                                          productName: product.name,
                                          barcode: product.barcode,
                                          width: 48,
                                          height: 48,
                                          borderRadius: 12,
                                          fallback: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isOutOfStock
                                                  ? (isDark ? const Color(0xFF450A0A) : Colors.red.shade50)
                                                  : (isLowStock
                                                      ? (isDark ? const Color(0xFF451A03) : Colors.amber.shade50)
                                                      : (isDark ? const Color(0xFF042F2E) : AppColors.primaryLight)),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              isOutOfStock
                                                  ? Icons.remove_shopping_cart_rounded
                                                  : (isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_rounded),
                                              color: isOutOfStock
                                                  ? AppColors.danger
                                                  : (isLowStock ? AppColors.warning : AppColors.primaryDark),
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Product Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Icon(Icons.qr_code, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  product.barcode,
                                                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    product.category,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            CurrencyFormatter.format(product.price),
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Stock Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: isOutOfStock
                                            ? Colors.red.withValues(alpha: 0.15)
                                            : (isLowStock
                                                ? Colors.amber.withValues(alpha: 0.2)
                                                : Colors.teal.withValues(alpha: 0.15)),
                                        borderRadius: BorderRadius.circular(7),
                                        border: Border.all(
                                          color: isOutOfStock
                                              ? AppColors.danger
                                              : (isLowStock ? AppColors.warning : AppColors.success),
                                        ),
                                      ),
                                      child: Text(
                                        isOutOfStock ? 'HABIS' : '${product.stock} pcs',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isOutOfStock
                                              ? AppColors.danger
                                              : (isLowStock ? AppColors.warning : AppColors.success),
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 2),

                                    // Popup Action Menu
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert, size: 20, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      color: isDark ? AppColors.darkCard : Colors.white,
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showEditProductDialog(context, product);
                                        } else if (val == 'delete') {
                                          _showDeleteProductDialog(context, product);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                              const SizedBox(width: 8),
                                              Text('Edit Produk', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMain : AppColors.textMain)),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: const [
                                              Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                              SizedBox(width: 8),
                                              Text('Hapus Produk', style: TextStyle(fontSize: 13, color: AppColors.danger)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSegment({
    required String title,
    required int count,
    required StockFilterType filterType,
    Color? dotColor,
    required bool isDark,
  }) {
    final isSelected = _selectedStockFilter == filterType;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedStockFilter = filterType;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.primary.withValues(alpha: 0.25) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
            border: isSelected
                ? Border.all(
                    color: isDark ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                            : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
                      : (isDark ? AppColors.darkTextMain : AppColors.textMain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMiniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      height: 28,
      width: 1,
      color: isDark ? AppColors.darkBorder : AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
}
