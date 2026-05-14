/// Input validation utilities for NBPay
class Validators {
  // Username validation
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Username tidak boleh kosong';
    if (value.length < 3) return 'Username minimal 3 karakter';
    if (value.length > 20) return 'Username maksimal 20 karakter';
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
      return 'Username hanya huruf kecil, angka, underscore';
    }
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password tidak boleh kosong';
    if (value.length < 6) return 'Password minimal 6 karakter';
    if (value.length > 50) return 'Password terlalu panjang';
    return null;
  }

  // Nama validation
  static String? validateNama(String? value) {
    if (value == null || value.isEmpty) return 'Nama tidak boleh kosong';
    if (value.length < 2) return 'Nama minimal 2 karakter';
    if (value.length > 50) return 'Nama terlalu panjang';
    return null;
  }

  // NIS validation (8 digits)
  static String? validateNIS(String? value) {
    if (value == null || value.isEmpty) return 'NIS tidak boleh kosong';
    if (!RegExp(r'^\d{8}$').hasMatch(value)) return 'NIS harus 8 angka';
    return null;
  }

  // Amount validation
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) return 'Jumlah tidak boleh kosong';
    final amount = double.tryParse(value.replaceAll('.', ''));
    if (amount == null) return 'Jumlah harus angka valid';
    if (amount <= 0) return 'Jumlah harus lebih dari 0';
    if (amount > 10000000) return 'Jumlah maksimal Rp 10.000.000';
    return null;
  }

  // UID validation (HEX format, no spaces/dashes)
  static String? validateUID(String? value) {
    if (value == null || value.isEmpty) return 'UID tidak boleh kosong';
    if (value.length < 4) return 'UID terlalu pendek';
    if (value.length > 20) return 'UID terlalu panjang';
    if (!RegExp(r'^[A-F0-9]+$').hasMatch(value)) {
      return 'UID harus format HEX (A-F, 0-9), uppercase';
    }
    return null;
  }

  // Normalize UID (uppercase, remove spaces)
  static String normalizeUID(String uid) {
    return uid.trim().toUpperCase();
  }

  // Format currency
  static String formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
  }
}
