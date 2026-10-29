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
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final parsed = int.tryParse(digits);
    if (parsed == null) return oldValue;
    final formatted = NumberFormat('#,###', 'id_ID').format(parsed);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _svc = FirebaseService();
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<UserModel> _students = [];
  List<Map<String, dynamic>> _machines = [];
  bool _loading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _machinesSub;

  List<UserModel> get _filteredStudents {
    if (_searchQuery.trim().isEmpty) return _students;
    final q = _searchQuery.trim().toLowerCase();
    return _students.where((s) {
      final matchName = s.nama.toLowerCase().contains(q);
      final matchNis = s.nis.toLowerCase().contains(q);
      final matchUser = (s.username ?? '').toLowerCase().contains(q);
      final matchCard = (s.uidKartu ?? '').toLowerCase().contains(q);
      return matchName || matchNis || matchUser || matchCard;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _machinesSub = _svc.streamAllMachines().listen((machines) {
      if (!mounted) return;
      setState(() => _machines = machines);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _machinesSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final students = await _svc.getAllStudents();
    if (!mounted) return;
    setState(() {
      _students = students;
      _loading = false;
    });
  }

  void _showRegisterDialog() {
    final uidCtrl = TextEditingController();
    final namaCtrl = TextEditingController();
    final nisCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscurePass = true;
    bool scanningUid = false;
    String? error;
    String? selectedMachineId = _machines.isNotEmpty ? _machines.first['id'] as String : null;
    StreamSubscription<String?>? uidSub;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void startScanUid() async {
            if (_machines.isEmpty) {
              setDialogState(() => error = 'Tidak ada mesin terdaftar. Tambahkan mesin terlebih dahulu.');
              return;
            }
            final machineId = selectedMachineId ?? _machines.first['id'] as String;
            final selectedM = _machines.firstWhere((m) => m['id'] == machineId, orElse: () => _machines.first);
            if (isMachineOffline(selectedM['last_heartbeat'])) {
              setDialogState(() => error = 'Mesin "${selectedM['nama'] ?? machineId}" sedang offline. Nyalakan hardware ESP32.');
              return;
            }
            await _svc.setMachineWaitingUid(machineId);
            setDialogState(() { scanningUid = true; error = null; });
            uidSub?.cancel();
            uidSub = _svc.streamLastUid(machineId).listen((uid) {
              if (uid != null && uid.isNotEmpty) {
                uidCtrl.text = uid;
                uidSub?.cancel();
                _svc.resetMachine(machineId);
                if (ctx.mounted) setDialogState(() => scanningUid = false);
              }
            });
          }

          void stopScanUid() async {
            uidSub?.cancel();
            final machineId = selectedMachineId;
            if (machineId != null) await _svc.resetMachine(machineId);
            if (ctx.mounted) setDialogState(() => scanningUid = false);
          }

          final isMachineOff = _machines.isEmpty || isMachineOffline(_machines.firstOrNull?['last_heartbeat']);

          return AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: const Text('Daftarkan Siswa Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_machines.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(selectedMachineId),
                      initialValue: _machines.any((m) => m['id'] == selectedMachineId) ? selectedMachineId : null,
                      isExpanded: true,
                      items: _machines.map((m) {
                        final s = machineStatusStyle(m);
                        return DropdownMenuItem<String>(
                          value: m['id'] as String,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 8, color: s.color),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  m['nama'] as String? ?? m['id'] as String,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('(${s.label})', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: scanningUid ? null : (v) => setDialogState(() => selectedMachineId = v),
                      decoration: InputDecoration(
                        labelText: 'Mesin untuk scan',
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.bgColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      dropdownColor: AppTheme.cardColor,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _DialogField(controller: uidCtrl, label: 'UID Kartu'),
                      ),
                      const SizedBox(width: 8),
                      scanningUid
                          ? SizedBox(
                              width: 36,
                              height: 36,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
                                  GestureDetector(
                                    onTap: stopScanUid,
                                    child: const Icon(Icons.stop, size: 14, color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            )
                          : IconButton(
                              icon: Icon(Icons.nfc, color: isMachineOff ? Colors.white24 : AppTheme.primaryColor),
                              tooltip: isMachineOff ? 'Mesin offline' : 'Scan Kartu via Mesin',
                              onPressed: isMachineOff ? null : startScanUid,
                            ),
                    ],
                  ),
                  if (scanningUid) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tempelkan kartu ke mesin "${_machines.firstWhere((m) => m['id'] == selectedMachineId, orElse: () => {'nama': selectedMachineId})['nama']}"... (tekan ■ untuk batal)',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _DialogField(controller: namaCtrl, label: 'Nama Siswa'),
                  const SizedBox(height: 12),
                  _DialogField(controller: nisCtrl, label: 'NIS', keyboard: TextInputType.number),
                  const SizedBox(height: 12),
                  _DialogField(controller: usernameCtrl, label: 'Username (untuk login)'),
                  const SizedBox(height: 4),
                  const Text('Username tidak dapat diubah setelah didaftarkan.',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: passCtrl,
                    label: 'Password',
                    obscure: obscurePass,
                    onToggle: () => setDialogState(() => obscurePass = !obscurePass),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  uidSub?.cancel();
                  Navigator.pop(ctx);
                },
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  uidSub?.cancel();
                  if (uidCtrl.text.isEmpty || namaCtrl.text.isEmpty ||
                      nisCtrl.text.isEmpty || usernameCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                    setDialogState(() => error = 'Semua field wajib diisi');
                    return;
                  }
                  try {
                    await _svc.registerStudentWithAuth(
                      uidKartu: uidCtrl.text.trim(),
                      nama: namaCtrl.text.trim(),
                      nis: nisCtrl.text.trim(),
                      username: usernameCtrl.text.trim(),
                      password: passCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } catch (e) {
                    setDialogState(() => error = friendlyAuthError(e));
                  }
                },
                child: const Text('Daftar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(UserModel s) {
    final namaCtrl = TextEditingController(text: s.nama);
    final nisCtrl = TextEditingController(text: s.nis);
    final uidKartuCtrl = TextEditingController(text: s.uidKartu ?? '');
    final saldoCtrl = TextEditingController(
      text: s.saldo > 0 ? NumberFormat('#,###', 'id_ID').format(s.saldo.toInt()) : '',
    );
    bool scanningUid = false;
    String? error;
    StreamSubscription<String?>? uidSub;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void startScan() async {
            if (_machines.isEmpty) {
              setDialogState(() => error = 'Tidak ada mesin terdaftar.');
              return;
            }
            final machine = _machines.first;
            if (isMachineOffline(machine['last_heartbeat'])) {
              setDialogState(() => error = 'Mesin "${machine['nama'] ?? machine['id']}" sedang offline. Nyalakan hardware ESP32.');
              return;
            }
            final machineId = machine['id'] as String;
            await _svc.setMachineWaitingUid(machineId);
            setDialogState(() { scanningUid = true; error = null; });
            uidSub?.cancel();
            uidSub = _svc.streamLastUid(machineId).listen((uid) {
              if (uid != null && uid.isNotEmpty) {
                uidKartuCtrl.text = uid;
                uidSub?.cancel();
                _svc.resetMachine(machineId);
                if (ctx.mounted) setDialogState(() => scanningUid = false);
              }
            });
          }

          void stopScan() async {
            uidSub?.cancel();
            if (_machines.isNotEmpty) await _svc.resetMachine(_machines.first['id'] as String);
            if (ctx.mounted) setDialogState(() => scanningUid = false);
          }

          final isMachineOff = _machines.isEmpty || isMachineOffline(_machines.firstOrNull?['last_heartbeat']);

          return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Edit Data Siswa'),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: namaCtrl, label: 'Nama Siswa', action: TextInputAction.next),
              const SizedBox(height: 12),
              _DialogField(controller: nisCtrl, label: 'NIS', keyboard: TextInputType.number, action: TextInputAction.next),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _DialogField(controller: uidKartuCtrl, label: 'UID Kartu')),
                  const SizedBox(width: 8),
                  scanningUid
                      ? SizedBox(
                          width: 36, height: 36,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
                              GestureDetector(onTap: stopScan, child: const Icon(Icons.stop, size: 14, color: Color(0xFFEF4444))),
                            ],
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.nfc, color: isMachineOff ? Colors.white24 : AppTheme.primaryColor),
                          tooltip: isMachineOff ? 'Mesin offline' : 'Scan Kartu via Mesin',
                          onPressed: isMachineOff ? null : startScan,
                        ),
                ],
              ),
              if (scanningUid)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Tempelkan kartu ke mesin... (tekan ■ untuk batal)',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                ),
              const SizedBox(height: 12),
              _DialogField(
                controller: saldoCtrl,
                label: 'Set Saldo Manual (kosongkan jika tidak diubah)',
                keyboard: TextInputType.number,
                inputFormatters: [_ThousandSeparatorFormatter()],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: Colors.white38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Username: @${s.username ?? '-'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('Username tidak dapat diubah.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ],
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () { uidSub?.cancel(); Navigator.pop(ctx); },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                uidSub?.cancel();
                if (namaCtrl.text.isEmpty || nisCtrl.text.isEmpty) {
                  setDialogState(() => error = 'Field tidak boleh kosong');
                  return;
                }
                try {
                  final docId = s.uidKartu ?? s.authUid!;
                  await _svc.updateUser(docId, {
                    'nama': namaCtrl.text.trim(),
                    'nis': nisCtrl.text.trim(),
                    if (uidKartuCtrl.text.trim().isNotEmpty) 'uid_kartu': uidKartuCtrl.text.trim().toUpperCase(),
                  });
                  final saldoText = saldoCtrl.text.trim().replaceAll('.', '');
                  if (saldoText.isNotEmpty) {
                    final newSaldo = double.tryParse(saldoText);
                    if (newSaldo != null) await _svc.setSaldo(docId, newSaldo);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  setDialogState(() => error = friendlyAuthError(e));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(UserModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Hapus Siswa'),
        content: Text('Hapus data siswa "${s.nama}" (NIS: ${s.nis})?'),
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
    if (ok == true) {
      await _svc.deleteUser(s.uidKartu ?? s.authUid!);
      _load();
    }
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.bgColor,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final searchField = SizedBox(
            height: 42,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari nama, NIS, username, UID...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white38),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                fillColor: AppTheme.cardColor,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.secondaryColor)),
              ),
            ),
          );

          final countBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_filteredStudents.length} Siswa',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
          );

          final addButton = FilledButton.icon(
            onPressed: _showRegisterDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Daftar Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

          if (isNarrow) {
            return Column(
              children: [
                Row(
                  children: [
                    countBadge,
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: 'Refresh',
                      onPressed: _load,
                    ),
                    const SizedBox(width: 8),
                    addButton,
                  ],
                ),
                const SizedBox(height: 10),
                searchField,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              countBadge,
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
              const SizedBox(width: 8),
              addButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'Tidak ada siswa cocok dengan "$_searchQuery"',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Reset Pencarian'),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded, size: 54, color: Colors.white24),
          const SizedBox(height: 12),
          const Text('Belum ada siswa terdaftar', style: TextStyle(color: Colors.white54, fontSize: 15)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _showRegisterDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Daftar Siswa Sekarang'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (ctx, i) {
                          final s = _filteredStudents[i];
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
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      const SizedBox(height: 3),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text('NIS: ${s.nis}',
                                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                          if (s.username != null && s.username!.isNotEmpty)
                                            Text('@${s.username}',
                                                style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            s.uidKartu != null && s.uidKartu!.isNotEmpty ? Icons.nfc_rounded : Icons.credit_card_off_outlined,
                                            size: 13,
                                            color: s.uidKartu != null && s.uidKartu!.isNotEmpty ? const Color(0xFF10B981) : Colors.white38,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            s.uidKartu != null && s.uidKartu!.isNotEmpty ? s.uidKartu! : 'Belum ada kartu',
                                            style: TextStyle(
                                              color: s.uidKartu != null && s.uidKartu!.isNotEmpty ? Colors.white60 : Colors.white38,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _fmt.format(s.saldo),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF10B981)),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.white60, size: 19),
                                          tooltip: 'Edit Siswa',
                                          onPressed: () => _showEditDialog(s),
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 19),
                                          tooltip: 'Hapus Siswa',
                                          onPressed: () => _confirmDelete(s),
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
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
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? action;
  const _DialogField({required this.controller, required this.label, this.keyboard, this.inputFormatters, this.action});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      textInputAction: action ?? TextInputAction.done,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.bgColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  const _PasswordField({required this.controller, required this.label, required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.bgColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white54),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
