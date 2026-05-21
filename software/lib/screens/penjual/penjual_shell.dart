import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/menu_item_model.dart';
import '../../models/transaction_model.dart';
import '../../models/machine_command_model.dart';
import '../../providers/payment_provider.dart';
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

class PenjualShell extends StatefulWidget {
  const PenjualShell({super.key});

  @override
  State<PenjualShell> createState() => _PenjualShellState();
}

class _PenjualShellState extends State<PenjualShell> {
  int _index = 0;
  final _svc = FirebaseService();
  UserModel? _penjual;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await _svc.getUserByAuthUid(uid);
    if (!mounted) return;
    setState(() { _penjual = user; _loadingUser = false; });
    if (_penjual != null) {
      context.read<PaymentProvider>().penjualUid = _penjual!.authUid;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final penjual = _penjual;
    if (penjual == null) {
      return const Scaffold(body: Center(child: Text('Akun tidak ditemukan')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NBPay Kasir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          _GreetingBanner(penjual: penjual),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                _KasirTab(penjual: penjual),
                _MenuTab(penjual: penjual),
                _RiwayatTab(penjual: penjual),
                _PenarikanTab(penjual: penjual),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: AppTheme.cardColor,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_outlined), label: 'Kasir'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_outlined), label: 'Menu'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Riwayat'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), label: 'Penarikan'),
        ],
      ),
    );
  }
}

// ── Greeting Banner ──────────────────────────────────────────────────────────

class _GreetingBanner extends StatelessWidget {
  final UserModel penjual;
  const _GreetingBanner({required this.penjual});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final streamUid = penjual.authUid ?? penjual.uidKartu ?? '';
    return StreamBuilder<UserModel?>(
      stream: FirebaseService().streamUser(streamUid),
      builder: (context, snap) {
        final user = snap.data ?? penjual;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white24,
                child: Icon(Icons.store, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Halo, ${user.nama}!',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('Penjual', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Saldo', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(fmt.format(user.saldo),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab Kasir ─────────────────────────────────────────────────────────────────

class _KasirTab extends StatefulWidget {
  final UserModel penjual;
  const _KasirTab({required this.penjual});

  @override
  State<_KasirTab> createState() => _KasirTabState();
}

class _KasirTabState extends State<_KasirTab> {
  final _svc = FirebaseService();
  final _amountCtrl = TextEditingController();
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  String? _selectedMachineId;
  List<Map<String, dynamic>> _machines = [];
  bool _loadingMachines = true;

  List<MenuItemModel> _menus = [];
  final List<Map<String, dynamic>> _cartItems = [];
  String _inputMode = 'manual';
  bool _hasValidAmount = false;

  List<int> _quickAmounts = [2000, 3000, 5000, 10000];
  StreamSubscription<List<int>>? _qaSub;
  StreamSubscription<List<MenuItemModel>>? _menuSub;
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
        final ids = filtered.map((m) => m['id'] as String).toSet();
        if (_selectedMachineId != null && !ids.contains(_selectedMachineId)) {
          _selectedMachineId = null;
        }
        if (filtered.isNotEmpty && _selectedMachineId == null) {
          _selectedMachineId = filtered.first['id'] as String;
          context.read<PaymentProvider>().setMachine(_selectedMachineId!);
        }
      });
    });
    _qaSub = _svc.streamQuickAmountsPenjual().listen((a) {
      if (mounted) setState(() => _quickAmounts = a);
    });
    _menuSub = _svc.streamMenus(widget.penjual.authUid ?? '').listen((m) {
      if (mounted) setState(() => _menus = m);
    });
  }

  @override
  void dispose() {
    _machinesSub?.cancel();
    _qaSub?.cancel();
    _menuSub?.cancel();
    super.dispose();
  }

  double get _cartTotal => _cartItems.fold(0, (s, i) => s + (i['price'] as double) * (i['qty'] as int));

  String get _cartKeterangan => _cartItems.map((i) => '${i['name']} x${i['qty']}').join(', ');

  void _addMenuToCart(MenuItemModel m) {
    final idx = _cartItems.indexWhere((i) => i['id'] == m.id);
    setState(() {
      if (idx >= 0) {
        _cartItems[idx] = {
          ..._cartItems[idx],
          'qty': (_cartItems[idx]['qty'] as int) + 1,
        };
      } else {
        _cartItems.add({'id': m.id, 'name': m.nama, 'price': m.harga, 'qty': 1});
      }
    });
  }

  void _undoLastItem() {
    if (_cartItems.isEmpty) return;
    setState(() {
      final last = _cartItems.last;
      if ((last['qty'] as int) > 1) {
        _cartItems[_cartItems.length - 1] = {...last, 'qty': (last['qty'] as int) - 1};
      } else {
        _cartItems.removeLast();
      }
    });
  }

