import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';
import '../providers/pos_provider.dart';
import '../services/excel_import_service.dart';

class BulkImportDialog extends StatefulWidget {
  final VoidCallback onImportSuccess;

  const BulkImportDialog({
    super.key,
    required this.onImportSuccess,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onImportSuccess}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BulkImportDialog(onImportSuccess: onImportSuccess),
    );
  }

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<BulkImportDialog> {
  bool _isDownloadingTemplate = false;
  bool _isParsing = false;
  bool _isImporting = false;

  String? _selectedFileName;
  ExcelParseResult? _parseResult;
  String? _errorMessage;

  Future<void> _handleDownloadTemplate() async {
    setState(() => _isDownloadingTemplate = true);
    try {
      final savedPath = await ExcelImportService.instance.downloadOrShareTemplate();
      if (!mounted) return;
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Platform.isWindows
                  ? 'Template berhasil disimpan di: $savedPath'
                  : 'Template Excel siap diedit atau dibagikan.',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat template: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingTemplate = false);
    }
  }

  Future<void> _handlePickFile() async {
    setState(() {
      _isParsing = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Pilih File Excel Produk (.xlsx)',
        type: Platform.isAndroid ? FileType.any : FileType.custom,
        allowedExtensions: Platform.isAndroid ? null : ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isParsing = false);
        return;
      }

      final file = result.files.single;
      final fileNameLower = file.name.toLowerCase();
      if (!fileNameLower.endsWith('.xlsx') && !fileNameLower.endsWith('.xls')) {
        throw Exception('Format file harus berupa Excel (.xlsx / .xls). Dipilih: ${file.name}');
      }
      List<int>? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Tidak dapat membaca isi data file spreadsheet.');
      }

      final parseRes = ExcelImportService.instance.parseExcelBytes(bytes);

      if (!mounted) return;
      setState(() {
        _selectedFileName = file.name;
        _parseResult = parseRes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal membaca file: $e';
        _parseResult = null;
      });
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  Future<void> _handleExecuteImport() async {
    final parse = _parseResult;
    if (parse == null || parse.validProducts.isEmpty) return;

    setState(() => _isImporting = true);

    try {
      final res = await ExcelImportService.instance.executeBulkImport(parse.validProducts);

      if (!mounted) return;
      final inserted = res['total_inserted'] ?? parse.validProducts.length;
      final skipped = res['total_skipped'] ?? 0;

      // Refresh data provider
      context.read<PosProvider>().loadProducts();
      widget.onImportSuccess();

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Berhasil mengimpor $inserted produk!${skipped > 0 ? ' ($skipped produk dilewati).' : ''}',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _errorMessage = 'Gagal menyimpan ke database: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parse = _parseResult;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.table_chart_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Impor Produk Massal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      'Pilih .xlsx •',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                    InkWell(
                      onTap: _isDownloadingTemplate || _isImporting ? null : _handleDownloadTemplate,
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        _isDownloadingTemplate ? 'Menyiapkan...' : 'Unduh Template',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 22),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BENTO CARD: PILIH FILE EXCEL (FOKUS UTAMA)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.upload_file_rounded, color: Colors.teal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pilih File Spreadsheet Excel',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _selectedFileName ?? 'Unggah file .xlsx yang sudah diisi data produk toko Anda.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedFileName != null ? FontWeight.w600 : FontWeight.normal,
                                  color: _selectedFileName != null
                                      ? AppColors.primary
                                      : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isParsing || _isImporting ? null : _handlePickFile,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _isParsing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                _selectedFileName == null ? Icons.folder_open_rounded : Icons.sync_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isParsing
                              ? 'Membaca Data Excel...'
                              : (_selectedFileName == null ? 'Pilih File Excel (.xlsx)' : 'Ganti File Excel Lain'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // PRATINJAU HASIL PARSING
              if (parse != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pratinjau Data Produk',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Total ${parse.totalRows} baris dibaca',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildBadge(
                            icon: Icons.check_circle_rounded,
                            label: '${parse.validProducts.length} Siap Diimpor',
                            color: AppColors.success,
                          ),
                          if (parse.warnings.isNotEmpty)
                            _buildBadge(
                              icon: Icons.info_outline_rounded,
                              label: '${parse.warnings.length} Catatan',
                              color: Colors.amber[800] ?? Colors.amber,
                            ),
                          if (parse.errors.isNotEmpty)
                            _buildBadge(
                              icon: Icons.warning_amber_rounded,
                              label: '${parse.errors.length} Dilewati / Error',
                              color: AppColors.danger,
                            ),
                        ],
                      ),

                      if (parse.validProducts.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Sampel Produk:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: parse.validProducts.length > 3 ? 3 : parse.validProducts.length,
                            separatorBuilder: (context, index) => const Divider(height: 8),
                            itemBuilder: (ctx, idx) {
                              final p = parse.validProducts[idx];
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(p.price),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Stok: ${p.stock}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (parse.validProducts.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '... dan ${parse.validProducts.length - 3} produk lainnya.',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],

                      if (parse.errors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Baris bermasalah (akan dilewati):',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.danger,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...parse.errors.take(3).map(
                                    (e) => Text(
                                      '• $e',
                                      style: const TextStyle(fontSize: 11, color: AppColors.danger),
                                    ),
                                  ),
                              if (parse.errors.length > 3)
                                Text(
                                  '• ... ${parse.errors.length - 3} baris lainnya',
                                  style: const TextStyle(fontSize: 11, color: AppColors.danger),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: (_parseResult == null ||
                  _parseResult!.validProducts.isEmpty ||
                  _isImporting)
              ? null
              : _handleExecuteImport,
          icon: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(
            _isImporting
                ? 'Menyimpan ke Database...'
                : 'Impor ${_parseResult?.validProducts.length ?? 0} Produk',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
