import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_theme.dart';

class MachineSimulatorScreen extends StatefulWidget {
  const MachineSimulatorScreen({super.key});

  @override
  State<MachineSimulatorScreen> createState() => _MachineSimulatorScreenState();
}

class _MachineSimulatorScreenState extends State<MachineSimulatorScreen> {
  final _svc = FirebaseService();
  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _machines = [];
  String? _selectedId;
  String _log = 'Pilih mesin dan mulai simulasi...';
  bool _heartbeatActive = false;
  Timer? _heartbeatTimer;

  // Dummy NFC UIDs for testing (real student card UIDs from Firestore)
  final _uidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMachines();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _uidCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMachines() async {
    final machines = await _svc.getAllMachines();
    setState(() => _machines = machines);
  }

  Map<String, dynamic>? get _selected =>
      _machines.where((m) => m['id'] == _selectedId).firstOrNull;

  void _addLog(String msg) {
    final time = TimeOfDay.now().format(context);
    setState(() => _log = '[$time] $msg\n$_log');
  }

  Future<void> _simulateTap() async {
    final id = _selectedId;
    final uid = _uidCtrl.text.trim();
    if (id == null) return _addLog('⚠️ Pilih mesin dulu');
    if (uid.isEmpty) return _addLog('⚠️ Isi UID kartu dulu');

    final tujuan = _selected?['tujuan'] ?? 'kasir';

    if (tujuan == 'cek_saldo') {
      await _db.collection('machine_commands').doc(id).set({
        'status': 'waiting_check',
        'last_uid': uid,
      }, SetOptions(merge: true));
      _addLog('📲 NFC tap → uid=$uid | status: waiting_check');
      _addLog('⏳ Menunggu respons app...');

      // Simulasi hardware: listen sampai showing_saldo lalu auto-reset (persis firmware asli)
      final sub = _db.collection('machine_commands').doc(id).snapshots().listen(null);
      sub.onData((snap) async {
        final data = snap.data() ?? {};
        final status = data['status'] as String?;
        if (status == 'showing_saldo') {
          final nama = data['nama_result'] ?? '?';
          final saldo = (data['saldo_result'] as num?)?.toDouble() ?? 0;
          _addLog('✅ Saldo diterima: $nama — Rp ${saldo.toStringAsFixed(0)}');
          _addLog('🖥️ Mesin tampil saldo 5 detik...');
          await sub.cancel();
          await Future.delayed(const Duration(seconds: 5));
          await _db.collection('machine_commands').doc(id).set({
            'status': 'idle',
            'last_uid': FieldValue.delete(),
            'saldo_result': FieldValue.delete(),
            'nama_result': FieldValue.delete(),
          }, SetOptions(merge: true));
          _addLog('🔄 Mesin auto-reset ke idle (seperti hardware asli)');
        } else if (status == 'error') {
          final pesan = data['nama_result'] ?? 'Kartu tidak dikenal';
          _addLog('❌ Error: $pesan');
          await sub.cancel();
          await Future.delayed(const Duration(seconds: 3));
          await _db.collection('machine_commands').doc(id).set(
            {'status': 'idle'},
            SetOptions(merge: true),
          );
          _addLog('🔄 Mesin auto-reset ke idle');
        }
      });
    } else if (tujuan == 'kasir') {
      await _db.collection('machine_commands').doc(id).set({
        'last_uid': uid,
      }, SetOptions(merge: true));
      _addLog('📲 NFC tap → uid=$uid (kasir)');
    } else if (tujuan == 'topup_daftar') {
      await _db.collection('machine_commands').doc(id).set({
        'last_uid': uid,
      }, SetOptions(merge: true));
      _addLog('📲 NFC tap → uid=$uid (topup_daftar)');
    }
  }

  void _toggleHeartbeat() {
    if (_selectedId == null) {
      _addLog('⚠️ Pilih mesin dulu');
      return;
    }
    if (_heartbeatActive) {
      _heartbeatTimer?.cancel();
      setState(() => _heartbeatActive = false);
      // Set last_heartbeat ke 2 menit lalu → langsung kedetect offline
      final twoMinsAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 2)),
      );
      _db.collection('machine_commands').doc(_selectedId!).set(
        {'last_heartbeat': twoMinsAgo},
        SetOptions(merge: true),
      );
      _addLog('💔 Heartbeat stop → mesin akan muncul offline dalam ~15 detik');
    } else {
      _sendHeartbeat();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendHeartbeat());
      setState(() => _heartbeatActive = true);
      _addLog('💚 Heartbeat dimulai (setiap 30 detik)');
    }
  }

  Future<void> _sendHeartbeat() async {
    if (_selectedId == null) return;
    await _svc.updateMachineHeartbeat(_selectedId!);
    _addLog('💓 Heartbeat dikirim → last_heartbeat updated');
  }

  Future<void> _resetMachine() async {
    if (_selectedId == null) return;
    await _db.collection('machine_commands').doc(_selectedId!).set({
      'status': 'idle',
      'last_uid': FieldValue.delete(),
      'saldo_result': FieldValue.delete(),
      'nama_result': FieldValue.delete(),
    }, SetOptions(merge: true));
    _addLog('🔄 Mesin direset ke idle');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulator Mesin'),
        backgroundColor: const Color(0xFF7C3AED),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('🤖 Pilih Mesin'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _selectedId,
                isExpanded: true,
                underline: const SizedBox(),
                hint: const Text('Pilih mesin...', style: TextStyle(color: Colors.white54)),
                items: _machines.map((m) => DropdownMenuItem(
                  value: m['id'] as String,
                  child: Text('${m['nama']} (${m['tujuan'] ?? '-'})'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedId = v),
              ),
            ),

            if (_selected != null) ...[
              const SizedBox(height: 8),
              StreamBuilder<DocumentSnapshot>(
                stream: _db.collection('machine_commands').doc(_selectedId).snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const SizedBox();
                  final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                  final status = data['status'] ?? 'idle';
                  final saldo = data['saldo_result'];
                  final nama = data['nama_result'];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status Firebase: $status',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        if (nama != null)
                          Text('nama_result: $nama',
                              style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13)),
                        if (saldo != null)
                          Text('saldo_result: Rp $saldo',
                              style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13)),
                      ],
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 20),
            _sectionLabel('📶 Heartbeat'),
            const SizedBox(height: 8),
            _SimButton(
              label: _heartbeatActive ? 'Stop Heartbeat (simulasi OFF)' : 'Start Heartbeat (simulasi ON)',
              color: _heartbeatActive ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
              onTap: _toggleHeartbeat,
            ),

            const SizedBox(height: 20),
            _sectionLabel('💳 Simulasi NFC Tap'),
            const SizedBox(height: 8),
            TextField(
              controller: _uidCtrl,
              decoration: InputDecoration(
                hintText: 'UID kartu siswa (dari Firestore users doc ID)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _SimButton(
              label: 'Simulasi Tap Kartu',
              color: const Color(0xFF0EA5E9),
              onTap: _simulateTap,
            ),

            const SizedBox(height: 20),
            _sectionLabel('🔄 Reset'),
            const SizedBox(height: 8),
            _SimButton(
              label: 'Reset Mesin ke Idle',
              color: Colors.white24,
              onTap: _resetMachine,
            ),

            const SizedBox(height: 20),
            _sectionLabel('📋 Log'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                _log,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white70),
      );
}

class _SimButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SimButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
