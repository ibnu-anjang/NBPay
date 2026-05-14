import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/topup_request_model.dart';
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

  StreamSubscription<List<TopUpRequestModel>>? _sub;
  List<TopUpRequestModel> _requests = [];
  String? _error;
  bool _loading = true;

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
    _sub?.cancel();
    super.dispose();
  }

  void _showPaymentInfoDialog() async {
    final info = await _svc.streamPaymentInfo().first;
    if (!mounted) return;

    final bankCtrl = TextEditingController(text: info['bank_name']);
    final accNumCtrl = TextEditingController(text: info['account_number']);
    final accNameCtrl = TextEditingController(text: info['account_name']);
    final qrisCtrl = TextEditingController(text: info['qris_image_url']);
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Info Rekening & QRIS'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transfer', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                _DialogField(controller: bankCtrl, label: 'Nama Bank'),
                const SizedBox(height: 10),
                _DialogField(controller: accNumCtrl, label: 'No. Rekening', inputType: TextInputType.number),
                const SizedBox(height: 10),
                _DialogField(controller: accNameCtrl, label: 'Atas Nama'),
                const SizedBox(height: 16),
                const Text('QRIS', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                _DialogField(controller: qrisCtrl, label: 'URL Gambar QRIS'),
                const SizedBox(height: 4),
                const Text(
                  'Upload gambar QRIS ke hosting (imgur, Firebase Storage, dll) lalu paste URL-nya di sini.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _svc.savePaymentInfo(
                    bankName: bankCtrl.text.trim(),
                    accountNumber: accNumCtrl.text.trim(),
                    accountName: accNameCtrl.text.trim(),
                    qrisImageUrl: qrisCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setS(() => error = e.toString());
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPaymentInfoDialog,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit Rekening/QRIS'),
        backgroundColor: AppTheme.primaryColor,
      ),
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

    if (_requests.isEmpty) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _subscribe(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _requests.length,
        itemBuilder: (ctx, i) => _RequestCard(req: _requests[i], fmt: _fmt, svc: _svc),
      ),
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
                    Text(methodLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                widget.fmt.format(widget.req.amount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF22C55E)),
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
                      : const Text('Setujui'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType inputType;
  const _DialogField({required this.controller, required this.label, this.inputType = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.bgColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
