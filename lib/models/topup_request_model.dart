import 'package:cloud_firestore/cloud_firestore.dart';

class TopUpRequestModel {
  final String id;
  final String uidKartu;
  final String namaSiswa;
  final double amount;
  final String method; // 'qris' | 'transfer' | 'cash'
  final String status;  // 'pending' | 'approved' | 'rejected'
  final DateTime timestamp;
  final String? catatan;

  const TopUpRequestModel({
    required this.id,
    required this.uidKartu,
    required this.namaSiswa,
    required this.amount,
    required this.method,
    required this.status,
    required this.timestamp,
    this.catatan,
  });

  factory TopUpRequestModel.fromMap(String id, Map<String, dynamic> d) {
    return TopUpRequestModel(
      id: id,
      uidKartu: d['uid_kartu'] ?? '',
      namaSiswa: d['nama_siswa'] ?? '',
      amount: (d['amount'] ?? 0).toDouble(),
      method: d['method'] ?? 'transfer',
      status: d['status'] ?? 'pending',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      catatan: d['catatan'],
    );
  }
}
