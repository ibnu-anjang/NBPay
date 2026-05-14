import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_theme.dart';

/// Screen untuk handle hardware-triggered card scan (topup_daftar mode)
/// Admin open screen ini, pilih mesin, hardware scan kartu, app show UI untuk register/topup
class CardScannerScreen extends StatefulWidget {
  const CardScannerScreen({super.key});

  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

class _CardScannerScreenState extends State<CardScannerScreen> {
  final _svc = FirebaseService();
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  List<Map<String, dynamic>> _machines = [];
  String? _selectedMachineId;
  StreamSubscription<List<Map<String, dynamic>>>? _machinesSub;
  StreamSubscription? _machineStateSub;

  // Card scan state
  String? _scannedUid;
  bool _showingOptions = false;
  bool _isRegistering = false;
  bool _isTopping = false;

  // Register form
  late TextEditingController _namaCtrl;
  late TextEditingController _nisCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;

  // Topup form
  late TextEditingController _amountCtrl;
  List<int> _quickAmounts = [10000, 20000, 50000, 100000];
  StreamSubscription<List<int>>? _qaSub;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController();
    _nisCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _amountCtrl = TextEditingController();

    _machinesSub = _svc.streamAllMachines().listen((machines) {
      final daftarMachines = machines
          .where((m) => (m['tujuan'] as String?) == 'topup_daftar')
          .toList();
      setState(() => _machines = daftarMachines);
    });

    _qaSub = _svc.streamQuickAmounts().listen((amounts) {
      setState(() => _quickAmounts = amounts);
    });
  }

  @override
  void dispose() {
    _machinesSub?.cancel();
    _machineStateSub?.cancel();
    _qaSub?.cancel();
    _namaCtrl.dispose();
    _nisCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _selectMachine(String machineId) {
    _machineStateSub?.cancel();
    setState(() {
      _selectedMachineId = machineId;
      _scannedUid = null;
      _showingOptions = false;
      _isRegistering = false;
      _isTopping = false;
    });

    // Listen ke machine state untuk detect UID scan
    _machineStateSub = _svc.streamMachine(machineId).listen((state) {
      if (state.status == 'waiting_uid' && state.lastUid != null && !_showingOptions) {
        setState(() {
          _scannedUid = state.lastUid;
          _showingOptions = true;
        });
      }
    });
  }

  Future<void> _registerStudent() async {
    if (_namaCtrl.text.isEmpty || _nisCtrl.text.isEmpty ||
        _usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua field wajib diisi')),
      );
      return;
    }

    setState(() => _isRegistering = true);
    try {
      await _svc.registerStudentWithAuth(
        uidKartu: _scannedUid!,
        nama: _namaCtrl.text,
        nis: _nisCtrl.text,
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Siswa berhasil didaftarkan'), duration: Duration(seconds: 2)),
        );
        await _svc.resetMachine(_selectedMachineId!);
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  Future<void> _topupStudent() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll('.', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Input amount harus valid')),
      );
      return;
    }

    setState(() => _isTopping = true);
    try {
      await _svc.topUp(_scannedUid!, amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Top-up Rp ${_fmt.format(amount)} berhasil')),
        );
        await _svc.resetMachine(_selectedMachineId!);
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isTopping = false);
    }
  }

  void _resetForm() {
    setState(() {
      _scannedUid = null;
      _showingOptions = false;
      _isRegistering = false;
      _isTopping = false;
      _namaCtrl.clear();
      _nisCtrl.clear();
      _usernameCtrl.clear();
      _passwordCtrl.clear();
      _amountCtrl.clear();
    });
  }

  Future<void> _cancelScan() async {
    if (_selectedMachineId != null) {
      await _svc.resetMachine(_selectedMachineId!);
    }
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Kartu — Topup/Daftar'),
      ),
      body: _selectedMachineId == null ? _buildMachineSelection() : _buildScannerUI(),
    );
  }

  Widget _buildMachineSelection() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _machines.length,
      itemBuilder: (ctx, i) {
        final m = _machines[i];
        return Card(
          color: AppTheme.cardColor,
          child: ListTile(
            title: Text(m['nama'] as String? ?? m['id']),
            subtitle: Text(m['id'] as String),
            onTap: () => _selectMachine(m['id'] as String),
          ),
        );
      },
    );
  }

  Widget _buildScannerUI() {
    if (!_showingOptions || _scannedUid == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nfc, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'Siap menerima scan kartu',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => setState(() => _selectedMachineId = null),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Ganti Mesin'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Scanned UID
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('UID Terdeteksi', style: TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 8),
                Text(
                  _scannedUid!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Options: Register or Topup
          if (!_isRegistering && !_isTopping)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => setState(() => _isRegistering = true),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Daftar Siswa Baru'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => setState(() => _isTopping = true),
                    icon: const Icon(Icons.add_circle),
                    label: const Text('Topup Saldo'),
                  ),
                ),
              ],
            ),

          // Register form
          if (_isRegistering) ...[
            const SizedBox(height: 24),
            const Text(
              'Daftar Siswa Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTextField(_namaCtrl, 'Nama Lengkap', Icons.person),
            _buildTextField(_nisCtrl, 'NIS', Icons.numbers),
            _buildTextField(_usernameCtrl, 'Username', Icons.mail),
            _buildTextField(_passwordCtrl, 'Password', Icons.lock, obscure: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _registerStudent,
                child: const Text('Daftar Siswa'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _isRegistering = false),
                child: const Text('Batal'),
              ),
            ),
          ],

          // Topup form
          if (_isTopping) ...[
            const SizedBox(height: 24),
            const Text(
              'Top-up Saldo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTextField(_amountCtrl, 'Jumlah (Rp)', Icons.money),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _quickAmounts.map((amount) {
                return ActionChip(
                  label: Text(_fmt.format(amount)),
                  onPressed: () => _amountCtrl.text = amount.toString(),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _topupStudent,
                child: const Text('Proses Top-up'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _isTopping = false),
                child: const Text('Batal'),
              ),
            ),
          ],

          // Cancel button
          if (_showingOptions && !_isRegistering && !_isTopping) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelScan,
                icon: const Icon(Icons.close),
                label: const Text('Batalkan Scan'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: AppTheme.bgColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
