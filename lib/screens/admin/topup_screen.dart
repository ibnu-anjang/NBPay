import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
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

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _svc = FirebaseService();
  final _amountCtrl = TextEditingController();
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  List<UserModel> _students = [];
  UserModel? _selected;
  bool _loading = false;
  bool _loadingData = true;
  bool _scanningCard = false;
  String? _message;
  StreamSubscription<String?>? _uidSub;

  List<Map<String, dynamic>> _machines = [];
  String? _selectedMachineId;
  List<int> _quickAmounts = [10000, 20000, 50000, 100000];
  StreamSubscription<List<int>>? _qaSub;
  StreamSubscription<List<Map<String, dynamic>>>? _machinesSub;

  @override
  void initState() {
    super.initState();
    _svc.expireStaleRequests();
    _loadStudents();
    _machinesSub = _svc.streamAllMachines().listen((machines) {
      if (!mounted) return;
      final filtered = machines.where((m) {
        final t = m['tujuan'] as String? ?? '';
        return t == 'topup_daftar' || t == 'topup' || t == 'daftar_siswa';
      }).toList();
      setState(() {
        _machines = filtered;
        if (_selectedMachineId == null && filtered.isNotEmpty) {
          _selectedMachineId = filtered.first['id'] as String;
        }
        _loadingData = false;
      });
    });
    _qaSub = _svc.streamQuickAmounts().listen((amounts) {
      if (mounted) setState(() => _quickAmounts = amounts);
    });
  }

  @override
  void dispose() {
    _uidSub?.cancel();
    _machinesSub?.cancel();
    _qaSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final students = await _svc.getAllStudents();
    if (!mounted) return;
    setState(() {
      _students = students;
      if (_machines.isNotEmpty) _loadingData = false;
    });
  }

  Future<void> _loadData() async {
    final students = await _svc.getAllStudents();
    if (!mounted) return;
    setState(() {
      _students = students;
      if (_selected != null) {
        _selected = students.where((s) => s.uidKartu == _selected!.uidKartu).firstOrNull;
      }
    });
  }

  Future<void> _scanCard() async {
    if (_machines.isEmpty) {
      setState(() => _message = 'Tidak ada mesin terdaftar. Tambahkan mesin terlebih dahulu.');
      return;
    }
    final machineId = _selectedMachineId ?? _machines.first['id'] as String;
    await _svc.setMachineWaitingUid(machineId);
    setState(() { _scanningCard = true; _message = null; });

    _uidSub?.cancel();
    _uidSub = _svc.streamLastUid(machineId).listen((uid) {
      if (uid != null && uid.isNotEmpty) {
        _uidSub?.cancel();
        _svc.resetMachine(machineId);
        if (!mounted) return;
        final student = _students.where((s) => s.uidKartu == uid).firstOrNull;
        setState(() {
          _scanningCard = false;
          if (student != null) {
            _selected = student;
            _message = null;
          } else {
            _message = 'Kartu tidak dikenali (UID: $uid)';
          }
        });
      }
    });
  }

  void _stopScan() async {
    _uidSub?.cancel();
    final machineId = _selectedMachineId;
    if (machineId != null) await _svc.resetMachine(machineId);
    if (!mounted) return;
    setState(() => _scanningCard = false);
  }

  Future<void> _doTopUp() async {
    if (_selected == null) {
      setState(() => _message = 'Pilih siswa terlebih dahulu.');
      return;
    }
    final uid = _selected!.uidKartu;
    final amount = double.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', ''));
    if (uid == null || amount == null || amount <= 0) return;

    setState(() { _loading = true; _message = null; });
    try {
      await _svc.topUp(uid, amount);
      if (!mounted) return;
      _amountCtrl.clear();
      await _loadData();
      if (!mounted) return;
      setState(() => _message = 'Top-up berhasil!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            title: const Text('Atur Nominal Cepat (Admin Topup)'),
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
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  final v = int.tryParse(editCtrl.text.replaceAll('.', '').replaceAll(',', ''));
                                  if (v != null && v > 0) {
                                    setDialogState(() { tempAmounts[e.key] = v; tempAmounts.sort(); editingIndex = null; });
                                  }
                                },
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
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => addFromField(),
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
                  if (tempAmounts.isNotEmpty) await _svc.saveQuickAmounts(tempAmounts);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Top-up Saldo')),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_machines.isNotEmpty) ...[
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
                          child: Row(children: [
                            Icon(Icons.circle, size: 8, color: s.color),
                            const SizedBox(width: 8),
                            Text(m['nama'] as String? ?? m['id'] as String),
                            const SizedBox(width: 4),
                            Text('(${s.label})', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                          ]),
                        );
                      }).toList(),
                      onChanged: _scanningCard ? null : (v) => setState(() => _selectedMachineId = v),
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
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                const Expanded(child: Text('Pilih Siswa', style: TextStyle(fontWeight: FontWeight.w600))),
                if (_scanningCard)
                  TextButton.icon(
                    onPressed: _stopScan,
                    icon: const Icon(Icons.stop, size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Batalkan Scan', style: TextStyle(color: Color(0xFFEF4444))),
                  )
                else
                  TextButton.icon(
                    onPressed: _machines.isEmpty ? null : _scanCard,
                    icon: const Icon(Icons.nfc, size: 16),
                    label: const Text('Scan Kartu'),
                  ),
              ],
            ),
            if (_scanningCard) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      'Tempelkan kartu siswa ke mesin "${_machines.firstWhere((m) => m['id'] == _selectedMachineId, orElse: () => {'nama': _selectedMachineId})['nama']}"...',
                    )),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<UserModel>(
                initialValue: _selected,
                items: _students.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text('${s.nama} — ${_fmt.format(s.saldo)}'),
                )).toList(),
                onChanged: (v) => setState(() => _selected = v),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                dropdownColor: AppTheme.cardColor,
              ),
            ],
            const SizedBox(height: 24),
            const Text('Jumlah Top-up', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandSeparatorFormatter()],
              textInputAction: TextInputAction.done,
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
                      onPressed: () => setState(() => _amountCtrl.text = NumberFormat('#,###', 'id_ID').format(a)),
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
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!,
                style: TextStyle(
                  color: _message!.startsWith('Top') ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                )),
            ],
            const SizedBox(height: 24),
            ListenableBuilder(
              listenable: _amountCtrl,
              builder: (context, _) {
                final amount = double.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                return ElevatedButton.icon(
                  onPressed: (_loading || amount <= 0) ? null : _doTopUp,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_card),
                  label: const Text('Top-up Sekarang'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
