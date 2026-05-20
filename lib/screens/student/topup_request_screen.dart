import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_theme.dart';

class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) return oldValue;
    final formatted = NumberFormat('#,###', 'id_ID').format(int.parse(digits));
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class TopUpRequestScreen extends StatefulWidget {
  final UserModel user;
  const TopUpRequestScreen({super.key, required this.user});

  @override
  State<TopUpRequestScreen> createState() => _TopUpRequestScreenState();
}

class _TopUpRequestScreenState extends State<TopUpRequestScreen> {
  final _svc = FirebaseService();
  final _amountCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  final _catatanFocus = FocusNode();
  final _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _method = 'qris';
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _catatanCtrl.dispose();
    _catatanFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(
      _amountCtrl.text.replaceAll('.', '').replaceAll(',', ''),
    );
    if (amount == null || amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal top-up Rp 10.000')),
      );
      return;
    }
    if (amount > 500000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal top-up Rp 500.000 per request')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _svc.submitTopUpRequest(
        uidKartu: widget.user.uidKartu ?? '',
        namaSiswa: widget.user.nama,
        amount: amount,
        method: _method,
        catatan: _catatanCtrl.text.trim().isEmpty
            ? null
            : _catatanCtrl.text.trim(),
      );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Top-up')),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Color(0xFF22C55E),
            ),
            const SizedBox(height: 16),
            const Text(
              'Request Terkirim!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Admin akan memverifikasi pembayaran Anda dan saldo akan ditambahkan setelah dikonfirmasi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali ke Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return StreamBuilder<Map<String, String>>(
      stream: _svc.streamPaymentInfo(),
      builder: (context, snap) {
        final info = snap.data ?? {};
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MethodCard(
                    label: 'QRIS',
                    icon: Icons.qr_code_2,
                    selected: _method == 'qris',
                    onTap: () => setState(() => _method = 'qris'),
                  ),
                  const SizedBox(width: 12),
                  _MethodCard(
                    label: 'Transfer',
                    icon: Icons.account_balance,
                    selected: _method == 'transfer',
                    onTap: () => setState(() => _method = 'transfer'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_method == 'qris')
                _InfoCard(
                  child: _QrisSection(imageUrl: info['qris_image_url'] ?? ''),
                )
              else
                _InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Rekening',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Bank',
                        value: info['bank_name']?.isEmpty == false
                            ? info['bank_name']!
                            : '-',
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(
                        label: 'No. Rekening',
                        value: info['account_number']?.isEmpty == false
                            ? info['account_number']!
                            : '-',
                        copyable: info['account_number']?.isNotEmpty == true,
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(
                        label: 'Atas Nama',
                        value: info['account_name']?.isEmpty == false
                            ? info['account_name']!
                            : '-',
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              const Text(
                'Jumlah Top-up',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_ThousandSeparatorFormatter()],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _catatanFocus.requestFocus(),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: 'Minimal Rp. 10.000',
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [10000, 20000, 50000, 100000]
                    .map(
                      (a) => ActionChip(
                        label: Text(_fmt.format(a)),
                        onPressed: () => setState(
                            () => _amountCtrl.text = NumberFormat('#,###', 'id_ID').format(a)),
                        backgroundColor: AppTheme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Catatan (opsional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _catatanCtrl,
                focusNode: _catatanFocus,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Contoh: sudah transfer jam 10:30',
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Kirim Request'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QrisSection extends StatelessWidget {
  final String imageUrl;
  const _QrisSection({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const Column(
        children: [
          Icon(Icons.qr_code_2, size: 80, color: Colors.white24),
          SizedBox(height: 8),
          Text(
            'QRIS belum dikonfigurasi oleh admin',
            style: TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (_, e, st) => const Column(
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 60,
                  color: Colors.white24,
                ),
                SizedBox(height: 4),
                Text(
                  'Gagal memuat gambar QRIS',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Scan QRIS di atas untuk membayar',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            final uri = Uri.parse(imageUrl);
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Unduh / Buka QRIS'),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _MethodCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : Colors.white12,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? AppTheme.primaryColor : Colors.white54,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.primaryColor : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Row(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (copyable) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nomor rekening disalin'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Icon(
                  Icons.copy_outlined,
                  size: 16,
                  color: Colors.white38,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
