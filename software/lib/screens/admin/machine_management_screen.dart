import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_theme.dart';

class MachineManagementScreen extends StatefulWidget {
  const MachineManagementScreen({super.key});

  @override
  State<MachineManagementScreen> createState() => _MachineManagementScreenState();
}

class _MachineManagementScreenState extends State<MachineManagementScreen> {
  final _svc = FirebaseService();
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    // Rebuild every 15s so offline detection stays fresh
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  static const _tujuanOptions = ['kasir', 'topup_daftar', 'cek_saldo'];
  static const _tujuanLabels = {
    'kasir': 'Kasir Pembayaran',
    'topup_daftar': 'Top-up & Daftar Siswa',
    'cek_saldo': 'Cek Saldo',
    // legacy labels for existing data
    'topup': 'Top-up Saldo',
    'daftar_siswa': 'Daftar Siswa',
  };

  void _showAddDialog() {
    final idCtrl = TextEditingController();
    final namaCtrl = TextEditingController();
    String tujuan = 'kasir';
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Tambah Mesin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Field(controller: idCtrl, label: 'ID Mesin (unik, contoh: kantin_01)', action: TextInputAction.next),
              const SizedBox(height: 12),
              _Field(controller: namaCtrl, label: 'Nama Mesin'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tujuan,
                items: _tujuanOptions.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(_tujuanLabels[t]!),
                )).toList(),
                onChanged: (v) => setDialogState(() => tujuan = v ?? 'kasir'),
                decoration: InputDecoration(
                  labelText: 'Tujuan Mesin',
                  filled: true,
                  fillColor: AppTheme.bgColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                dropdownColor: AppTheme.cardColor,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final id = idCtrl.text.trim();
                final nama = namaCtrl.text.trim();
                if (id.isEmpty || nama.isEmpty) {
                  setDialogState(() => error = 'Semua field wajib diisi');
                  return;
                }
                if (id.length > 64) {
                  setDialogState(() => error = 'ID maksimal 64 karakter');
                  return;
                }
                if (!RegExp(r'^[a-z0-9_]+$').hasMatch(id)) {
                  setDialogState(() => error = 'ID hanya boleh huruf kecil, angka, underscore. Contoh: kantin_01');
                  return;
                }
                try {
                  await _svc.addMachine(id, nama);
                  await _svc.updateMachineTujuan(id, tujuan);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDialogState(() => error = e.toString().replaceFirst('Exception: ', ''));
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTujuanDialog(String machineId, String currentTujuan) {
    String tujuan = _tujuanOptions.contains(currentTujuan) ? currentTujuan : 'kasir';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Ubah Tujuan Mesin'),
          content: DropdownButtonFormField<String>(
            initialValue: tujuan,
            items: _tujuanOptions.map((t) => DropdownMenuItem(
              value: t,
              child: Text(_tujuanLabels[t]!),
            )).toList(),
            onChanged: (v) => setDialogState(() => tujuan = v ?? 'kasir'),
            decoration: InputDecoration(
              labelText: 'Tujuan',
              filled: true,
              fillColor: AppTheme.bgColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            dropdownColor: AppTheme.cardColor,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                await _svc.updateMachineTujuan(machineId, tujuan);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String machineId, String nama) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Hapus Mesin'),
        content: Text('Hapus mesin "$nama" ($machineId)?'),
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
      await _svc.deleteMachine(machineId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Mesin'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {})),
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _svc.streamAllMachines(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final machines = snap.data ?? [];
          if (machines.isEmpty) {
            return const Center(child: Text('Belum ada mesin terdaftar'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: machines.length,
            itemBuilder: (ctx, i) {
              final m = machines[i];
              final id = m['id'] as String;
              final nama = m['nama'] as String? ?? id;
              final status = m['status'] as String? ?? 'idle';
              final tujuan = m['tujuan'] as String? ?? 'kasir';
              final isCekSaldo = tujuan == 'cek_saldo';

              // Offline detection via last_heartbeat
              final rawHeartbeat = m['last_heartbeat'];
              final bool isOffline;
              if (rawHeartbeat is Timestamp) {
                final diff = DateTime.now().difference(rawHeartbeat.toDate());
                isOffline = diff.inSeconds > 60;
              } else {
                // No heartbeat yet — hardware belum pernah kirim ping, anggap online
                isOffline = false;
              }

              Color statusColor;
              String statusLabel;
              if (isOffline) {
                statusColor = Colors.white38;
                statusLabel = 'offline';
              } else {
                switch (status) {
                  case 'waiting_tap':
                    statusColor = const Color(0xFFF59E0B);
                    statusLabel = 'Menunggu Tap';
                  case 'waiting_check':
                    statusColor = const Color(0xFF0EA5E9);
                    statusLabel = 'Memproses';
                  case 'showing_saldo':
                    statusColor = const Color(0xFF22C55E);
                    statusLabel = 'Tampil Saldo';
                  case 'success':
                    statusColor = const Color(0xFF22C55E);
                    statusLabel = 'Berhasil';
                  case 'error':
                    statusColor = const Color(0xFFEF4444);
                    statusLabel = 'Error';
                  default:
                    statusColor = const Color(0xFF22C55E);
                    statusLabel = 'Siap';
                }
              }

              // Extra info for cek_saldo machines showing result
              final saldoResult = (m['saldo_result'] as num?)?.toDouble();
              final namaResult = m['nama_result'] as String?;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOffline ? Colors.white12 : statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isCekSaldo
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF0EA5E9),
                      child: Icon(
                        isCekSaldo ? Icons.credit_score : Icons.point_of_sale,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nama, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(id, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(_tujuanLabels[tujuan] ?? tujuan,
                              style: TextStyle(
                                color: isCekSaldo
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFF0EA5E9),
                                fontSize: 11,
                              )),
                          if (status == 'showing_saldo' && saldoResult != null && namaResult != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '$namaResult  •  Rp ${saldoResult.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF22C55E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11)),
                    ),
                    const SizedBox(width: 4),
                    if (status != 'idle')
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                        tooltip: 'Reset ke idle',
                        onPressed: () => _svc.resetMachine(id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                      onPressed: () => _showEditTujuanDialog(id, tujuan),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                      onPressed: () => _confirmDelete(id, nama),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Mesin'),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputAction? action;
  const _Field({required this.controller, required this.label, this.action});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
