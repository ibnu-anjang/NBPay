import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../widgets/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _svc = FirebaseService();
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  List<UserModel> _students = [];
  List<Map<String, dynamic>> _machines = [];
  bool _loading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _machinesSub;

  @override
  void initState() {
    super.initState();
    _load();
    _machinesSub = _svc.streamAllMachines().listen((machines) {
      if (!mounted) return;
      final filtered = machines.where((m) {
        final t = m['tujuan'] as String? ?? '';
        return t == 'topup_daftar' || t == 'topup' || t == 'daftar_siswa';
      }).toList();
      setState(() => _machines = filtered);
    });
  }

  @override
  void dispose() {
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

          return AlertDialog(
            backgroundColor: AppTheme.cardColor,
            title: const Text('Daftarkan Siswa Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_machines.length > 1) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedMachineId,
                      items: _machines.map((m) {
                        final s = machineStatusStyle(m);
                        return DropdownMenuItem<String>(
                          value: m['id'] as String,
                          child: Row(children: [
                            Icon(Icons.circle, size: 8, color: s.color),
                            const SizedBox(width: 8),
                            Text(m['nama'] as String? ?? m['id'] as String, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text('(${s.label})', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                          ]),
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
                              icon: const Icon(Icons.nfc, color: AppTheme.primaryColor),
                              tooltip: 'Scan Kartu',
                              onPressed: _machines.isEmpty ? null : startScanUid,
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
      text: s.saldo > 0 ? s.saldo.toInt().toString() : '',
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
            final machineId = _machines.first['id'] as String;
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

          return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Edit Data Siswa'),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: namaCtrl, label: 'Nama Siswa'),
              const SizedBox(height: 12),
              _DialogField(controller: nisCtrl, label: 'NIS', keyboard: TextInputType.number),
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
                          icon: const Icon(Icons.nfc, color: AppTheme.primaryColor),
                          tooltip: 'Scan Kartu',
                          onPressed: startScan,
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
                    if (uidKartuCtrl.text.trim().isNotEmpty) 'uid_kartu': uidKartuCtrl.text.trim(),
                  });
                  final saldoText = saldoCtrl.text.trim();
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
      await _svc.deleteUser(s.authUid ?? s.uidKartu!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Siswa'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.person_add_outlined), onPressed: _showRegisterDialog),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? const Center(child: Text('Belum ada siswa terdaftar'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _students.length,
                  itemBuilder: (ctx, i) {
                    final s = _students[i];
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
                          const CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('NIS: ${s.nis}  •  @${s.username ?? '-'}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                Text(s.uidKartu ?? '-', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_fmt.format(s.saldo),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                                    onPressed: () => _showEditDialog(s),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                    onPressed: () => _confirmDelete(s),
                                    padding: EdgeInsets.zero,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegisterDialog,
        icon: const Icon(Icons.add),
        label: const Text('Daftar Siswa'),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  const _DialogField({required this.controller, required this.label, this.keyboard});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
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
