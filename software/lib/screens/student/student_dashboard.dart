import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.bgColor,
            elevation: 0,
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
                    'Siswa',
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
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Keluar',
                onPressed: () => svc.logout(),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 840;
              final content = isWide
                  ? _buildWideLayout(context, user, svc, fmt)
                  : _buildMobileLayout(context, user, svc, fmt);

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: content,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    UserModel? user,
    FirebaseService svc,
    NumberFormat fmt,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Smart Card & Actions (Fixed 380px)
          SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _SmartCard(user: user, uidKartu: uidKartu, fmt: fmt, svc: svc),
                  const SizedBox(height: 16),
                  _QuickActions(user: user, uidKartu: uidKartu, svc: svc),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Right Column: Filterable History
          Expanded(
            child: _HistoryTabs(uidKartu: uidKartu, svc: svc, fmt: fmt),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    UserModel? user,
    FirebaseService svc,
    NumberFormat fmt,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _SmartCard(user: user, uidKartu: uidKartu, fmt: fmt, svc: svc),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _QuickActions(user: user, uidKartu: uidKartu, svc: svc),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _HistoryTabs(uidKartu: uidKartu, svc: svc, fmt: fmt),
        ),
      ],
    );
  }
}

// ── Smart Card (E-Money Visual) ──────────────────────────────────────────────

class _SmartCard extends StatelessWidget {
  final UserModel? user;
  final String uidKartu;
  final NumberFormat fmt;
  final FirebaseService svc;

  const _SmartCard({
    required this.user,
    required this.uidKartu,
    required this.fmt,
    required this.svc,
  });

  @override
  Widget build(BuildContext context) {
    final isFrozen = user?.isFrozen ?? false;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isFrozen
              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
              : [const Color(0xFF4F46E5), const Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isFrozen ? Colors.black : const Color(0xFF6366F1)).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isFrozen ? const Color(0xFFEF4444).withValues(alpha: 0.6) : Colors.white24,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Chip icon, contactless wave, logo & status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Icon(Icons.credit_card_rounded, size: 18, color: Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.contactless_rounded, color: Colors.white70, size: 22),
                ],
              ),
              Row(
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
                      color: isFrozen
                          ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                          : const Color(0xFF22C55E).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isFrozen ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFrozen ? Icons.lock_rounded : Icons.check_circle_rounded,
                          size: 11,
                          color: isFrozen ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isFrozen ? 'BEKU' : 'AKTIF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isFrozen ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          // Saldo Area
          const Text('Saldo Kartu Siswa', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            fmt.format(user?.saldo ?? 0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          // Bottom Area: Name, NIS, & UID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nama ?? 'Memuat...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIS: ${user?.nis.isNotEmpty == true ? user!.nis : "-"}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  uidKartu,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions (Top-up & Freeze Card) ────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final UserModel? user;
  final String uidKartu;
  final FirebaseService svc;

  const _QuickActions({
    required this.user,
    required this.uidKartu,
    required this.svc,
  });

  void _showFreezeDialog(BuildContext context, bool currentFrozen) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              currentFrozen ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: currentFrozen ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 10),
            Text(currentFrozen ? 'Buka Kunci Kartu?' : 'Bekukan Kartu RFID?'),
          ],
        ),
        content: Text(
          currentFrozen
              ? 'Kartu RFID fisik Anda akan diaktifkan kembali dan dapat digunakan belanja di kasir kantin.'
              : 'Gunakan fitur ini jika kartu Anda hilang atau terjatuh! Semua transaksi tap di mesin kasir kantin akan langsung DITOLAK seketika.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentFrozen ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await svc.toggleFreezeCard(uidKartu, !currentFrozen);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        currentFrozen ? 'Kartu berhasil diaktifkan kembali!' : 'Kartu berhasil DIBEKUKAN!',
                      ),
                      backgroundColor: currentFrozen ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal mengubah status kartu: $e')),
                  );
                }
              }
            },
            child: Text(currentFrozen ? 'Aktifkan' : 'Bekukan Sekarang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFrozen = user?.isFrozen ?? false;

    return Row(
      children: [
        // Top-up Button
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: user == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TopUpRequestScreen(user: user!),
                      ),
                    ),
            icon: const Icon(Icons.add_card_rounded, size: 18),
            label: const Text('Top-up Saldo', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Freeze / Lock Button
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: user == null ? null : () => _showFreezeDialog(context, isFrozen),
            icon: Icon(
              isFrozen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              size: 18,
              color: isFrozen ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
            ),
            label: Text(
              isFrozen ? 'Buka Kunci' : 'Kunci Kartu',
              style: TextStyle(
                color: isFrozen ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: (isFrozen ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab Transaksi & Request (With Category Filters) ─────────────────────────

class _HistoryTabs extends StatefulWidget {
  final String uidKartu;
  final FirebaseService svc;
  final NumberFormat fmt;

  const _HistoryTabs({
    required this.uidKartu,
    required this.svc,
    required this.fmt,
  });

  @override
  State<_HistoryTabs> createState() => _HistoryTabsState();
}

class _HistoryTabsState extends State<_HistoryTabs> {
  String _filter = 'semua'; // 'semua' | 'credit' | 'debit'

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.all(4),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const TabBar(
              tabs: [
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Histori Transaksi'),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_card_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Request Top-up'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              children: [
                _buildTransactionList(),
                _RequestTab(uidKartu: widget.uidKartu, svc: widget.svc, fmt: widget.fmt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return Column(
      children: [
        // Filter Chips (Semua, Jajan, Top-up)
        HorizontalScrollChips(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildFilterChip('Semua', 'semua'),
            const SizedBox(width: 8),
            _buildFilterChip('Top-up (Masuk)', 'credit'),
            const SizedBox(width: 8),
            _buildFilterChip('Jajan (Keluar)', 'debit'),
          ],
        ),
        Expanded(
          child: StreamBuilder<List<TransactionModel>>(
            stream: widget.svc.streamTransactions(widget.uidKartu),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final allTxs = snap.data ?? [];
              final txs = allTxs.where((t) {
                if (_filter == 'credit') return t.tipe == 'credit';
                if (_filter == 'debit') return t.tipe == 'debit';
                return true;
              }).toList();

              if (txs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 54, color: Colors.white24),
                      const SizedBox(height: 10),
                      Text(
                        _filter == 'semua'
                            ? 'Belum ada transaksi sama sekali'
                            : 'Tidak ada transaksi kategori ini',
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: txs.length,
                itemBuilder: (_, i) => _TxCard(tx: txs[i], fmt: widget.fmt),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.keterangan,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 54, color: Colors.white24),
                SizedBox(height: 10),
                Text('Belum ada riwayat pengajuan top-up', style: TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Top-up $methodLabel', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (req.kodeUnik != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Kode: ${req.kodeUnik}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
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
              Text(
                '+${fmt.format(req.totalBayar)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
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
