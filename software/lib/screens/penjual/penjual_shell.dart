import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/cloudinary_service.dart';
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 840;

        final tabs = [
          _KasirTab(penjual: penjual),
          _MenuTab(penjual: penjual),
          _RiwayatTab(penjual: penjual),
          _PenarikanTab(penjual: penjual),
        ];

        if (isWide) {
          return Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/nbpay-logo.svg',
                    height: 38,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 14),
                  Container(width: 1.5, height: 22, color: Colors.white24),
                  const SizedBox(width: 14),
                  const Text('Kasir Kantin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  backgroundColor: AppTheme.cardColor,
                  indicatorColor: Colors.white,
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AppTheme.bgColor),
                  selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  unselectedIconTheme: const IconThemeData(color: Colors.white60),
                  unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: Text('Kasir')),
                    NavigationRailDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: Text('Menu')),
                    NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Riwayat')),
                    NavigationRailDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: Text('Penarikan')),
                  ],
                ),
                const VerticalDivider(width: 1, color: Colors.white12),
                Expanded(
                  child: Column(
                    children: [
                      _GreetingBanner(penjual: penjual),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1260),
                            child: IndexedStack(
                              index: _index,
                              children: tabs,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile layout
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/nbpay-logo.svg',
                  height: 34,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Kasir',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
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
                  children: tabs,
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            backgroundColor: AppTheme.cardColor,
            selectedItemColor: Colors.white,
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
      },
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
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF0EA5E9), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.nama,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Kantin Aktif',
                          style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'SALDO TERKUMPUL',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmt.format(user.saldo),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
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

  List<int> _quickAmounts = [2000, 3000, 5000, 10000, 15000, 20000, 25000, 50000, 100000];
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedMachineId != null) {
              context.read<PaymentProvider>().setMachine(_selectedMachineId!);
            }
          });
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

  void _removeItem(int index) => setState(() => _cartItems.removeAt(index));

  void _onKeypadTap(String key) {
    if (key == 'C') {
      _amountCtrl.clear();
      setState(() => _hasValidAmount = false);
      return;
    }
    if (key == '⌫') {
      final current = _amountCtrl.text.replaceAll('.', '').replaceAll(',', '');
      if (current.isNotEmpty) {
        final updated = current.substring(0, current.length - 1);
        final val = int.tryParse(updated) ?? 0;
        _amountCtrl.text = val > 0 ? NumberFormat('#,###', 'id_ID').format(val) : '';
        setState(() => _hasValidAmount = val > 0);
      }
      return;
    }
    final current = _amountCtrl.text.replaceAll('.', '').replaceAll(',', '');
    final newString = current + key;
    if (newString.length > 9) return;
    final val = int.tryParse(newString);
    if (val != null) {
      _amountCtrl.text = NumberFormat('#,###', 'id_ID').format(val);
      setState(() => _hasValidAmount = val > 0);
    }
  }

  void _addQuickAmount(int amount) {
    final current = int.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    final updated = current + amount;
    _amountCtrl.text = NumberFormat('#,###', 'id_ID').format(updated);
    setState(() => _hasValidAmount = updated > 0);
  }

  Future<void> _startPayment() async {
    final selectedMachine = _machines.firstWhere(
      (m) => m['id'] == _selectedMachineId,
      orElse: () => {'nama': _selectedMachineId},
    );
    if (_selectedMachineId == null || isMachineOffline(selectedMachine['last_heartbeat'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesin kasir offline! Nyalakan hardware ESP32 sebelum memulai transaksi.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

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

    final isOffline = _selectedMachineId == null || isMachineOffline(selectedMachine['last_heartbeat']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWidePOS = constraints.maxWidth >= 860;

        if (isWidePOS) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (60%): Input / Menu Catalog
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMachineStatusBar(status, machine, selectedMachine),
                      const SizedBox(height: 14),
                      _buildModeSegmentedControl(),
                      const SizedBox(height: 14),
                      if (_inputMode == 'manual') ...[
                        _buildAmountDisplayCard(),
                        const SizedBox(height: 12),
                        _buildQuickAmountChips(),
                        const SizedBox(height: 14),
                        _buildNumericKeypad(),
                      ] else ...[
                        _buildMenuGrid(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Right Column (40%): Digital Order Ticket & Payment Action
                Expanded(
                  flex: 4,
                  child: _buildOrderReceiptPanel(status, machine, true, isOffline: isOffline),
                ),
              ],
            ),
          );
        }

        // Mobile / Compact POS Layout
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMachineStatusBar(status, machine, selectedMachine),
              const SizedBox(height: 14),
              _buildModeSegmentedControl(),
              const SizedBox(height: 14),
              if (_inputMode == 'manual') ...[
                _buildAmountDisplayCard(),
                const SizedBox(height: 12),
                _buildQuickAmountChips(),
                const SizedBox(height: 14),
                _buildNumericKeypad(),
              ] else ...[
                _buildMenuGrid(),
              ],
              const SizedBox(height: 18),
              _buildOrderReceiptPanel(status, machine, false, isOffline: isOffline),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMachineStatusBar(String status, MachineCommandModel? machine, Map<String, dynamic> selectedMachine) {
    final isOffline = isMachineOffline(selectedMachine['last_heartbeat']);
    final style = machineStatusStyle(selectedMachine);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: style.color,
              boxShadow: [
                BoxShadow(
                  color: style.color.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.nfc_rounded, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: ValueKey(_selectedMachineId),
                value: _machines.any((m) => m['id'] == _selectedMachineId) ? _selectedMachineId : null,
                isExpanded: true,
                dropdownColor: AppTheme.cardColor,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white54),
                items: _machines.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['id'] as String,
                    child: Text(
                      '${m['nama'] ?? m['id']}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (status == 'idle' || status == 'error')
                    ? (id) {
                        if (id == null) return;
                        setState(() => _selectedMachineId = id);
                        context.read<PaymentProvider>().setMachine(id);
                      }
                    : null,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: style.color.withValues(alpha: 0.3)),
            ),
            child: Text(
              isOffline ? 'Offline' : style.label,
              style: TextStyle(color: style.color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _inputMode = 'manual'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _inputMode == 'manual' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _inputMode == 'manual'
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.dialpad_rounded,
                      size: 16,
                      color: _inputMode == 'manual' ? AppTheme.bgColor : Colors.white60,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nominal Manual',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _inputMode == 'manual' ? AppTheme.bgColor : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _inputMode = 'menu'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _inputMode == 'menu' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _inputMode == 'menu'
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      size: 16,
                      color: _inputMode == 'menu' ? AppTheme.bgColor : Colors.white60,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pilih Menu (${_menus.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _inputMode == 'menu' ? AppTheme.bgColor : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplayCard() {
    final currentVal = double.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    final formatted = _fmt.format(currentVal);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _hasValidAmount
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NOMINAL TAGIHAN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white54,
                ),
              ),
              if (currentVal > 0)
                GestureDetector(
                  onTap: () {
                    _amountCtrl.clear();
                    setState(() => _hasValidAmount = false);
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatted,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: currentVal > 0 ? const Color(0xFF10B981) : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountChips() {
    return HorizontalScrollChips(
      trailing: IconButton(
        icon: const Icon(Icons.tune_rounded, size: 20, color: Colors.white60),
        tooltip: 'Atur nominal cepat',
        onPressed: _showQuickAmountEditor,
      ),
      children: _quickAmounts.map((a) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(
              '+${_fmt.format(a)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            backgroundColor: AppTheme.cardColor,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onPressed: () => _addQuickAmount(a),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumericKeypad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((k) {
              final isAction = k == 'C' || k == '⌫';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: isAction
                        ? (k == 'C' ? const Color(0xFFEF4444).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08))
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _onKeypadTap(k),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isAction && k == 'C'
                                ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: k == '⌫'
                            ? const Icon(Icons.backspace_outlined, size: 20, color: Colors.white70)
                            : Text(
                                k,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isAction && k == 'C' ? const Color(0xFFEF4444) : Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMenuGrid() {
    if (_menus.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.restaurant_menu_outlined, size: 48, color: Colors.white24),
              SizedBox(height: 10),
              Text('Belum ada menu terdaftar', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white60)),
              SizedBox(height: 4),
              Text('Tambahkan menu di tab Menu untuk mulai berjualan', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _menus.length,
      itemBuilder: (_, i) {
        final m = _menus[i];
        final inCart = _cartItems.firstWhere((item) => item['id'] == m.id, orElse: () => {});
        final qty = inCart.isNotEmpty ? (inCart['qty'] as int) : 0;

        return Material(
          color: qty > 0 ? const Color(0xFF0EA5E9).withValues(alpha: 0.12) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _addMenuToCart(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: qty > 0 ? const Color(0xFF0EA5E9).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
                  width: qty > 0 ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (m.imageUrl != null && m.imageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        m.imageUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          m.nama,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _fmt.format(m.harga),
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (qty > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'x$qty',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    )
                  else
                    const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white38),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderReceiptPanel(String status, MachineCommandModel? machine, bool isWide, {bool isOffline = false}) {
    final currentTotal = _inputMode == 'manual'
        ? (double.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0)
        : _cartTotal;
    final canPay = currentTotal > 0 && !isOffline && (status == 'idle' || status == 'error');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ticket Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: Color(0xFF0EA5E9), size: 20),
                  const SizedBox(width: 8),
                  const Text('Rincian Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              if ((_inputMode == 'manual' && _hasValidAmount) || (_inputMode == 'menu' && _cartItems.isNotEmpty))
                TextButton(
                  onPressed: _reset,
                  child: const Text('Batal', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Items body
          if (status == 'waiting_tap') ...[
            _buildWaitingTapState(machine),
          ] else if (status == 'success') ...[
            _buildSuccessState(machine),
          ] else if (status != 'idle' && status != 'error') ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 16),
                  Text('Menghubungkan ke mesin RFID...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ] else ...[
            if (_inputMode == 'menu') ...[
              if (_cartItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 40, color: Colors.white24),
                        SizedBox(height: 8),
                        Text('Keranjang masih kosong', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        Text('Pilih menu untuk menambahkan', style: TextStyle(color: Colors.white24, fontSize: 11)),
                      ],
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: isWide ? 260 : 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _cartItems.length,
                    separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (_, i) {
                      final item = _cartItems[i];
                      final itemTotal = (item['price'] as double) * (item['qty'] as int);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(_fmt.format(item['price']), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 14),
                                    onPressed: () {
                                      final q = item['qty'] as int;
                                      if (q > 1) {
                                        setState(() => item['qty'] = q - 1);
                                      } else {
                                        _removeItem(i);
                                      }
                                    },
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    padding: EdgeInsets.zero,
                                  ),
                                  Text('${item['qty']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 14),
                                    onPressed: () => setState(() => item['qty'] = (item['qty'] as int) + 1),
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(_fmt.format(itemTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.dialpad_rounded, size: 18, color: Color(0xFF0EA5E9)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Transaksi Manual', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('Nominal diisi langsung via keypad', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(_fmt.format(currentTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF10B981))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL TAGIHAN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1, color: Colors.white70)),
                Text(
                  _fmt.format(currentTotal),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -0.5, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isOffline) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mesin Kasir Offline. Perintah tap dinonaktifkan demi keamanan transaksi fisik.',
                        style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            ElevatedButton.icon(
              onPressed: canPay ? _startPayment : null,
              icon: Icon(isOffline ? Icons.block_rounded : Icons.contactless_rounded, size: 20),
              label: Text(
                isOffline
                    ? 'Mesin Offline (Tap Diblokir)'
                    : (currentTotal > 0 ? 'Perintahkan Tap Kartu (${_fmt.format(currentTotal)})' : 'Perintahkan Tap Kartu'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOffline ? Colors.white12 : const Color(0xFF0EA5E9),
                foregroundColor: isOffline ? Colors.white38 : Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: canPay ? 4 : 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingTapState(MachineCommandModel? machine) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.contactless_rounded, size: 36, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Silakan Tap Kartu RFID',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Dekatkan kartu siswa ke reader mesin kasir',
            style: TextStyle(fontSize: 12, color: Colors.white60),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _fmt.format(machine?.amount ?? 0),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Batalkan Transaksi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(MachineCommandModel? machine) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.check_rounded, size: 40, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pembayaran Berhasil!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            _fmt.format(machine?.amount ?? 0),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: const Text('Transaksi Baru', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
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
      final imageUrlCtrl = TextEditingController(text: existing?.imageUrl ?? '');
      String? currentImageUrl = existing?.imageUrl;
      bool uploadingImage = false;
      String? error;

      showDialog(
        context: ctx,
        builder: (dctx) => StatefulBuilder(
          builder: (dctx, setDs) => AlertDialog(
            backgroundColor: AppTheme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_menu, color: AppTheme.secondaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  existing == null ? 'Tambah Menu Baru' : 'Edit Menu',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo Preview Box
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: uploadingImage
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(height: 10),
                                  Text('Mengunggah ke Cloudinary...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            )
                          : (currentImageUrl != null && currentImageUrl!.isNotEmpty)
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      currentImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.broken_image_outlined, color: Colors.white38, size: 32),
                                            SizedBox(height: 6),
                                            Text('URL Gambar Tidak Valid', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDs(() {
                                            currentImageUrl = null;
                                            imageUrlCtrl.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.image_outlined, size: 36, color: Colors.white24),
                                      SizedBox(height: 8),
                                      Text('Belum ada foto menu', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      Text('Upload via Cloudinary atau tempel URL langsung', style: TextStyle(color: Colors.white24, fontSize: 11)),
                                    ],
                                  ),
                                ),
                    ),
                    const SizedBox(height: 10),

                    // Cloudinary Upload Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: uploadingImage ? null : () async {
                          setDs(() { uploadingImage = true; error = null; });
                          try {
                            final url = await CloudinaryService.pickAndUploadImage(folder: 'nbpay_menus');
                            if (url != null) {
                              setDs(() {
                                currentImageUrl = url;
                                imageUrlCtrl.text = url;
                              });
                            }
                          } catch (e) {
                            setDs(() => error = e.toString().replaceFirst('Exception: ', ''));
                          } finally {
                            setDs(() => uploadingImage = false);
                          }
                        },
                        icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                        label: const Text('Upload Foto dari Galeri (Cloudinary)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.secondaryColor,
                          side: BorderSide(color: AppTheme.secondaryColor.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // URL Input field
                    const Text('Atau Tempel URL Gambar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: imageUrlCtrl,
                      onChanged: (v) {
                        setDs(() => currentImageUrl = v.trim().isEmpty ? null : v.trim());
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://res.cloudinary.com/... atau URL gambar',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
                        prefixIcon: const Icon(Icons.link_rounded, size: 16, color: Colors.white38),
                        filled: true,
                        fillColor: AppTheme.bgColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.secondaryColor)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nama Menu
                    const Text('Nama Menu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: namaCtrl,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Nasi Goreng Spesial',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
                        filled: true,
                        fillColor: AppTheme.bgColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.secondaryColor)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Harga
                    const Text('Harga (Rp)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: hargaCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_ThousandSeparatorFormatter()],
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Contoh: 15.000',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        filled: true,
                        fillColor: AppTheme.bgColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.secondaryColor)),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('Batal', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nama = namaCtrl.text.trim();
                  final harga = double.tryParse(hargaCtrl.text.replaceAll('.', '').replaceAll(',', ''));
                  if (nama.isEmpty || harga == null || harga <= 0) {
                    setDs(() => error = 'Nama dan harga wajib diisi');
                    return;
                  }
                  try {
                    final finalImageUrl = currentImageUrl?.trim().isEmpty == true ? null : currentImageUrl?.trim();
                    if (existing == null) {
                      await svc.addMenu(MenuItemModel(
                        penjualUid: penjual.authUid ?? '',
                        nama: nama,
                        harga: harga,
                        imageUrl: finalImageUrl,
                      ));
                    } else {
                      await svc.updateMenu(existing.id!, nama, harga, imageUrl: finalImageUrl);
                    }
                    if (dctx.mounted) Navigator.pop(dctx);
                  } catch (e) {
                    setDs(() => error = e.toString().replaceFirst('Exception: ', ''));
                  }
                },
                child: const Text('Simpan Menu'),
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
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${menus.length} Menu',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => showAddEdit(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah Menu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: menus.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.restaurant_menu_outlined, size: 60, color: Colors.white24),
                            const SizedBox(height: 12),
                            const Text('Belum ada menu makanan / minuman', style: TextStyle(color: Colors.white54, fontSize: 15)),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => showAddEdit(context),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Tambah Menu Sekarang'),
                              style: FilledButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: menus.length,
                        itemBuilder: (_, i) {
                          final m = menus[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                m.imageUrl != null && m.imageUrl!.isNotEmpty
                                    ? Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: AppTheme.bgColor,
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(9),
                                          child: Image.network(
                                            m.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Icon(
                                              Icons.restaurant_menu_rounded,
                                              color: AppTheme.secondaryColor,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.15),
                                        child: const Icon(Icons.restaurant_menu_rounded, color: AppTheme.secondaryColor, size: 20),
                                      ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      const SizedBox(height: 3),
                                      Text(fmt.format(m.harga),
                                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.white60, size: 19),
                                  tooltip: 'Edit Menu',
                                  onPressed: () => showAddEdit(context, existing: m),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 19),
                                  tooltip: 'Hapus Menu',
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
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
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

// ── Tab Penarikan ─────────────────────────────────────────────────────────────

class _PenarikanTab extends StatefulWidget {
  final UserModel penjual;
  const _PenarikanTab({required this.penjual});

  @override
  State<_PenarikanTab> createState() => _PenarikanTabState();
}

class _PenarikanTabState extends State<_PenarikanTab> {
  final _svc = FirebaseService();
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _submitting = false;

  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final accNumCtrl = TextEditingController();
    final accNameCtrl = TextEditingController(text: widget.penjual.nama);
    final notesCtrl = TextEditingController();
    String selectedBank = 'BCA';
    String? errorMsg;

    final availableSaldo = widget.penjual.saldo;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 10),
              Text('Pencairan Saldo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Tersedia:', style: TextStyle(color: Colors.white60, fontSize: 13)),
                        Text(
                          _fmt.format(availableSaldo),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF22C55E), fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Bank / E-Wallet Tujuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedBank,
                        isExpanded: true,
                        dropdownColor: AppTheme.cardColor,
                        items: ['BCA', 'Mandiri', 'BRI', 'BNI', 'DANA', 'GoPay', 'OVO', 'ShopeePay']
                            .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDState(() => selectedBank = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Nomor Rekening / No. HP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: accNumCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Contoh: 1234567890',
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Atas Nama Rekening', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: accNameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nama pemilik rekening',
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Nominal Penarikan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ThousandSeparatorFormatter()],
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      hintText: 'Minimal Rp 10.000',
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.bgColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 6),
                  HorizontalScrollChips(
                    children: [
                      ActionChip(
                        label: const Text('Semua Saldo', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          amountCtrl.text = NumberFormat('#,###', 'id_ID').format(availableSaldo.toInt());
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Rp 20.000', style: TextStyle(fontSize: 11)),
                        onPressed: () => amountCtrl.text = '20.000',
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Rp 50.000', style: TextStyle(fontSize: 11)),
                        onPressed: () => amountCtrl.text = '50.000',
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Rp 100.000', style: TextStyle(fontSize: 11)),
                        onPressed: () => amountCtrl.text = '100.000',
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Rp 200.000', style: TextStyle(fontSize: 11)),
                        onPressed: () => amountCtrl.text = '200.000',
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Rp 500.000', style: TextStyle(fontSize: 11)),
                        onPressed: () => amountCtrl.text = '500.000',
                      ),
                    ],
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(errorMsg!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
              onPressed: () async {
                final nominal = double.tryParse(amountCtrl.text.replaceAll('.', '').replaceAll(',', ''));
                if (nominal == null || nominal < 10000) {
                  setDState(() => errorMsg = 'Nominal minimal penarikan Rp 10.000');
                  return;
                }
                if (nominal > availableSaldo) {
                  setDState(() => errorMsg = 'Saldo Anda tidak mencukupi');
                  return;
                }
                if (accNumCtrl.text.trim().isEmpty) {
                  setDState(() => errorMsg = 'Nomor rekening wajib diisi');
                  return;
                }
                if (accNameCtrl.text.trim().isEmpty) {
                  setDState(() => errorMsg = 'Nama pemilik rekening wajib diisi');
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _submitting = true);
                try {
                  await _svc.requestWithdrawal(
                    penjualAuthUid: widget.penjual.authUid ?? '',
                    amount: nominal,
                    bankName: selectedBank,
                    accountNumber: accNumCtrl.text.trim(),
                    accountName: accNameCtrl.text.trim(),
                    catatan: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pengajuan pencairan dana berhasil dikirim ke bendahara sekolah!'),
                        backgroundColor: Color(0xFF22C55E),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengajukan penarikan: $e'), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _submitting = false);
                }
              },
              child: const Text('Kirim Pengajuan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;
              final walletIcon = Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF59E0B), size: 28),
              );
              final balanceInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo Siap Ditarik', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    _fmt.format(widget.penjual.saldo),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
                  ),
                ],
              );
              final withdrawBtn = ElevatedButton.icon(
                onPressed: (widget.penjual.saldo < 10000 || _submitting) ? null : _showWithdrawDialog,
                icon: const Icon(Icons.payments_rounded, size: 16),
                label: const Text('Cairkan Saldo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        walletIcon,
                        const SizedBox(width: 14),
                        Expanded(child: balanceInfo),
                      ],
                    ),
                    const SizedBox(height: 14),
                    withdrawBtn,
                  ],
                );
              }

              return Row(
                children: [
                  walletIcon,
                  const SizedBox(width: 14),
                  Expanded(child: balanceInfo),
                  withdrawBtn,
                ],
              );
            },
          ),
        ),
        // Subtitle
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Riwayat Pencairan Dana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
          ),
        ),
        // History list
        Expanded(
          child: StreamBuilder<List<TransactionModel>>(
            stream: _svc.streamPenjualWithdrawals(widget.penjual.authUid ?? ''),
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
                      Icon(Icons.payments_outlined, size: 50, color: Colors.white24),
                      SizedBox(height: 10),
                      Text('Belum ada riwayat penarikan saldo', style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: txs.length,
                itemBuilder: (_, i) {
                  final tx = txs[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.outbox_rounded, color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx.keterangan, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd MMM yyyy, HH:mm').format(tx.timestamp),
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '-${_fmt.format(tx.nominal)}',
                          style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
