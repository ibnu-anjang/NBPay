import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../models/topup_request_model.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_theme.dart';
import 'topup_request_screen.dart';

class StudentDashboard extends StatelessWidget {
  final String uidKartu;
  const StudentDashboard({super.key, required this.uidKartu});

  @override
  Widget build(BuildContext context) {
    final svc = FirebaseService();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return StreamBuilder<UserModel?>(
      stream: svc.streamUser(uidKartu),
      builder: (context, userSnap) {
        final user = userSnap.data;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF6366F1),
              title: const Text('SmartSchool Pay', style: TextStyle(color: Colors.white)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Logout',
                  onPressed: () => svc.logout(),
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Transaksi'),
                  Tab(text: 'Riwayat Request'),
                ],
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
              ),
            ),
            body: Column(
              children: [
                _HeaderCard(user: user, uidKartu: uidKartu, fmt: fmt),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TransactionTab(uidKartu: uidKartu, svc: svc, fmt: fmt),
                      _RequestTab(uidKartu: uidKartu, svc: svc, fmt: fmt),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UserModel? user;
  final String uidKartu;
  final NumberFormat fmt;
  const _HeaderCard({required this.user, required this.uidKartu, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Halo, ${user?.nama ?? '...'}!',
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 2),
          Text(user?.nis ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          const Text('Saldo Anda', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            fmt.format(user?.saldo ?? 0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(uidKartu,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
              const Spacer(),
              SizedBox(
                width: 110,
                child: ElevatedButton.icon(
                onPressed: user == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TopUpRequestScreen(user: user!),
                          ),
                        ),
                icon: const Icon(Icons.add_card, size: 16),
                label: const Text('Top-up'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Riwayat Transaksi ─────────────────────────────────────────────────

class _TransactionTab extends StatelessWidget {
  final String uidKartu;
  final FirebaseService svc;
  final NumberFormat fmt;
  const _TransactionTab({required this.uidKartu, required this.svc, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionModel>>(
      stream: svc.streamTransactions(uidKartu),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(snap.error.toString(),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        final txs = snap.data ?? [];
        if (txs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 60, color: Colors.white24),
                SizedBox(height: 12),
                Text('Belum ada transaksi', style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: txs.length,
          itemBuilder: (_, i) => _TxCard(tx: txs[i], fmt: fmt),
        );
      },
    );
  }
}

class _TxCard extends StatelessWidget {
  final TransactionModel tx;
  final NumberFormat fmt;
  const _TxCard({required this.tx, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isDebit = tx.tipe == 'debit';
    final color = isDebit ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final icon = isDebit ? Icons.shopping_bag_outlined : Icons.add_card_outlined;
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.keterangan, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(tx.timestamp),
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          Text(
            '${isDebit ? '-' : '+'}${fmt.format(tx.nominal)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Riwayat Request Top-up ────────────────────────────────────────────

class _RequestTab extends StatelessWidget {
  final String uidKartu;
  final FirebaseService svc;
  final NumberFormat fmt;
  const _RequestTab({required this.uidKartu, required this.svc, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TopUpRequestModel>>(
      stream: svc.streamMyTopUpRequests(uidKartu),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(snap.error.toString(),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 60, color: Colors.white24),
                SizedBox(height: 12),
                Text('Belum ada request top-up', style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (_, i) => _RequestCard(req: requests[i], fmt: fmt),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final TopUpRequestModel req;
  final NumberFormat fmt;
  const _RequestCard({required this.req, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (req.status) {
      'approved' => (const Color(0xFF22C55E), Icons.check_circle_outline, 'Disetujui'),
      'rejected' => (const Color(0xFFEF4444), Icons.cancel_outlined, 'Ditolak'),
      'expired'  => (Colors.white38, Icons.timer_off_outlined, 'Kedaluwarsa'),
      _ => (const Color(0xFFF59E0B), Icons.hourglass_empty_outlined, 'Menunggu'),
    };

    final methodLabel = req.method == 'qris' ? 'QRIS' : req.method == 'transfer' ? 'Transfer' : 'Cash';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Request Top-up · $methodLabel',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(req.timestamp),
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                if (req.catatan != null) ...[
                  const SizedBox(height: 2),
                  Text(req.catatan!,
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${fmt.format(req.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
