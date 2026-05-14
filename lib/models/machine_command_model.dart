import 'package:cloud_firestore/cloud_firestore.dart';

class MachineCommandModel {
  final String machineId;
  final String status; // 'idle', 'waiting_tap', 'waiting_check', 'waiting_uid', 'showing_saldo', 'success', 'error'
  final String? tujuan; // 'kasir', 'cek_saldo', 'topup_daftar'
  final double amount;
  final String? lastUid;
  final double? saldoResult;
  final String? namaResult;
  final Timestamp? lastHeartbeat;

  MachineCommandModel({
    required this.machineId,
    required this.status,
    this.tujuan,
    required this.amount,
    this.lastUid,
    this.saldoResult,
    this.namaResult,
    this.lastHeartbeat,
  });

  factory MachineCommandModel.fromMap(String id, Map<String, dynamic> data) {
    return MachineCommandModel(
      machineId: id,
      status: data['status'] ?? 'idle',
      tujuan: data['tujuan'],
      amount: (data['amount'] ?? 0).toDouble(),
      lastUid: data['last_uid'],
      saldoResult: data['saldo_result'] != null ? (data['saldo_result'] as num).toDouble() : null,
      namaResult: data['nama_result'],
      lastHeartbeat: data['last_heartbeat'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'tujuan': tujuan,
      'amount': amount,
      'last_uid': lastUid,
      'saldo_result': saldoResult,
      'nama_result': namaResult,
      'last_heartbeat': lastHeartbeat,
    };
  }

  /// Check if machine is online (heartbeat received within last 60 seconds)
  bool get isOnline {
    if (lastHeartbeat == null) return false;
    final now = DateTime.now();
    final hbTime = lastHeartbeat!.toDate();
    return now.difference(hbTime).inSeconds < 60;
  }
}
