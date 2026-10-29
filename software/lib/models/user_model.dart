
class UserModel {
  final String? uidKartu;
  final String nama;
  final String role; // 'siswa' | 'admin' | 'penjual'
  final double saldo;
  final String nis;
  final String? username;
  final String? authUid;
  final bool isFrozen;

  UserModel({
    this.uidKartu,
    required this.nama,
    required this.role,
    required this.saldo,
    required this.nis,
    this.username,
    this.authUid,
    this.isFrozen = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uidKartu: data['uid_kartu'],
      nama: data['nama'] ?? '',
      role: data['role'] ?? 'siswa',
      saldo: (data['saldo'] ?? 0).toDouble(),
      nis: data['nis'] ?? '',
      username: data['username'],
      authUid: data['auth_uid'],
      isFrozen: data['is_frozen'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid_kartu': uidKartu,
      'nama': nama,
      'role': role,
      'saldo': saldo,
      'nis': nis,
      if (username != null) 'username': username,
      if (authUid != null) 'auth_uid': authUid,
      'is_frozen': isFrozen,
    };
  }
}
