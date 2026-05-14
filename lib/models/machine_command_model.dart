class MachineCommandModel {
  final String machineId;
  final String status; // 'idle', 'waiting_tap', 'success', 'error'
  final double amount;
  final String? lastUid;

  MachineCommandModel({
    required this.machineId,
    required this.status,
    required this.amount,
    this.lastUid,
  });

  factory MachineCommandModel.fromMap(String id, Map<String, dynamic> data) {
    return MachineCommandModel(
      machineId: id,
      status: data['status'] ?? 'idle',
      amount: (data['amount'] ?? 0).toDouble(),
      lastUid: data['last_uid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'amount': amount,
      'last_uid': lastUid,
    };
  }
}
