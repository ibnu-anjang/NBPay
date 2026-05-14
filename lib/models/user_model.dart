
class UserModel {
  final String? uidKartu;
  final String nama;
  final String role; // 'siswa' or 'admin'
  final double saldo;
  final String nis;
  final String? username;
  final String? authUid;

  UserModel({
    this.uidKartu,
    required this.nama,
    required this.role,
    required this.saldo,
    required this.nis,
    this.username,
    this.authUid,
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
    };
  }
}
