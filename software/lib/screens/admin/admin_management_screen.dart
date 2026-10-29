import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../widgets/app_theme.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final _svc = FirebaseService();
  List<UserModel> _admins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snap = await _svc.getAllAdmins();
    if (!mounted) return;
    setState(() { _admins = snap; _loading = false; });
  }

  void _showAddDialog() {
    final namaCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscure = true;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Tambah Admin Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Field(controller: namaCtrl, label: 'Nama Admin', action: TextInputAction.next),
              const SizedBox(height: 12),
              _Field(controller: usernameCtrl, label: 'Username', action: TextInputAction.next),
              const SizedBox(height: 4),
              const Text('Username tidak dapat diubah setelah ditambahkan.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 12),
              _PasswordField(controller: passCtrl, label: 'Password', obscure: obscure,
                onToggle: () => setDialogState(() => obscure = !obscure)),
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
                if (namaCtrl.text.isEmpty || usernameCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                  setDialogState(() => error = 'Semua field wajib diisi');
                  return;
                }
                try {
                  await _svc.registerAdmin(
                    nama: namaCtrl.text.trim(),
                    username: usernameCtrl.text.trim(),
                    password: passCtrl.text,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  setDialogState(() => error = friendlyAuthError(e));
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(UserModel admin) {
    final namaCtrl = TextEditingController(text: admin.nama);
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Edit Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Field(controller: namaCtrl, label: 'Nama Admin'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 14, color: Colors.white38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Username: @${admin.username ?? '-'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('Username tidak dapat diubah.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
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
                if (namaCtrl.text.isEmpty) {
                  setDialogState(() => error = 'Nama tidak boleh kosong');
                  return;
                }
                try {
                  await _svc.updateUser(admin.authUid!, {'nama': namaCtrl.text.trim()});
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  setDialogState(() => error = friendlyAuthError(e));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(UserModel admin) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Hapus Admin'),
        content: Text('Hapus akun admin "${admin.nama}" (@${admin.username})?'),
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
      await _svc.deleteUser(admin.authUid!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppTheme.bgColor,
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_admins.length} Admin',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh',
                  onPressed: _load,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tambah Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _admins.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.admin_panel_settings_outlined, size: 54, color: Colors.white24),
                            const SizedBox(height: 12),
                            const Text('Belum ada admin terdaftar', style: TextStyle(color: Colors.white54, fontSize: 15)),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _showAddDialog,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Tambah Admin Sekarang'),
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _admins.length,
                        itemBuilder: (ctx, i) {
                          final a = _admins[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                  child: const Icon(Icons.admin_panel_settings, color: Color(0xFF8B5CF6), size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      const SizedBox(height: 3),
                                      Text('@${a.username ?? '-'}',
                                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.white60, size: 19),
                                  tooltip: 'Edit Admin',
                                  onPressed: () => _showEditDialog(a),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 19),
                                  tooltip: 'Hapus Admin',
                                  onPressed: () => _confirmDelete(a),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
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

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  const _PasswordField({required this.controller, required this.label, required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.bgColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white54),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
