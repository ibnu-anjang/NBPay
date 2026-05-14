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

      // Route to appropriate handler based on tujuan (mode) and status
      final tujuan = state.tujuan ?? 'kasir';

      if (state.status == 'waiting_tap' && state.lastUid != null && !isProcessing && tujuan == 'kasir') {
        _handleIncomingTapKasir(state.lastUid!, state.amount);
      } else if (state.status == 'waiting_check' && state.lastUid != null && !isProcessing && tujuan == 'cek_saldo') {
        _handleCekSaldo(state.lastUid!);
      } else if (state.status == 'waiting_uid' && state.lastUid != null && !isProcessing && tujuan == 'topup_daftar') {
        _handleTopupDaftar(state.lastUid!);
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

  Future<void> _handleIncomingTapKasir(String uid, double amount) async {
    isProcessing = true;
    _safeNotify();

    try {
      final payment = penjualUid != null
          ? _service.processSale(
              buyerUidKartu: uid,
              machineId: currentMachineId!,
              totalAmount: amount,
              penjualAuthUid: penjualUid!,
              keterangan: saleKeterangan ?? 'Pembelian',
            )
          : _service.processPayment(uid, amount, currentMachineId!);

      await payment.timeout(
        const Duration(seconds: 15),
        onTimeout: () async {
          debugPrint("Kasir payment timeout — resetting machine");
          await _service.resetMachine(currentMachineId!);
          return false;
        },
      );
    } catch (e) {
      debugPrint("Kasir handler error: $e");
    } finally {
      isProcessing = false;
      _safeNotify();
    }
  }

  Future<void> _handleCekSaldo(String uid) async {
    isProcessing = true;
    _safeNotify();

    try {
      // Wait for cek saldo with 10 second timeout (hardware default)
      await _service.processCekSaldo(currentMachineId!, uid).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          debugPrint("Cek Saldo timeout — hardware did not respond");
          await _service.resetMachine(currentMachineId!);
        },
      );
    } catch (e) {
      debugPrint("Cek Saldo handler error: $e");
    } finally {
      isProcessing = false;
      _safeNotify();
    }
  }

  Future<void> _handleTopupDaftar(String uid) async {
    isProcessing = true;
    _safeNotify();

    try {
      await _service.processTopupDaftarCard(uid, currentMachineId!).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          debugPrint("Topup/Daftar timeout — resetting machine");
          await _service.resetMachine(currentMachineId!);
        },
      );
    } catch (e) {
      debugPrint("Topup/Daftar handler error: $e");
    } finally {
      isProcessing = false;
      _safeNotify();
    }
  }

  Future<void> performTopUp(String uid, double amount) async {
    await _service.topUp(uid, amount);
  }

  Future<void> resetMachine() async {
    if (currentMachineId == null) return;
    await _service.resetMachine(currentMachineId!);
  }
}
