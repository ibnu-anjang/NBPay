import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/machine_command_model.dart';

class PaymentProvider extends ChangeNotifier {
  final FirebaseService _service = FirebaseService();

  String? currentMachineId;
  MachineCommandModel? machineState;
  bool isProcessing = false;
  StreamSubscription<MachineCommandModel>? _machineSub;

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  String? penjualUid;
  String? saleKeterangan;

  void setMachine(String id) {
    _machineSub?.cancel();
    currentMachineId = id;
    _machineSub = _service.streamMachine(id).listen((state) {
      machineState = state;

      if (state.status == 'waiting_tap' && state.lastUid != null && !isProcessing) {
        _handleIncomingTap(state.lastUid!, state.amount);
      }

      _safeNotify();
    });
  }

  @override
  void dispose() {
    _machineSub?.cancel();
    super.dispose();
  }

  Future<void> startPayment(double amount, {String? penjualAuthUid, String? keterangan}) async {
    if (currentMachineId == null) return;
    penjualUid = penjualAuthUid;
    saleKeterangan = keterangan;
    await _service.requestPayment(currentMachineId!, amount);
  }

  Future<void> _handleIncomingTap(String uid, double amount) async {
    isProcessing = true;
    _safeNotify();

    if (penjualUid != null) {
      await _service.processSale(
        buyerUidKartu: uid,
        machineId: currentMachineId!,
        totalAmount: amount,
        penjualAuthUid: penjualUid!,
        keterangan: saleKeterangan ?? 'Pembelian',
      );
    } else {
      await _service.processPayment(uid, amount, currentMachineId!);
    }

    isProcessing = false;
    _safeNotify();
  }

  Future<void> performTopUp(String uid, double amount) async {
    await _service.topUp(uid, amount);
  }

  Future<void> resetMachine() async {
    if (currentMachineId == null) return;
    await _service.resetMachine(currentMachineId!);
  }
}
