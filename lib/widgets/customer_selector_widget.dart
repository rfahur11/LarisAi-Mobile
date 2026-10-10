import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/pos_provider.dart';
import '../services/local_db_service.dart';

class CustomerSelectorWidget extends StatefulWidget {
  final ValueChanged<String> onCustomerChanged;
  final bool isDark;
  final String? initialValue;

  const CustomerSelectorWidget({
    super.key,
    required this.onCustomerChanged,
    required this.isDark,
    this.initialValue,
  });

  @override
  State<CustomerSelectorWidget> createState() => _CustomerSelectorWidgetState();
}

class _CustomerSelectorWidgetState extends State<CustomerSelectorWidget> {
  int _modeIndex = 0; // 0 = Cari Pelanggan, 1 = Input Pelanggan Baru
  CustomerRecord? _selectedRecord;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newNameController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();

  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _parseInitial(widget.initialValue!);
    }
  }

  void _parseInitial(String raw) {
    final match = RegExp(r'^(.*?)\s*[\(\-•]\s*(08\d{8,13}|\+?62\d{8,13})\)?$').firstMatch(raw);
    if (match != null) {
      _selectedRecord = CustomerRecord(
        id: raw,
        name: match.group(1)?.trim() ?? raw,
        phone: match.group(2)?.trim() ?? '',
      );
    } else {
      _selectedRecord = CustomerRecord(id: raw, name: raw, phone: '');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newNameController.dispose();
    _newPhoneController.dispose();
    super.dispose();
  }

  void _selectCustomer(CustomerRecord record) {
    setState(() {
      _selectedRecord = record;
      _searchController.clear();
      _searchFilter = '';
    });
    final val = record.phone.isNotEmpty ? '${record.name} (${record.phone})' : record.name;
    widget.onCustomerChanged(val);
  }

  void _clearSelected() {
    setState(() {
      _selectedRecord = null;
      _searchController.clear();
      _newNameController.clear();
      _newPhoneController.clear();
      _searchFilter = '';
    });
    widget.onCustomerChanged('');
  }

  void _notifyNewCustomer() {
    final name = _newNameController.text.trim();
    final phone = _newPhoneController.text.trim();
    if (name.isEmpty && phone.isEmpty) {
      widget.onCustomerChanged('');
    } else if (phone.isNotEmpty) {
      widget.onCustomerChanged('$name ($phone)');
    } else {
      widget.onCustomerChanged(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final posProvider = Provider.of<PosProvider>(context);
    final history = posProvider.customerHistory;

    final filteredHistory = _searchFilter.isEmpty
        ? history
        : history.where((c) {
            final q = _searchFilter.toLowerCase();
            return c.name.toLowerCase().contains(q) || c.phone.contains(q);
          }).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Label & Status
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Data Pelanggan (CRM)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (_selectedRecord != null || _newNameController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF25D366)),
                      SizedBox(width: 4),
                      Text(
                        'Pelanggan Terhubung',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF25D366),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Opsional',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // JIKA SUDAH TERPILIH: Tampilkan Badge Ringkas & Tombol Reset
          if (_selectedRecord != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF042F2E) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                    child: const Icon(Icons.person, size: 16, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedRecord!.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF065F46),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_selectedRecord!.phone.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.chat, size: 10, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              Text(
                                _selectedRecord!.phone,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : const Color(0xFF047857),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _clearSelected,
                    icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.danger),
                    label: const Text('Ganti', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Mode Segmented Bar: [ 🔍 Cari Pelanggan ] vs [ ➕ Pelanggan Baru ]
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _modeIndex = 0);
                        _notifyNewCustomer();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _modeIndex == 0
                              ? (isDark ? AppColors.darkCard : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _modeIndex == 0
                              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3)]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🔍 Cari Pelanggan (${history.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _modeIndex == 0 ? FontWeight.bold : FontWeight.w500,
                            color: _modeIndex == 0
                                ? AppColors.primary
                                : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _modeIndex = 1);
                        _notifyNewCustomer();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _modeIndex == 1
                              ? (isDark ? AppColors.darkCard : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: _modeIndex == 1
                              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3)]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '➕ Input Baru',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _modeIndex == 1 ? FontWeight.bold : FontWeight.w500,
                            color: _modeIndex == 1
                                ? AppColors.primary
                                : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // SUB-VIEW 1: CARI PELANGGAN TERDAFTAR
            if (_modeIndex == 0) ...[
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau nomor WhatsApp...',
                  hintStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchFilter = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchFilter = val.trim()),
              ),
              const SizedBox(height: 6),

              if (filteredHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          history.isEmpty ? 'Belum ada data pelanggan tersimpan.' : 'Tidak ada nama yang cocok.',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => setState(() => _modeIndex = 1),
                        child: const Text('+ Tambah Baru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredHistory.length > 5 ? 5 : filteredHistory.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                    ),
                    itemBuilder: (context, idx) {
                      final item = filteredHistory[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primaryLight,
                          child: const Icon(Icons.person, size: 14, color: AppColors.primary),
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextMain : AppColors.textMain,
                          ),
                        ),
                        subtitle: item.phone.isNotEmpty
                            ? Text(
                                item.phone,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF059669)),
                              )
                            : null,
                        trailing: (item.totalOrders > 0)
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.totalOrders}x belanja',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => _selectCustomer(item),
                      );
                    },
                  ),
                ),
            ] else ...[
              // SUB-VIEW 2: INPUT PELANGGAN BARU (NAMA + WA)
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: _newNameController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Nama Pelanggan',
                        labelStyle: TextStyle(fontSize: 11),
                        hintText: 'e.g. Budi Santoso',
                        hintStyle: TextStyle(fontSize: 10),
                        prefixIcon: Icon(Icons.person_outline, size: 16),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (_) => _notifyNewCustomer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: _newPhoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        labelText: 'No. WhatsApp',
                        labelStyle: TextStyle(fontSize: 11),
                        hintText: '081234567890',
                        hintStyle: TextStyle(fontSize: 10),
                        prefixIcon: Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFF25D366)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (_) => _notifyNewCustomer(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 11, color: Color(0xFF25D366)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Otomatis tersimpan permanen untuk CRM & promo WhatsApp.',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
