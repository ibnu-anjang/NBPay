import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String? id;
  final String uidKartu;
  final double nominal;
  final String tipe; // 'debit' or 'credit'
  final DateTime timestamp;
  final String keterangan;

  TransactionModel({
    this.id,
    required this.uidKartu,
    required this.nominal,
    required this.tipe,
    required this.timestamp,
    required this.keterangan,
  });

  factory TransactionModel.fromMap(String id, Map<String, dynamic> data) {
    return TransactionModel(
      id: id,
      uidKartu: data['uid_kartu'] ?? '',
      nominal: (data['nominal'] ?? 0).toDouble(),
      tipe: data['tipe'] ?? 'debit',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      keterangan: data['keterangan'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid_kartu': uidKartu,
      'nominal': nominal,
      'tipe': tipe,
      'timestamp': Timestamp.fromDate(timestamp),
      'keterangan': keterangan,
    };
  }
}
