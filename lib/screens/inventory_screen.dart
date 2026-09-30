import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../models/product_model.dart';
import '../providers/pos_provider.dart';
import 'scanner_screen.dart';

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
              Text('Tambah Produk Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barcode input with scan button
                const Text('Barcode / SKU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: barcodeController,
                        decoration: const InputDecoration(
                          hintText: 'Kode barcode',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          });
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Name
                const Text('Nama Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Teh Botol Sosro 450ml',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                const Text('Kategori', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: ['Makanan', 'Minuman', 'Sembako', 'Snack', 'Umum']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),

                // Price & Stock
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Harga Jual (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '10000',
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
                          const Text('Jumlah Stok', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '50',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final barcode = barcodeController.text.trim();
                final price = int.tryParse(priceController.text.trim()) ?? 0;
                final stock = int.tryParse(stockController.text.trim()) ?? 0;

                if (name.isEmpty || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lengkapi nama dan harga produk!'), backgroundColor: AppColors.danger),
                  );
                  return;
                }

                final product = Product(
                  id: '',
                  barcode: barcode.isNotEmpty ? barcode : DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  category: category,
                  price: price,
                  stock: stock,
                );

                await Provider.of<PosProvider>(context, listen: false).addNewProduct(product);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ $name berhasil ditambahkan ke katalog!'), backgroundColor: AppColors.primary),
                  );
                }
              },
              child: const Text('Simpan Produk'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomStockFilterDialog(BuildContext context) {
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Filter Jumlah Stok Kustom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih operator dan masukkan jumlah target stok:',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),

                  // 1. Operator Selector Chips
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('≤ Kurang / Sama', style: TextStyle(fontSize: 11)),
                          selected: tempOp == StockOperator.lte,
                          selectedColor: AppColors.primaryLight,
                          onSelected: (_) => setDialogState(() => tempOp = StockOperator.lte),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('= Tepat Sama', style: TextStyle(fontSize: 11)),
                          selected: tempOp == StockOperator.eq,
                          selectedColor: AppColors.primaryLight,
                          onSelected: (_) => setDialogState(() => tempOp = StockOperator.eq),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('≥ Lebih / Sama', style: TextStyle(fontSize: 11)),
                          selected: tempOp == StockOperator.gte,
                          selectedColor: AppColors.primaryLight,
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
                      color: AppColors.primaryLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opLabel, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(
                              'Stok $opSymbol $tempVal unit',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: textEditCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: '0',
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                  const Text('Pilihan Cepat:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('🔴 Habis (= 0)', style: TextStyle(fontSize: 10)),
                        onPressed: () => setDialogState(() {
                          tempOp = StockOperator.eq;
                          tempVal = 0;
                          textEditCtrl.text = '0';
                        }),
                      ),
                      ActionChip(
                        label: const Text('🟡 Menipis (≤ 5)', style: TextStyle(fontSize: 10)),
                        onPressed: () => setDialogState(() {
                          tempOp = StockOperator.lte;
                          tempVal = 5;
                          textEditCtrl.text = '5';
                        }),
                      ),
                      ActionChip(
                        label: const Text('🟠 Kritis (≤ 10)', style: TextStyle(fontSize: 10)),
                        onPressed: () => setDialogState(() {
                          tempOp = StockOperator.lte;
                          tempVal = 10;
                          textEditCtrl.text = '10';
                        }),
                      ),
                      ActionChip(
                        label: const Text('🟢 Stok (≥ 20)', style: TextStyle(fontSize: 10)),
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
                child: const Text('Batal'),
              ),
              ElevatedButton(
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

    final totalStockUnits = allProducts.fold<int>(0, (sum, p) => sum + p.stock);
    final totalInventoryValue = allProducts.fold<int>(0, (sum, p) => sum + (p.price * p.stock));
    final outOfStockCount = allProducts.where((p) => p.stock <= 0).length;
    final lowStockCount = allProducts.where((p) => p.stock > 0 && p.stock <= 5).length;

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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => _showAddProductDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('+ Tambah Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Overview Metric Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
            ),
            child: Row(
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

          // 2. Search Box & Quick Scan
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: isDark ? AppColors.darkBackground : AppColors.background,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk, SKU, atau barcode...',
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
                const SizedBox(width: 10),
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
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
                ),
              ],
            ),
          ),

          // 3. Stock Status Filter Chips Bar
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStockFilterChip(
                  label: 'Semua Stok (${allProducts.length})',
                  filterType: StockFilterType.all,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                _buildStockFilterChip(
                  label: '🔴 Habis ($outOfStockCount)',
                  filterType: StockFilterType.outOfStock,
                  badgeColor: AppColors.danger,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                _buildStockFilterChip(
                  label: '🟡 Menipis ≤5 ($lowStockCount)',
                  filterType: StockFilterType.lowStock,
                  badgeColor: AppColors.warning,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                _buildStockFilterChip(
                  label: '🟢 Aman >5',
                  filterType: StockFilterType.inStock,
                  badgeColor: AppColors.success,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                // Custom Threshold Chip
                ActionChip(
                  avatar: Icon(
                    _selectedStockFilter == StockFilterType.custom ? Icons.filter_alt_rounded : Icons.tune_rounded,
                    size: 14,
                    color: _selectedStockFilter == StockFilterType.custom ? Colors.white : AppColors.accent,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedStockFilter == StockFilterType.custom
                            ? '🔢 Stok ${_customStockOperator == StockOperator.eq ? '=' : (_customStockOperator == StockOperator.gte ? '≥' : '≤')} $_customStockThreshold unit'
                            : '🔢 Filter Stok Kustom...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedStockFilter == StockFilterType.custom ? FontWeight.bold : FontWeight.normal,
                          color: _selectedStockFilter == StockFilterType.custom ? Colors.white : (isDark ? AppColors.darkTextMain : AppColors.textMain),
                        ),
                      ),
                      if (_selectedStockFilter == StockFilterType.custom) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedStockFilter = StockFilterType.all;
                            });
                          },
                          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                  backgroundColor: _selectedStockFilter == StockFilterType.custom
                      ? AppColors.accent
                      : (isDark ? AppColors.darkSurface : Colors.white),
                  side: BorderSide(
                    color: _selectedStockFilter == StockFilterType.custom ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  onPressed: () => _showCustomStockFilterDialog(context),
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
              separatorBuilder: (_, __) => const SizedBox(width: 6),
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
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final product = filteredProducts[idx];
                          final isOutOfStock = product.stock <= 0;
                          final isLowStock = product.stock > 0 && product.stock <= 5;

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
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
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Icon Box
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isOutOfStock
                                        ? (isDark ? const Color(0xFF450A0A) : Colors.red.shade50)
                                        : (isLowStock
                                            ? (isDark ? const Color(0xFF451A03) : Colors.amber.shade50)
                                            : (isDark ? const Color(0xFF042F2E) : AppColors.primaryLight)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isOutOfStock
                                        ? Icons.remove_shopping_cart_rounded
                                        : (isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_rounded),
                                    color: isOutOfStock
                                        ? AppColors.danger
                                        : (isLowStock ? AppColors.warning : AppColors.primaryDark),
                                    size: 22,
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
                                          Text(
                                            product.barcode,
                                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
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

                                // Stock Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isOutOfStock
                                        ? Colors.red.withValues(alpha: 0.15)
                                        : (isLowStock
                                            ? Colors.amber.withValues(alpha: 0.2)
                                            : Colors.teal.withValues(alpha: 0.15)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isOutOfStock
                                          ? AppColors.danger
                                          : (isLowStock ? AppColors.warning : AppColors.success),
                                    ),
                                  ),
                                  child: Text(
                                    isOutOfStock ? 'HABIS (0)' : '${product.stock} pcs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isOutOfStock
                                          ? AppColors.danger
                                          : (isLowStock ? AppColors.warning : AppColors.success),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockFilterChip({
    required String label,
    required StockFilterType filterType,
    Color? badgeColor,
    required bool isDark,
  }) {
    final isSelected = _selectedStockFilter == filterType;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStockFilter = filterType),
      selectedColor: isDark ? const Color(0xFF042F2E) : AppColors.primaryLight,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? (isDark ? AppColors.primaryHover : AppColors.primaryDark)
            : (isDark ? AppColors.darkTextMain : AppColors.textMain),
      ),
      side: BorderSide(
        color: isSelected ? (badgeColor ?? AppColors.primary) : (isDark ? AppColors.darkBorder : AppColors.border),
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
