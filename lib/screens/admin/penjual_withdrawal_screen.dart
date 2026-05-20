import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
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

class PenjualWithdrawalScreen extends StatefulWidget {
  const PenjualWithdrawalScreen({super.key});

  @override
  State<PenjualWithdrawalScreen> createState() => _PenjualWithdrawalScreenState();
}

class _PenjualWithdrawalScreenState extends State<PenjualWithdrawalScreen> {
  final _svc = FirebaseService();
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  List<UserModel> _penjuals = [];
  List<Map<String, dynamic>> _machines = [];
  String? _selectedMachineId;
  UserModel? _selected;
  bool _loadingPenjual = true;
  bool _scanningCard = false;
  bool _loading = false;
  String? _message;
  StreamSubscription<String?>? _uidSub;
  StreamSubscription<List<Map<String, dynamic>>>? _machinesSub;
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPenjual();
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
      });
    });
  }

  @override
  void dispose() {
    _uidSub?.cancel();
    _machinesSub?.cancel();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPenjual() async {
    setState(() => _loadingPenjual = true);
    final penjuals = await _svc.getAllPenjual();
    if (!mounted) return;
    setState(() {
      _penjuals = penjuals;
      _loadingPenjual = false;
    });
  }

  Future<void> _loadData() async {
    final penjuals = await _svc.getAllPenjual();
    if (!mounted) return;
    setState(() => _penjuals = penjuals);
  }

  Future<void> _scanCard() async {
    if (_machines.isEmpty) {
      setState(() => _message = 'Tidak ada mesin terdaftar.');
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
        final penjual = _penjuals.where((p) => p.uidKartu == uid).firstOrNull;
        setState(() {
          _scanningCard = false;
          if (penjual != null) {
            _selected = penjual;
            _message = null;
          } else {
            _message = 'Kartu tidak dikenali sebagai penjual (UID: $uid).\nPastikan UID kartu sudah didaftarkan di data penjual.';
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

  Future<void> _doWithdraw() async {
    final penjual = _selected;
    if (penjual == null) return;
    final inputText = _amountCtrl.text.replaceAll('.', '').replaceAll(',', '').trim();
    final amount = inputText.isEmpty ? penjual.saldo : double.tryParse(inputText) ?? 0;
    if (amount <= 0) {
      setState(() => _message = 'Masukkan jumlah penarikan yang valid.');
      return;
    }
    if (amount > penjual.saldo) {
      setState(() => _message = 'Jumlah penarikan melebihi saldo penjual (${_fmt.format(penjual.saldo)}).');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Konfirmasi Penarikan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Penjual: ${penjual.nama}'),
            const SizedBox(height: 8),
            Text('Saldo akan ditarik sebesar:',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_fmt.format(amount),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            const SizedBox(height: 12),
            const Text('Pastikan uang tunai sudah diserahkan kepada penjual.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi & Tarik'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() { _loading = true; _message = null; });
    try {
      await _svc.withdrawPenjual(penjualAuthUid: penjual.authUid!, amount: amount);
      await _loadData();
      if (!mounted) return;
      setState(() {
        _message = 'Penarikan ${_fmt.format(amount)} untuk ${penjual.nama} berhasil!';
        _selected = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Gagal: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penarikan Saldo Penjual')),
      body: _loadingPenjual
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primaryColor),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Penjual tempelkan kartu ke mesin, atau pilih manual dari daftar.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_machines.isNotEmpty) ...[
                    const SizedBox(height: 16),
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
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Pilih Penjual', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
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
                  const SizedBox(height: 8),
                  if (_scanningCard)
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
                          Expanded(
                            child: Text(
                              'Tempelkan kartu penjual ke mesin "${_machines.firstWhere((m) => m['id'] == _selectedMachineId, orElse: () => {'nama': _selectedMachineId})['nama']}"...',
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<UserModel>(
                      initialValue: _selected,
                      items: _penjuals.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.nama} — ${_fmt.format(p.saldo)}'),
                      )).toList(),
                      onChanged: (v) => setState(() { _selected = v; _message = null; _amountCtrl.clear(); }),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.cardColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      dropdownColor: AppTheme.cardColor,
                    ),
                  if (_selected != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFF59E0B),
                                child: Icon(Icons.store, color: Colors.white),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_selected!.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('@${_selected!.username ?? '-'}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Saldo tersedia:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(_fmt.format(_selected!.saldo),
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _amountCtrl.text = NumberFormat('#,###', 'id_ID').format(_selected!.saldo.toInt())),
                                child: const Text('Tarik Semua'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_ThousandSeparatorFormatter()],
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Jumlah yang ditarik',
                              hintText: 'Kosongkan untuk tarik semua',
                              prefixText: 'Rp ',
                              filled: true,
                              fillColor: AppTheme.bgColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _message!.startsWith('Penarikan') ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_loading || _selected == null || _selected!.saldo <= 0)
                          ? null
                          : () {
                              final inputText = _amountCtrl.text.trim();
                              final amt = inputText.isEmpty ? _selected!.saldo : double.tryParse(inputText) ?? 0;
                              if (amt <= 0 || amt > _selected!.saldo) {
                                setState(() => _message = amt > _selected!.saldo
                                    ? 'Jumlah melebihi saldo (${_fmt.format(_selected!.saldo)})'
                                    : 'Masukkan jumlah yang valid.');
                              } else {
                                _doWithdraw();
                              }
                            },
                      icon: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.payments_outlined),
                      label: const Text('Tarik Saldo Penjual'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Riwayat Penarikan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _WithdrawalHistoryList(fmt: _fmt, penjuals: _penjuals),
                ],
              ),
            ),
    );
  }
}

class _WithdrawalHistoryList extends StatelessWidget {
  final NumberFormat fmt;
  final List<UserModel> penjuals;
  const _WithdrawalHistoryList({required this.fmt, required this.penjuals});

  @override
  Widget build(BuildContext context) {
    final svc = FirebaseService();
    return StreamBuilder<List<TransactionModel>>(
      stream: svc.streamWithdrawalTransactions(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }
        final txs = snap.data ?? [];
        if (txs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('Belum ada riwayat penarikan', style: TextStyle(color: Colors.white38))),
          );
        }
        return Column(
          children: txs.map((tx) {
            final penjualName = penjuals.where((p) => p.authUid == tx.uidKartu).firstOrNull?.nama ?? tx.uidKartu;
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payments_outlined, color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(penjualName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(tx.timestamp),
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  Text('-${fmt.format(tx.nominal)}',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
