import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'topup_screen.dart';
import 'topup_approval_screen.dart';
import 'user_management_screen.dart';
import 'penjual_management_screen.dart';
import 'admin_management_screen.dart';
import 'machine_management_screen.dart';
import 'card_scanner_screen.dart';
import 'machine_simulator_screen.dart';
import 'penjual_withdrawal_screen.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../widgets/app_theme.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  final _svc = FirebaseService();
  StreamSubscription<List<Map<String, dynamic>>>? _cekSaldoSub;
  // Track which machines are being processed to avoid duplicate calls
  final _processing = <String>{};

  late final Future<UserModel> _userFuture = () async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('no uid');
    return _svc.getUserByAuthUid(uid);
  }();

  @override
  void initState() {
    super.initState();
    _cekSaldoSub = _svc.streamAllMachines().listen((machines) {
      for (final m in machines) {
        final id = m['id'] as String;
        final tujuan = m['tujuan'] as String? ?? '';
        final status = m['status'] as String? ?? 'idle';
        final lastUid = m['last_uid'] as String?;
        if (tujuan == 'cek_saldo' && status == 'waiting_check' &&
            lastUid != null && lastUid.isNotEmpty && !_processing.contains(id)) {
          _processing.add(id);
          _svc.processCekSaldo(id, lastUid).whenComplete(() => _processing.remove(id));
        }
      }
    });
  }

  @override
  void dispose() {
    _cekSaldoSub?.cancel();
    super.dispose();
  }

  static final _screens = [
    const TopUpScreen(),
    const TopUpApprovalScreen(),
    const UserManagementScreen(),
    const PenjualManagementScreen(),
    const PenjualWithdrawalScreen(),
    const AdminManagementScreen(),
    const MachineManagementScreen(),
    const CardScannerScreen(),
    const MachineSimulatorScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NBPay Admin'),
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
          _GreetingBanner(userFuture: _userFuture, role: 'Admin'),
          Expanded(child: _screens[_index.clamp(0, _screens.length - 1)]),
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
          BottomNavigationBarItem(icon: Icon(Icons.add_card_outlined), label: 'Top-up'),
          BottomNavigationBarItem(icon: Icon(Icons.inbox_outlined), label: 'Permintaan'),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_outlined), label: 'Siswa'),
          BottomNavigationBarItem(icon: Icon(Icons.store_outlined), label: 'Penjual'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), label: 'Tarik'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Admin'),
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_outlined), label: 'Mesin'),
          BottomNavigationBarItem(icon: Icon(Icons.nfc_outlined), label: 'Scan Kartu'),
          BottomNavigationBarItem(icon: Icon(Icons.science_outlined), label: 'Simulator'),
        ],
      ),
    );
  }
}

class _GreetingBanner extends StatelessWidget {
  final Future<UserModel> userFuture;
  final String role;
  const _GreetingBanner({required this.userFuture, required this.role});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel>(
      future: userFuture,
      builder: (context, snap) {
        final nama = snap.data?.nama ?? '...';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Halo, $nama!',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(role,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
