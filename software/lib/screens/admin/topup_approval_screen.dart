import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/topup_request_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_theme.dart';

class TopUpApprovalScreen extends StatefulWidget {
  const TopUpApprovalScreen({super.key});

  @override
  State<TopUpApprovalScreen> createState() => _TopUpApprovalScreenState();
}

class _TopUpApprovalScreenState extends State<TopUpApprovalScreen> {
  final _svc = FirebaseService();
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _searchCtrl = TextEditingController();

  StreamSubscription<List<TopUpRequestModel>>? _sub;
  List<TopUpRequestModel> _requests = [];
  String? _error;
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _svc.expireStaleRequests();
    _subscribe();
  }

  void _subscribe() {
    setState(() { _loading = true; _error = null; });
    _sub?.cancel();
    _sub = _svc.streamPendingRequests().listen(
      (list) {
        if (mounted) setState(() { _requests = list; _loading = false; _error = null; });
      },
      onError: (e) {
        if (mounted) setState(() { _error = e.toString(); _loading = false; });
      },
      onDone: () {
        // Stream closed unexpectedly — retry after 2s
        if (mounted) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _subscribe();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _showPaymentInfoDialog() async {
    final info = await _svc.streamPaymentInfo().first;
    if (!mounted) return;

    bool qrisEnabled = info['qris_enabled'] != 'false';
    bool bankEnabled = info['bank_enabled'] != 'false';
    final bankCtrl = TextEditingController(text: info['bank_name']);
    final accNumCtrl = TextEditingController(text: info['account_number']);
    final accNameCtrl = TextEditingController(text: info['account_name']);
    final qrisCtrl = TextEditingController(text: info['qris_image_url']);
    bool uploadingQris = false;
    String? error;
    int activeTab = 0; // 0: QRIS, 1: Rekening, 2: Mesin

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppTheme.secondaryColor, size: 22),
              SizedBox(width: 10),
              Text('Pengaturan Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Segmented Tab Selector ──
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      _buildDialogTab(
                        title: 'QRIS',
                        icon: Icons.qr_code_2_rounded,
                        isActive: activeTab == 0,
                        badgeColor: qrisEnabled ? const Color(0xFF10B981) : Colors.white24,
                        onTap: () => setS(() => activeTab = 0),
                      ),
                      _buildDialogTab(
                        title: 'Rekening',
                        icon: Icons.account_balance_rounded,
                        isActive: activeTab == 1,
                        badgeColor: bankEnabled ? const Color(0xFF38BDF8) : Colors.white24,
                        onTap: () => setS(() => activeTab = 1),
                      ),
                      _buildDialogTab(
                        title: 'Mesin RFID',
                        icon: Icons.nfc_rounded,
                        isActive: activeTab == 2,
                        badgeColor: const Color(0xFF6366F1),
                        onTap: () => setS(() => activeTab = 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tab 0: QRIS ──
                if (activeTab == 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: qrisEnabled ? AppTheme.secondaryColor.withValues(alpha: 0.3) : Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status Pembayaran QRIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              qrisEnabled ? 'Aktif — Siswa dapat memilih QRIS' : 'Nonaktif — Siswa tidak dapat memilih QRIS',
                              style: TextStyle(fontSize: 11, color: qrisEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: qrisEnabled,
                          activeTrackColor: AppTheme.secondaryColor,
                          onChanged: (v) => setS(() => qrisEnabled = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (qrisCtrl.text.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              qrisCtrl.text,
                              height: 130,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Gagal memuat preview QRIS', style: TextStyle(color: Colors.white38, fontSize: 12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: uploadingQris ? null : () async {
                                  setS(() { uploadingQris = true; error = null; });
                                  try {
                                    final url = await CloudinaryService.pickAndUploadImage(folder: 'nbpay_qris');
                                    if (url != null) setS(() => qrisCtrl.text = url);
                                  } catch (e) {
                                    setS(() => error = e.toString().replaceFirst('Exception: ', ''));
                                  } finally {
                                    setS(() => uploadingQris = false);
                                  }
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 15),
                                label: const Text('Ganti Foto', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => setS(() => qrisCtrl.text = ''),
                                icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
                                label: const Text('Hapus', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: uploadingQris
                          ? const Column(
                              children: [
                                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(height: 8),
                                Text('Mengunggah ke Cloudinary...', style: TextStyle(fontSize: 11, color: Colors.white70)),
                              ],
                            )
                          : Column(
                              children: [
                                const Icon(Icons.qr_code_scanner_rounded, size: 36, color: AppTheme.secondaryColor),
                                const SizedBox(height: 6),
                                const Text('Belum ada foto QRIS terpasang', style: TextStyle(fontSize: 12, color: Colors.white60)),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: () async {
                                    setS(() { uploadingQris = true; error = null; });
                                    try {
                                      final url = await CloudinaryService.pickAndUploadImage(folder: 'nbpay_qris');
                                      if (url != null) setS(() => qrisCtrl.text = url);
                                    } catch (e) {
                                      setS(() => error = e.toString().replaceFirst('Exception: ', ''));
                                    } finally {
                                      setS(() => uploadingQris = false);
                                    }
                                  },
                                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                                  label: const Text('Upload Foto QRIS Baru', style: TextStyle(fontSize: 12)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildAppleField(
                    controller: qrisCtrl,
                    label: 'URL Gambar QRIS (Cloudinary atau Link Luar)',
                    hint: 'https://res.cloudinary.com/...',
                    onChanged: (v) => setS(() {}),
                  ),
                ],

                // ── Tab 1: Rekening Bank ──
                if (activeTab == 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bankEnabled ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status Transfer Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              bankEnabled ? 'Aktif — Siswa dapat transfer dengan kode unik' : 'Nonaktif — Siswa tidak dapat transfer bank',
                              style: TextStyle(fontSize: 11, color: bankEnabled ? const Color(0xFF38BDF8) : const Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: bankEnabled,
                          activeTrackColor: AppTheme.primaryColor,
                          onChanged: (v) => setS(() => bankEnabled = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAppleField(
                    controller: bankCtrl,
                    label: 'Nama Bank',
                    hint: 'Contoh: BCA, Mandiri, BRI, BSI',
                    action: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  _buildAppleField(
                    controller: accNumCtrl,
                    label: 'Nomor Rekening',
                    hint: 'Contoh: 1234567890',
                    inputType: TextInputType.number,
                    action: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  _buildAppleField(
                    controller: accNameCtrl,
                    label: 'Atas Nama (Pemilik Rekening)',
                    hint: 'Contoh: SMK Negeri Barokah',
                  ),
                ],

                // ── Tab 2: Mesin RFID ──
                if (activeTab == 2) ...[
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _svc.streamAllMachines(),
                    builder: (context, snap) {
                      final machines = (snap.data ?? []).where((m) {
                        final t = m['tujuan'] as String? ?? '';
                        return t == 'topup' || t == 'topup_daftar' || t == 'daftar_siswa';
                      }).toList();

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.nfc_rounded, size: 18, color: Color(0xFF10B981)),
                                SizedBox(width: 8),
                                Text(
                                  'Sinkronisasi Mesin Top-up Fisik',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Siswa dapat top-up tunai langsung melalui tap kartu RFID pada mesin sekolah.',
                              style: TextStyle(fontSize: 11, color: Colors.white60),
                            ),
                            const SizedBox(height: 10),
                            if (machines.isEmpty)
                              const Text('Belum ada mesin top-up terdaftar.', style: TextStyle(fontSize: 11, color: Colors.white38))
                            else
                              ...machines.map((m) {
                                final style = machineStatusStyle(m);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          m['nama'] as String? ?? m['id'] as String,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: style.color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: style.color.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          style.label,
                                          style: TextStyle(fontSize: 10, color: style.color, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Pengaman Aktif: Perintah scan kartu otomatis diblokir jika mesin berstatus Offline.',
                                    style: TextStyle(fontSize: 10, color: Colors.white54),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],

                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _svc.savePaymentInfo(
                    bankName: bankCtrl.text.trim(),
                    accountNumber: accNumCtrl.text.trim(),
                    accountName: accNameCtrl.text.trim(),
                    qrisImageUrl: qrisCtrl.text.trim(),
                    qrisEnabled: qrisEnabled,
                    bankEnabled: bankEnabled,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setS(() => error = e.toString());
                }
              },
              child: const Text('Simpan Pengaturan'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildDialogTab({
    required String title,
    required IconData icon,
    required bool isActive,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isActive ? AppTheme.bgColor : Colors.white60),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? AppTheme.bgColor : Colors.white70,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildAppleField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? inputType,
    TextInputAction? action,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: inputType,
          textInputAction: action,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
            fillColor: AppTheme.bgColor,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 1.5)),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text('Gagal memuat data', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _subscribe,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _requests.where((r) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final matchName = r.namaSiswa.toLowerCase().contains(q);
      final matchCode = r.kodeUnik != null && r.kodeUnik.toString().contains(q);
      final matchTotal = r.totalBayar.toInt().toString().contains(q);
      return matchName || matchCode || matchTotal;
    }).toList();

    return Column(
      children: [
        // ── Persistent Header: Search & Config ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 640;
              final searchField = SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari kode unik (misal: 247) atau nama siswa...',
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
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${filtered.length} Menunggu',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                ),
              );

              final configButton = FilledButton.icon(
                onPressed: _showPaymentInfoDialog,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Atur QRIS & Rekening', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          onPressed: _subscribe,
                        ),
                        const SizedBox(width: 8),
                        configButton,
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
                    onPressed: _subscribe,
                  ),
                  const SizedBox(width: 8),
                  configButton,
                ],
              );
            },
          ),
        ),

        // ── Stream Status Banner for Payment Channels ──
        StreamBuilder<Map<String, String>>(
          stream: _svc.streamPaymentInfo(),
          builder: (context, snap) {
            final info = snap.data ?? {};
            final qrisOn = info['qris_enabled'] != 'false';
            final bankOn = info['bank_enabled'] != 'false';
            final hasQris = (info['qris_image_url'] ?? '').isNotEmpty;
            final bankName = info['bank_name'] ?? '';

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  // QRIS status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: qrisOn ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: qrisOn ? const Color(0xFF10B981).withValues(alpha: 0.4) : Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 14,
                          color: qrisOn ? const Color(0xFF10B981) : Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'QRIS: ${qrisOn ? (hasQris ? "Siap" : "Belum Ada Foto") : "Nonaktif"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: qrisOn ? const Color(0xFF10B981) : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bank status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: bankOn ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: bankOn ? const Color(0xFF38BDF8).withValues(alpha: 0.4) : Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 14,
                          color: bankOn ? const Color(0xFF38BDF8) : Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bank: ${bankOn ? (bankName.isNotEmpty ? bankName : "Aktif") : "Nonaktif"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: bankOn ? const Color(0xFF38BDF8) : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: _showPaymentInfoDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'Ubah Status >',
                        style: TextStyle(fontSize: 11, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // ── Body List or Empty State ──
        Expanded(
          child: _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined, size: 64, color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text('Tidak ada request masuk', style: TextStyle(color: Colors.white38)),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _subscribe,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_outlined, size: 48, color: Colors.white24),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Tidak ada request dengan kata kunci "$_searchQuery"'
                                : 'Tidak ada request masuk',
                            style: const TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _subscribe(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _RequestCard(req: filtered[i], fmt: _fmt, svc: _svc),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatefulWidget {
  final TopUpRequestModel req;
  final NumberFormat fmt;
  final FirebaseService svc;
  const _RequestCard({required this.req, required this.fmt, required this.svc});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await widget.svc.approveTopUpRequest(widget.req);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Top-up disetujui & saldo ditambahkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Tolak Request?'),
        content: Text(
          'Request top-up ${widget.req.namaSiswa} sebesar ${widget.fmt.format(widget.req.amount)} akan ditolak.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await widget.svc.rejectTopUpRequest(widget.req.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodIcon = widget.req.method == 'qris' ? Icons.qr_code_2 : Icons.account_balance;
    final methodLabel = widget.req.method == 'qris' ? 'QRIS' : 'Transfer';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(methodIcon, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.req.namaSiswa,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(methodLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        if (widget.req.kodeUnik != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'Kode: ${widget.req.kodeUnik}',
                              style: const TextStyle(
                                color: Color(0xFF0EA5E9),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.fmt.format(widget.req.totalBayar),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF22C55E)),
                  ),
                  if (widget.req.kodeUnik != null)
                    Text(
                      'Pokok: ${widget.fmt.format(widget.req.amount)}',
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                ],
              ),
            ],
          ),
          if (widget.req.catatan != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes_outlined, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(widget.req.catatan!,
                        style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _approve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Setujui ${widget.fmt.format(widget.req.totalBayar)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