  void _removeItem(int index) => setState(() => _cartItems.removeAt(index));

  Future<void> _startPayment() async {
    double amount;
    String keterangan;
    if (_inputMode == 'manual') {
      amount = double.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
      keterangan = 'Pembelian di ${widget.penjual.nama}';
    } else {
      amount = _cartTotal;
      keterangan = _cartKeterangan.isNotEmpty ? _cartKeterangan : 'Pembelian di ${widget.penjual.nama}';
    }
    if (amount <= 0) return;
    await context.read<PaymentProvider>().startPayment(
      amount,
      penjualAuthUid: widget.penjual.authUid,
      keterangan: keterangan,
    );
  }

  Future<void> _reset() async {
    await context.read<PaymentProvider>().resetMachine();
    _amountCtrl.clear();
    setState(() { _cartItems.clear(); _hasValidAmount = false; });
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
            title: const Text('Atur Nominal Cepat'),
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
                            hintText: 'Tambah nominal',
                            prefixText: 'Rp ',
                            isDense: true,
                            filled: true,
                            fillColor: AppTheme.bgColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
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

    if (_loadingMachines) return const Center(child: CircularProgressIndicator());

    if (_machines.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada mesin terdaftar.\nHubungi admin untuk menambahkan mesin.',
              textAlign: TextAlign.center),
        ),
      );
    }

    final selectedMachine = _machines.firstWhere(
      (m) => m['id'] == _selectedMachineId,
      orElse: () => {'nama': _selectedMachineId},
    );
    final machineName = selectedMachine['nama'] as String? ?? _selectedMachineId ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
                    final style = machineStatusStyle(m);
                    return DropdownMenuItem<String>(
                      value: m['id'] as String,
                      child: Row(children: [
                        Icon(Icons.circle, size: 8, color: style.color),
                        const SizedBox(width: 6),
                        Text(m['nama'] as String? ?? m['id'] as String),
                        const SizedBox(width: 6),
                        Text('(${style.label})', style: TextStyle(fontSize: 11, color: style.color)),
                      ]),
                    );
                  }).toList(),
                  onChanged: (status == 'idle' || status == 'error')
                      ? (id) {
                          if (id == null) return;
                          setState(() => _selectedMachineId = id);
                          context.read<PaymentProvider>().setMachine(id);
                        }
                      : null,
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
          const SizedBox(height: 20),

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
                    label: 'Pilih Menu',
                    icon: Icons.restaurant_menu_outlined,
                    selected: _inputMode == 'menu',
                    onTap: () => setState(() => _inputMode = 'menu'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_inputMode == 'manual') ...[
              const Text('Nominal Belanja', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_ThousandSeparatorFormatter()],
                textInputAction: TextInputAction.done,
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
              if (_menus.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: Text('Belum ada menu. Tambahkan di tab Menu.',
                        style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _menus.length,
                  itemBuilder: (_, i) {
                    final m = _menus[i];
                    return GestureDetector(
                      onTap: () => _addMenuToCart(m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(m.nama,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(_fmt.format(m.harga),
                                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              if (_cartItems.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Keranjang', style: TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _undoLastItem,
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text('Undo'),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _cartItems.clear()),
                          icon: const Icon(Icons.clear_all, size: 16, color: Color(0xFFEF4444)),
                          label: const Text('Hapus Semua', style: TextStyle(color: Color(0xFFEF4444))),
                        ),
                      ],
                    ),
                  ],
                ),
                ...List.generate(_cartItems.length, (i) {
                  final item = _cartItems[i];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text('${item['name']} x${item['qty']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_fmt.format((item['price'] as double) * (item['qty'] as int)),
                            style: const TextStyle(color: AppTheme.primaryColor)),
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
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: (_inputMode == 'manual' ? _hasValidAmount : _cartItems.isNotEmpty) ? _startPayment : null,
              icon: const Icon(Icons.nfc),
              label: const Text('Perintahkan Tap Kartu'),
            ),
          ],

          if (status == 'waiting_tap') ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text('Menunggu tap kartu pembeli...', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(_fmt.format(machine?.amount ?? 0),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 28),
                  TextButton(onPressed: _reset, child: const Text('Batalkan')),
                ],
              ),
            ),
          ],

          if (status == 'success') ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF22C55E)),
                  const SizedBox(height: 16),
                  const Text('Pembayaran Berhasil!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_fmt.format(machine?.amount ?? 0), style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 28),
                  ElevatedButton(onPressed: _reset, child: const Text('Transaksi Baru')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tab Menu CRUD ─────────────────────────────────────────────────────────────

class _MenuTab extends StatelessWidget {
  final UserModel penjual;
  const _MenuTab({required this.penjual});

  @override
  Widget build(BuildContext context) {
    final svc = FirebaseService();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    void showAddEdit(BuildContext ctx, {MenuItemModel? existing}) {
      final namaCtrl = TextEditingController(text: existing?.nama ?? '');
      final hargaCtrl = TextEditingController(
        text: existing != null ? existing.harga.toInt().toString() : '',
      );
      String? error;

      showDialog(
        context: ctx,
        builder: (dctx) => StatefulBuilder(
          builder: (dctx, setDs) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: Text(existing == null ? 'Tambah Menu' : 'Edit Menu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Nama Menu',
                    filled: true,
                    fillColor: AppTheme.bgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hargaCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ThousandSeparatorFormatter()],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Harga',
                    prefixText: 'Rp ',
                    filled: true,
                    fillColor: AppTheme.bgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  final nama = namaCtrl.text.trim();
                  final harga = double.tryParse(hargaCtrl.text.replaceAll('.', '').replaceAll(',', ''));
                  if (nama.isEmpty || harga == null || harga <= 0) {
                    setDs(() => error = 'Nama dan harga wajib diisi');
                    return;
                  }
                  try {
                    if (existing == null) {
                      await svc.addMenu(MenuItemModel(
                        penjualUid: penjual.authUid ?? '',
                        nama: nama,
                        harga: harga,
                      ));
                    } else {
                      await svc.updateMenu(existing.id!, nama, harga);
                    }
                    if (dctx.mounted) Navigator.pop(dctx);
                  } catch (e) {
                    setDs(() => error = e.toString().replaceFirst('Exception: ', ''));
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<MenuItemModel>>(
      stream: svc.streamMenus(penjual.authUid ?? ''),
      builder: (context, snap) {
        final menus = snap.data ?? [];
        return Scaffold(
          body: menus.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu_outlined, size: 60, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('Belum ada menu', style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: menus.length,
                  itemBuilder: (_, i) {
                    final m = menus[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: Icon(Icons.fastfood_outlined, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(fmt.format(m.harga),
                                    style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                            onPressed: () => showAddEdit(context, existing: m),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppTheme.cardColor,
                                  title: const Text('Hapus Menu'),
                                  content: Text('Hapus menu "${m.nama}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Hapus'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) await svc.deleteMenu(m.id!);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showAddEdit(context),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Menu'),
          ),
        );
      },
    );
  }
}

// ── Tab Riwayat Penjualan ─────────────────────────────────────────────────────

class _RiwayatTab extends StatelessWidget {
  final UserModel penjual;
  const _RiwayatTab({required this.penjual});

  @override
  Widget build(BuildContext context) {
    final svc = FirebaseService();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return StreamBuilder<List<TransactionModel>>(
      stream: svc.streamPenjualTransactions(penjual.authUid ?? ''),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final txs = snap.data ?? [];
        if (txs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 60, color: Colors.white24),
                SizedBox(height: 12),
                Text('Belum ada transaksi penjualan', style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: txs.length,
          itemBuilder: (_, i) {
            final tx = txs[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sell_outlined, color: Color(0xFF22C55E), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.keterangan,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(tx.timestamp),
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  Text('+${fmt.format(tx.nominal)}',
                      style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  final MachineCommandModel? machine;
  final NumberFormat fmt;
  final String machineName;
  final dynamic lastHeartbeat;
  const _StatusBanner({required this.status, required this.machine, required this.fmt, required this.machineName, this.lastHeartbeat});

  @override
  Widget build(BuildContext context) {
    final offline = isMachineOffline(lastHeartbeat);
    Color color;
    String label;
    IconData icon;
    if (offline) {
      color = Colors.white38; label = 'Mesin Offline'; icon = Icons.wifi_off_outlined;
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

// ── Tab Penarikan ─────────────────────────────────────────────────────────────

class _PenarikanTab extends StatelessWidget {
  final UserModel penjual;
  const _PenarikanTab({required this.penjual});

  @override
  Widget build(BuildContext context) {
    final svc = FirebaseService();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return StreamBuilder<List<TransactionModel>>(
      stream: svc.streamPenjualWithdrawals(penjual.authUid ?? ''),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final txs = snap.data ?? [];
        if (txs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined, size: 60, color: Colors.white24),
                SizedBox(height: 12),
                Text('Belum ada riwayat penarikan', style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: txs.length,
          itemBuilder: (_, i) {
            final tx = txs[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payments_outlined, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.keterangan, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(tx.timestamp),
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  Text('-${fmt.format(tx.nominal)}',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
