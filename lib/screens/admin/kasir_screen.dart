import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/payment_provider.dart';
import '../../models/machine_command_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_theme.dart';

class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) return oldValue;
    final formatted = NumberFormat('#,###', 'id_ID').format(int.parse(digits));
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class KasirScreen extends StatefulWidget {
  final bool showAppBar;
  const KasirScreen({super.key, this.showAppBar = true});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  final _amountCtrl = TextEditingController();
  final _menuNameCtrl = TextEditingController();
  final _menuPriceCtrl = TextEditingController();
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _svc = FirebaseService();

  String? _selectedMachineId;
  List<Map<String, dynamic>> _machines = [];
  bool _loadingMachines = true;

  String _inputMode = 'manual';
  bool _hasValidAmount = false;
  final List<Map<String, dynamic>> _cartItems = [];

  List<int> _quickAmounts = [2000, 3000, 5000, 10000, 15000, 20000];
  StreamSubscription<List<int>>? _qaSub;
  StreamSubscription<List<Map<String, dynamic>>>? _machinesSub;

  @override
  void initState() {
    super.initState();
    _machinesSub = _svc.streamAllMachines().listen((machines) {
      if (!mounted) return;
      final filtered = machines.where((m) {
        final t = m['tujuan'] as String? ?? '';
        return t == 'kasir' || t == '';
      }).toList();
      setState(() {
        _machines = filtered;
        _loadingMachines = false;
        if (filtered.isNotEmpty && _selectedMachineId == null) {
          _selectedMachineId = filtered.first['id'] as String;
          context.read<PaymentProvider>().setMachine(_selectedMachineId!);
        }
      });
    });
    _qaSub = _svc.streamQuickAmountsPenjual().listen((amounts) {
      if (mounted) setState(() => _quickAmounts = amounts);
    });
  }

  @override
  void dispose() {
    _machinesSub?.cancel();
    _qaSub?.cancel();
    super.dispose();
  }

  double get _cartTotal => _cartItems.fold(0, (sum, item) => sum + (item['price'] as double));

  void _addMenuItem() {
    final name = _menuNameCtrl.text.trim();
    final price = double.tryParse(_menuPriceCtrl.text.replaceAll('.', '').replaceAll(',', ''));
    if (name.isEmpty || price == null || price <= 0) return;
    setState(() {
      _cartItems.add({'name': name, 'price': price});
      _menuNameCtrl.clear();
      _menuPriceCtrl.clear();
    });
  }

  void _removeItem(int index) => setState(() => _cartItems.removeAt(index));

  Future<void> _startPayment() async {
    double amount;
    if (_inputMode == 'manual') {
      amount = double.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', '').trim()) ?? 0;
    } else {
      amount = _cartTotal;
    }
    if (amount <= 0) return;
    await context.read<PaymentProvider>().startPayment(amount);
  }

  Future<void> _reset() async {
    await context.read<PaymentProvider>().resetMachine();
    _amountCtrl.clear();
    setState(() { _cartItems.clear(); _hasValidAmount = false; });
  }

  void _onMachineChanged(String? id) {
    if (id == null) return;
    setState(() => _selectedMachineId = id);
    context.read<PaymentProvider>().setMachine(id);
  }

  void _showQuickAmountEditor() {
    final newItemCtrl = TextEditingController();
    final editCtrl = TextEditingController();
    int? editingIndex;
    List<int> tempAmounts = List<int>.from(_quickAmounts);
    final fmt = NumberFormat('#,###', 'id_ID');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void addFromField() {
            final v = int.tryParse(newItemCtrl.text.replaceAll('.', '').replaceAll(',', ''));
            if (v != null && v > 0) {
              setDialogState(() { tempAmounts.add(v); tempAmounts.sort(); newItemCtrl.clear(); });
            }
          }
          return AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: const Text('Atur Nominal Cepat (Penjual/Kasir)'),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...tempAmounts.asMap().entries.map((e) {
                    if (editingIndex == e.key) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Text('Rp ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Expanded(
                              child: TextField(
                                controller: editCtrl,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [_ThousandSeparatorFormatter()],
                                decoration: InputDecoration(
                                  isDense: true, filled: true, fillColor: AppTheme.bgColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: AppTheme.primaryColor, size: 18),
                              onPressed: () {
                                final v = int.tryParse(editCtrl.text.replaceAll('.', '').replaceAll(',', ''));
                                if (v != null && v > 0) {
                                  setDialogState(() { tempAmounts[e.key] = v; tempAmounts.sort(); editingIndex = null; });
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setDialogState(() => editingIndex = null),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(fmt.format(e.value), style: const TextStyle(fontSize: 14)),
                      leading: const Text('Rp', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white54),
                            onPressed: () => setDialogState(() { editingIndex = e.key; editCtrl.text = e.value.toString(); }),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                            onPressed: () => setDialogState(() => tempAmounts.removeAt(e.key)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(color: Colors.white12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newItemCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [_ThousandSeparatorFormatter()],
                          decoration: InputDecoration(
                            hintText: 'Tambah nominal baru',
                            prefixText: 'Rp ',
                            isDense: true,
                            filled: true,
                            fillColor: AppTheme.bgColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                        onPressed: addFromField,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  addFromField();
                  if (tempAmounts.isNotEmpty) await _svc.saveQuickAmountsPenjual(tempAmounts);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentProvider>();
    final machine = provider.machineState;
    final status = machine?.status ?? 'idle';

    if (_loadingMachines) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_machines.isEmpty) {
      return Scaffold(
        appBar: widget.showAppBar ? AppBar(title: const Text('Kasir')) : null,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Belum ada mesin terdaftar.\nTambahkan mesin di menu Admin → Mesin.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final selectedMachine = _machines.firstWhere(
      (m) => m['id'] == _selectedMachineId,
      orElse: () => {'nama': _selectedMachineId},
    );
    final machineName = selectedMachine['nama'] as String? ?? _selectedMachineId ?? '';

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Kasir')) : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Mesin: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMachineId,
                    items: _machines.map((m) {
                      final s = machineStatusStyle(m);
                      return DropdownMenuItem<String>(
                        value: m['id'] as String,
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: s.color),
                            const SizedBox(width: 8),
                            Text(m['nama'] as String? ?? m['id'] as String),
                            const SizedBox(width: 4),
                            Text('(${s.label})', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (status == 'idle' || status == 'error') ? _onMachineChanged : null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    dropdownColor: AppTheme.cardColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatusBanner(status: status, machine: machine, fmt: _fmt, machineName: machineName, lastHeartbeat: selectedMachine['last_heartbeat']),
            const SizedBox(height: 24),
            if (status == 'idle' || status == 'error') ...[
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      label: 'Input Manual',
                      icon: Icons.keyboard_outlined,
                      selected: _inputMode == 'manual',
                      onTap: () => setState(() => _inputMode = 'manual'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModeButton(
                      label: 'Tambah Menu',
                      icon: Icons.restaurant_menu_outlined,
                      selected: _inputMode == 'menu',
                      onTap: () => setState(() => _inputMode = 'menu'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_inputMode == 'manual') ...[
                const Text('Nominal Belanja', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ThousandSeparatorFormatter()],
                  onChanged: (v) {
                    final digits = v.replaceAll('.', '').replaceAll(',', '');
                    setState(() => _hasValidAmount = digits.isNotEmpty && (double.tryParse(digits) ?? 0) > 0);
                  },
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _quickAmounts.map((a) => ActionChip(
                          label: Text(_fmt.format(a)),
                          onPressed: () => setState(() { _amountCtrl.text = NumberFormat('#,###', 'id_ID').format(a); _hasValidAmount = true; }),
                          backgroundColor: AppTheme.cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        )).toList(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white54),
                      tooltip: 'Atur nominal cepat',
                      onPressed: _showQuickAmountEditor,
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _menuNameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Nama menu',
                          filled: true,
                          fillColor: AppTheme.cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _menuPriceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_ThousandSeparatorFormatter()],
                        decoration: InputDecoration(
                          hintText: 'Harga',
                          prefixText: 'Rp ',
                          filled: true,
                          fillColor: AppTheme.cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _addMenuItem,
                      icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_cartItems.isEmpty)
                  const Text('Belum ada item', style: TextStyle(color: Colors.white38, fontSize: 13))
                else ...[
                  ...List.generate(_cartItems.length, (i) {
                    final item = _cartItems[i];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(item['name'] as String),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_fmt.format(item['price']), style: const TextStyle(color: AppTheme.primaryColor)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _removeItem(i),
                            child: const Icon(Icons.close, size: 16, color: Colors.white38),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_fmt.format(_cartTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: (_inputMode == 'manual' ? _hasValidAmount : _cartItems.isNotEmpty) ? _startPayment : null,
                icon: const Icon(Icons.nfc),
                label: const Text('Perintahkan Tap Kartu'),
              ),
            ],
            if (status == 'waiting_tap') ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    const Text('Menunggu tap kartu...', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(_fmt.format(machine?.amount ?? 0),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    TextButton(onPressed: _reset, child: const Text('Batalkan')),
                  ],
                ),
              ),
            ],
            if (status == 'success') ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF22C55E)),
                    const SizedBox(height: 16),
                    const Text('Pembayaran Berhasil!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_fmt.format(machine?.amount ?? 0), style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 32),
                    ElevatedButton(onPressed: _reset, child: const Text('Transaksi Baru')),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final MachineCommandModel? machine;
  final NumberFormat fmt;
  final String machineName;
  final dynamic lastHeartbeat;
  const _StatusBanner({required this.status, required this.machine, required this.fmt, required this.machineName, this.lastHeartbeat});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    if (isMachineOffline(lastHeartbeat)) {
      color = Colors.white38; label = 'Offline'; icon = Icons.wifi_off_outlined;
    } else {
      switch (status) {
        case 'waiting_tap':
          color = const Color(0xFFF59E0B); label = 'Menunggu Tap'; icon = Icons.nfc;
        case 'success':
          color = const Color(0xFF22C55E); label = 'Berhasil'; icon = Icons.check_circle;
        case 'error':
          color = const Color(0xFFEF4444); label = 'Gagal / Saldo Kurang'; icon = Icons.error_outline;
        default:
          color = const Color(0xFF22C55E); label = 'Siap'; icon = Icons.circle_outlined;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('mesin: $machineName', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.primaryColor : Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.white54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: selected ? Colors.white : Colors.white54)),
          ],
        ),
      ),
    );
  }
}

