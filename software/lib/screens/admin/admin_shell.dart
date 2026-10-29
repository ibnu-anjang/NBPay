import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'topup_screen.dart';
import 'topup_approval_screen.dart';
import 'user_management_screen.dart';
import 'penjual_management_screen.dart';
import 'admin_management_screen.dart';
import 'machine_management_screen.dart';
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

  final _showingSaldoTimers = <String, Timer>{};

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
        // Auto-reset showing_saldo after 8s in case hardware doesn't reset
        if (status == 'showing_saldo') {
          if (!_showingSaldoTimers.containsKey(id)) {
            _showingSaldoTimers[id] = Timer(const Duration(seconds: 8), () {
              _showingSaldoTimers.remove(id);
              _svc.resetMachine(id);
            });
          }
        } else {
          _showingSaldoTimers.remove(id)?.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _cekSaldoSub?.cancel();
    for (final t in _showingSaldoTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  static const _sections = [
    TopUpScreen(),
    _AdminApprovalsSection(),
    _AdminUsersSection(),
    MachineManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 840;

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
                  const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    NavigationRailDestination(
                      icon: Icon(Icons.add_card_outlined),
                      selectedIcon: Icon(Icons.add_card_rounded),
                      label: Text('Top-up'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.verified_outlined),
                      selectedIcon: Icon(Icons.verified_rounded),
                      label: Text('Persetujuan'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.group_outlined),
                      selectedIcon: Icon(Icons.group_rounded),
                      label: Text('Pengguna'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.nfc_outlined),
                      selectedIcon: Icon(Icons.nfc_rounded),
                      label: Text('Mesin RFID'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, color: Colors.white12),
                Expanded(
                  child: Column(
                    children: [
                      _GreetingBanner(userFuture: _userFuture, role: 'Admin'),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: _sections[_index.clamp(0, _sections.length - 1)],
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

        // Mobile Layout (Compact & Spacious Bottom Bar)
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
                    'Admin',
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
              _GreetingBanner(userFuture: _userFuture, role: 'Admin'),
              Expanded(child: _sections[_index.clamp(0, _sections.length - 1)]),
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
              BottomNavigationBarItem(
                icon: Icon(Icons.add_card_outlined),
                activeIcon: Icon(Icons.add_card_rounded),
                label: 'Top-up',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.verified_outlined),
                activeIcon: Icon(Icons.verified_rounded),
                label: 'Persetujuan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group_outlined),
                activeIcon: Icon(Icons.group_rounded),
                label: 'Pengguna',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.nfc_outlined),
                activeIcon: Icon(Icons.nfc_rounded),
                label: 'Mesin RFID',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Composite Section: Approvals (Top-up & Withdrawal) ───────────────────────

class _AdminApprovalsSection extends StatelessWidget {
  const _AdminApprovalsSection();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const TabBar(
              tabs: [
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.input_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Top-up Siswa'),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Pencairan Kantin'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                TopUpApprovalScreen(),
                PenjualWithdrawalScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Composite Section: Users (Siswa, Penjual, Admin) ─────────────────────────

class _AdminUsersSection extends StatelessWidget {
  const _AdminUsersSection();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const TabBar(
              tabs: [
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Siswa'),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Penjual'),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                UserManagementScreen(),
                PenjualManagementScreen(),
                AdminManagementScreen(),
              ],
            ),
          ),
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
        final nama = snap.data?.nama ?? 'Administrator';
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
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Selamat datang, $nama',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Portal Manajemen $role NBPay',
                      style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                      'Sistem Online',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
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
