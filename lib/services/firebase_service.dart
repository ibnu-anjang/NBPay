import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/machine_command_model.dart';
import '../models/topup_request_model.dart';
import '../models/menu_item_model.dart';

/// Converts Firebase/generic errors to user-friendly Indonesian messages.
String friendlyAuthError(dynamic e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'email-already-in-use':
        return 'Username sudah digunakan. Pilih username lain.';
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'wrong-password':
        return 'Password salah.';
      case 'invalid-credential':
        return 'Username atau password salah.';
      case 'invalid-email':
        return 'Format username tidak valid.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Silakan coba lagi nanti.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet. Periksa jaringan Anda.';
      case 'requires-recent-login':
        return 'Sesi telah kedaluwarsa. Silakan login ulang.';
      default:
        return e.message ?? 'Terjadi kesalahan (${e.code}).';
    }
  }
  return e.toString().replaceFirst('Exception: ', '');
}

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Defers stream events to the next event-loop tick so they never fire
  // synchronously inside a Flutter Web frame callback, preventing
  // the window.dart / mouse_tracker.dart assertion errors.
  Stream<T> _async<T>(Stream<T> source) =>
      source.asyncMap((v) => Future.delayed(Duration.zero, () => v));

  // Username → synthetic email for Firebase Auth
  String _usernameToEmail(String username) => '$username@nbpay.internal';

  // Creates a Firebase Auth user WITHOUT signing the current admin out.
  // Uses a temporary secondary FirebaseApp so the primary auth session is untouched.
  static int _secondaryAppCounter = 0;

  Future<String> _createAuthUser(String email, String password) async {
    // Counter + hashCode gives collision-safe unique name even under concurrent calls.
    final name = 'nbpay_sec_${++_secondaryAppCounter}_${identityHashCode(this)}';
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: name,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!.uid;
    } finally {
      await secondaryApp?.delete();
    }
  }

  Future<void> loginWithUsername(String usernameOrEmail, String password) async {
    final email = usernameOrEmail.contains('@')
        ? usernameOrEmail
        : _usernameToEmail(usernameOrEmail);
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserModel> getUserByAuthUid(String authUid) async {
    final snap = await _db.collection('users').where('auth_uid', isEqualTo: authUid).limit(1).get();
    if (snap.docs.isEmpty) throw Exception('User not found');
    return UserModel.fromMap(snap.docs.first.data());
  }

  Future<List<UserModel>> getAllStudents() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'siswa').get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  Future<List<UserModel>> getAllPenjual() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'penjual').get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  Future<List<UserModel>> getAllAdmins() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'admin').get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  // Deletes the Firestore doc only. The Firebase Auth account persists (client SDK
  // cannot delete another user's Auth account — requires Admin SDK/Cloud Functions).
  // With Firestore security rules in place, the deleted user will get permission denied
  // on login and be shown the "akun tidak ditemukan" screen with a logout button.
  Future<void> deleteUser(String authUid) async {
    await _db.collection('users').doc(authUid).delete();
  }

  Future<void> registerPenjual({
    required String nama,
    required String username,
    required String password,
    String? uidKartu,
  }) async {
    final authUid = await _createAuthUser(_usernameToEmail(username), password);
    await _db.collection('users').doc(authUid).set({
      'nama': nama,
      'role': 'penjual',
      'username': username,
      'auth_uid': authUid,
      'saldo': 0,
      'nis': '',
      if (uidKartu != null && uidKartu.isNotEmpty) 'uid_kartu': uidKartu,
    });
  }

  Future<void> registerAdmin({
    required String nama,
    required String username,
    required String password,
  }) async {
    final authUid = await _createAuthUser(_usernameToEmail(username), password);
    await _db.collection('users').doc(authUid).set({
      'nama': nama,
      'role': 'admin',
      'username': username,
      'auth_uid': authUid,
      'saldo': 0,
      'nis': '',
    });
  }

  Future<void> registerStudentWithAuth({
    required String uidKartu,
    required String nama,
    required String nis,
    required String username,
    required String password,
  }) async {
    final authUid = await _createAuthUser(_usernameToEmail(username), password);
    await _db.collection('users').doc(uidKartu).set({
      'uid_kartu': uidKartu,
      'nama': nama,
      'role': 'siswa',
      'saldo': 0,
      'nis': nis,
      'username': username,
      'auth_uid': authUid,
    });
  }

  // Stream for Student Dashboard
  Stream<UserModel?> streamUser(String uidKartu) {
    return _async(_db.collection('users').doc(uidKartu).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return UserModel.fromMap(snap.data()!);
      }
      return null;
    }));
  }

  // Stream for Transactions — capped at 100 most recent to stay within Firestore free quota.
  Stream<List<TransactionModel>> streamTransactions(String uidKartu) {
    return _async(_db
        .collection('transactions')
        .where('uid_kartu', isEqualTo: uidKartu)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TransactionModel.fromMap(doc.id, doc.data()))
            .toList()));
  }

  // Stream for Machine Status (Admin side)
  Stream<MachineCommandModel> streamMachine(String machineId) {
    return _async(_db.collection('machine_commands').doc(machineId).snapshots().map(
        (snap) => MachineCommandModel.fromMap(snap.id, snap.data() ?? {})));
  }

  Future<void> resetMachine(String machineId) async {
    await _db.collection('machine_commands').doc(machineId).set({
      'status': 'idle',
      'amount': 0,
      'last_uid': FieldValue.delete(),
      'saldo_result': FieldValue.delete(),
      'nama_result': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // Action: Trigger Payment Request
  Future<void> requestPayment(String machineId, double amount) async {
    await _db.collection('machine_commands').doc(machineId).set({
      'status': 'waiting_tap',
      'amount': amount,
      'last_uid': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // Action: Process Transaction (This logic should ideally be a Cloud Function for security, 
  // but for the prototype we do it in-app as per TRD)
  Future<bool> processPayment(String uidKartu, double amount, String machineId) async {
    try {
      final userRef = _db.collection('users').doc(_normalizeUid(uidKartu));
      final machineRef = _db.collection('machine_commands').doc(machineId);

      return await _db.runTransaction((transaction) async {
        // Guard: cek status mesin dulu — kalau tab lain sudah proses, abort
        final machineSnap = await transaction.get(machineRef);
        final machineStatus = machineSnap.data()?['status'] as String?;
        if (machineStatus != 'waiting_tap') throw Exception('already_processed');

        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) throw Exception("User not found");

        final userData = userSnap.data()!;
        final currentSaldo = (userData['saldo'] ?? 0).toDouble();
        if (currentSaldo < amount) throw Exception("Saldo tidak cukup");

        transaction.update(userRef, {'saldo': currentSaldo - amount});

        final transRef = _db.collection('transactions').doc();
        transaction.set(transRef, {
          'uid_kartu': uidKartu,
          'nominal': amount,
          'tipe': 'debit',
          'timestamp': FieldValue.serverTimestamp(),
          'keterangan': 'Pembayaran Kantin',
        });

        transaction.set(machineRef, {'status': 'success'}, SetOptions(merge: true));

        return true;
      });
    } catch (e) {
      if (e.toString().contains('already_processed')) return false;
      debugPrint("Transaction Error: $e");
      await _db.collection('machine_commands').doc(machineId).set({
        'status': 'error',
      }, SetOptions(merge: true));
      return false;
    }
  }

  Future<void> logout() => _auth.signOut();

  // --- Machine Management ---
  Future<List<Map<String, dynamic>>> getAllMachines() async {
    final snap = await _db.collection('machine_commands').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Stream<List<Map<String, dynamic>>> streamAllMachines() {
    return _async(_db.collection('machine_commands').snapshots().map(
      (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    ));
  }

  Future<void> addMachine(String machineId, String nama) async {
    await _db.collection('machine_commands').doc(machineId).set({
      'nama': nama,
      'status': 'idle',
      'amount': 0,
    }, SetOptions(merge: false));
  }

  Future<void> deleteMachine(String machineId) async {
    await _db.collection('machine_commands').doc(machineId).delete();
  }

  Future<void> updateMachineTujuan(String machineId, String tujuan) async {
    await _db.collection('machine_commands').doc(machineId).set(
      {'tujuan': tujuan},
      SetOptions(merge: true),
    );
  }

  Future<void> updateUser(String docId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(docId).update(data);
  }

  /// Update uid_kartu for penjual (stored by authUid doc).
  Future<void> updatePenjualCard(String authUid, String uidKartu) async {
    await _db.collection('users').doc(authUid).update({'uid_kartu': uidKartu});
  }

  /// Admin manually sets a user's saldo.
  Future<void> setSaldo(String docId, double saldo) async {
    final ref = _db.collection('users').doc(docId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('User not found');
      final previousSaldo = (snap.data()!['saldo'] ?? 0).toDouble();
      tx.update(ref, {'saldo': saldo});
      final transRef = _db.collection('transactions').doc();
      tx.set(transRef, {
        'uid_kartu': docId,
        'nominal': saldo - previousSaldo, // delta: positive=credit, negative=debit
        'saldo_sebelum': previousSaldo,
        'saldo_sesudah': saldo,
        'tipe': 'set_saldo',
        'timestamp': FieldValue.serverTimestamp(),
        'keterangan': 'Set saldo oleh admin',
      });
    });
  }

  // Quick amounts — admin topup, stored in Firestore
  Stream<List<int>> streamQuickAmounts() {
    return _async(_db.collection('settings').doc('quick_amounts').snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return [10000, 20000, 50000, 100000];
      final list = (data['amounts'] as List?)?.map((e) => (e as num).toInt()).toList();
      return list ?? [10000, 20000, 50000, 100000];
    }));
  }

  Future<void> saveQuickAmounts(List<int> amounts) async {
    await _db.collection('settings').doc('quick_amounts').set({'amounts': amounts});
  }

  // Quick amounts — penjual/kasir, stored in separate Firestore doc
  Stream<List<int>> streamQuickAmountsPenjual() {
    return _async(_db.collection('settings').doc('quick_amounts_penjual').snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return [2000, 3000, 5000, 10000, 15000, 20000];
      final list = (data['amounts'] as List?)?.map((e) => (e as num).toInt()).toList();
      return list ?? [2000, 3000, 5000, 10000, 15000, 20000];
    }));
  }

  Future<void> saveQuickAmountsPenjual(List<int> amounts) async {
    await _db.collection('settings').doc('quick_amounts_penjual').set({'amounts': amounts});
  }

  // --- Menu Management (per penjual) ---
  Stream<List<MenuItemModel>> streamMenus(String penjualUid) {
    return _async(_db
        .collection('menus')
        .where('penjual_uid', isEqualTo: penjualUid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => MenuItemModel.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => a.nama.compareTo(b.nama));
          return list;
        }));
  }

  Future<void> addMenu(MenuItemModel item) async {
    await _db.collection('menus').add(item.toMap());
  }

  Future<void> updateMenu(String menuId, String nama, double harga) async {
    await _db.collection('menus').doc(menuId).update({'nama': nama, 'harga': harga});
  }

  Future<void> deleteMenu(String menuId) async {
    await _db.collection('menus').doc(menuId).delete();
  }

  /// Process sale: deduct buyer saldo, credit penjual saldo, log transactions.
  Future<bool> processSale({
    required String buyerUidKartu,
    required String machineId,
    required double totalAmount,
    required String penjualAuthUid,
    required String keterangan,
  }) async {
    try {
      final buyerRef = _db.collection('users').doc(_normalizeUid(buyerUidKartu));
      final penjualRef = _db.collection('users').doc(penjualAuthUid);

      final machineRef = _db.collection('machine_commands').doc(machineId);

      return await _db.runTransaction((tx) async {
        // Guard: kalau tab lain sudah proses, abort
        final machineSnap = await tx.get(machineRef);
        final machineStatus = machineSnap.data()?['status'] as String?;
        if (machineStatus != 'waiting_tap') throw Exception('already_processed');

        final buyerSnap = await tx.get(buyerRef);
        final penjualSnap = await tx.get(penjualRef);

        if (!buyerSnap.exists) throw Exception('Pembeli tidak ditemukan');
        if (!penjualSnap.exists) throw Exception('Penjual tidak ditemukan');

        final buyerSaldo = (buyerSnap.data()!['saldo'] ?? 0).toDouble();
        if (buyerSaldo < totalAmount) throw Exception('Saldo tidak cukup');

        final penjualSaldo = (penjualSnap.data()!['saldo'] ?? 0).toDouble();

        tx.update(buyerRef, {'saldo': buyerSaldo - totalAmount});
        tx.update(penjualRef, {'saldo': penjualSaldo + totalAmount});

        final buyerTxRef = _db.collection('transactions').doc();
        tx.set(buyerTxRef, {
          'uid_kartu': buyerUidKartu,
          'nominal': totalAmount,
          'tipe': 'debit',
          'timestamp': FieldValue.serverTimestamp(),
          'keterangan': keterangan,
          'penjual_uid': penjualAuthUid,
        });

        final penjualTxRef = _db.collection('transactions').doc();
        tx.set(penjualTxRef, {
          'uid_kartu': penjualAuthUid,
          'nominal': totalAmount,
          'tipe': 'credit',
          'timestamp': FieldValue.serverTimestamp(),
          'keterangan': 'Penjualan: $keterangan',
          'buyer_uid': buyerUidKartu,
        });

        tx.set(machineRef, {'status': 'success'}, SetOptions(merge: true));

        return true;
      });
    } catch (e) {
      if (e.toString().contains('already_processed')) return false;
      await _db.collection('machine_commands').doc(machineId).set({
        'status': 'error',
      }, SetOptions(merge: true));
      return false;
    }
  }

  Stream<List<TransactionModel>> streamWithdrawalTransactions() {
    return _async(_db
        .collection('transactions')
        .where('tipe', isEqualTo: 'withdrawal')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TransactionModel.fromMap(d.id, d.data()))
            .toList()));
  }

  Stream<List<TransactionModel>> streamPenjualWithdrawals(String penjualAuthUid) {
    return _async(_db
        .collection('transactions')
        .where('uid_kartu', isEqualTo: penjualAuthUid)
        .where('tipe', isEqualTo: 'withdrawal')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TransactionModel.fromMap(d.id, d.data()))
            .toList()));
  }

  Stream<List<TransactionModel>> streamPenjualTransactions(String penjualAuthUid) {
    return _async(_db
        .collection('transactions')
        .where('uid_kartu', isEqualTo: penjualAuthUid)
        .where('tipe', isEqualTo: 'credit')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TransactionModel.fromMap(d.id, d.data()))
            .toList()));
  }

  /// Withdraw penjual saldo (admin taps penjual card, moves saldo to 0 or chosen amount).
  Future<void> withdrawPenjual({
    required String penjualAuthUid,
    required double amount,
  }) async {
    final ref = _db.collection('users').doc(penjualAuthUid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Penjual tidak ditemukan');
      final current = (snap.data()!['saldo'] ?? 0).toDouble();
      if (current < amount) throw Exception('Saldo penjual tidak mencukupi');
      tx.update(ref, {'saldo': current - amount});
      final txRef = _db.collection('transactions').doc();
      tx.set(txRef, {
        'uid_kartu': penjualAuthUid,
        'nominal': amount,
        'tipe': 'withdrawal',
        'timestamp': FieldValue.serverTimestamp(),
        'keterangan': 'Penarikan tunai oleh admin',
      });
    });
  }

  // Normalize UID from hardware: trim whitespace, force UPPERCASE.
  // This is a safety net — hardware should already send uppercase per HARDWARE_DOCS,
  // but a mismatch here causes a silent "kartu tidak dikenal" which is hard to debug.
  static String _normalizeUid(String uid) => uid.trim().toUpperCase();

  // Stream UID kartu dari mesin (untuk scan kartu saat daftar/topup)
  Stream<String?> streamLastUid(String machineId) {
    return _async(_db.collection('machine_commands').doc(machineId).snapshots().map(
      (snap) {
        final raw = snap.data()?['last_uid'] as String?;
        return raw != null ? _normalizeUid(raw) : null;
      },
    ));
  }

  Future<void> setMachineWaitingUid(String machineId) async {
    await _db.collection('machine_commands').doc(machineId).set({
      'status': 'waiting_uid',
      'last_uid': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // Cek Saldo: lookup user by uid_kartu, write saldo_result + nama_result back to machine
  Future<void> processCekSaldo(String machineId, String uidKartu) async {
    try {
      final uid = _normalizeUid(uidKartu);
      final userRef = _db.collection('users').doc(uid);
      final machineRef = _db.collection('machine_commands').doc(machineId);

      await _db.runTransaction((tx) async {
        // Guard: cek status sebelum proses — hindari concurrent taps
        final machineSnap = await tx.get(machineRef);
        final machineStatus = machineSnap.data()?['status'] as String?;
        if (machineStatus != 'waiting_check') throw Exception('already_processed');

        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) throw Exception('Kartu tidak dikenal');

        final userData = userSnap.data()!;
        tx.set(machineRef, {
          'status': 'showing_saldo',
          'saldo_result': (userData['saldo'] ?? 0).toDouble(),
          'nama_result': userData['nama'] ?? 'Siswa',
          'last_uid': FieldValue.delete(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      if (e.toString().contains('already_processed')) return;
      debugPrint("Cek Saldo Error: $e");
      try {
        await _db.collection('machine_commands').doc(machineId).set({
          'status': 'error',
          'nama_result': 'Kartu tidak dikenal',
          'last_uid': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (e2) {
        debugPrint("Error writing error status: $e2");
      }
    }
  }

  // Machine heartbeat: hardware writes this every ~30s; admin UI uses it to detect offline
  Future<void> updateMachineHeartbeat(String machineId) async {
    await _db.collection('machine_commands').doc(machineId).set({
      'last_heartbeat': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Payment info (QRIS / rekening) — disimpan di Firestore agar admin bisa edit
  Stream<Map<String, String>> streamPaymentInfo() {
    return _async(_db.collection('settings').doc('payment_info').snapshots().map((snap) {
      final d = snap.data() ?? {};
      return {
        'bank_name': d['bank_name'] ?? '',
        'account_number': d['account_number'] ?? '',
        'account_name': d['account_name'] ?? '',
        'qris_image_url': d['qris_image_url'] ?? '',
      };
    }));
  }

  Future<void> savePaymentInfo({
    required String bankName,
    required String accountNumber,
    required String accountName,
    required String qrisImageUrl,
  }) async {
    await _db.collection('settings').doc('payment_info').set({
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'qris_image_url': qrisImageUrl,
    }, SetOptions(merge: true));
  }

  // Top-up Requests (buyer self-service)
  Future<void> submitTopUpRequest({
    required String uidKartu,
    required String namaSiswa,
    required double amount,
    required String method,
    String? catatan,
  }) async {
    // Prevent accumulation: block if the student already has a pending request.
    final existing = await _db
        .collection('topup_requests')
        .where('uid_kartu', isEqualTo: uidKartu)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception(
          'Kamu masih memiliki request yang belum diproses. Tunggu hingga disetujui atau ditolak sebelum mengajukan request baru.');
    }
    await _db.collection('topup_requests').add({
      'uid_kartu': uidKartu,
      'nama_siswa': namaSiswa,
      'amount': amount,
      'method': method,
      'status': 'pending',
      'catatan': catatan,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<TopUpRequestModel>> streamPendingRequests() {
    return _async(_db
        .collection('topup_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => TopUpRequestModel.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        }));
  }

  Stream<List<TopUpRequestModel>> streamMyTopUpRequests(String uidKartu) {
    return _async(_db
        .collection('topup_requests')
        .where('uid_kartu', isEqualTo: uidKartu)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => TopUpRequestModel.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        }));
  }

  Future<List<TopUpRequestModel>> getPendingRequests() async {
    final snap = await _db
        .collection('topup_requests')
        .where('status', isEqualTo: 'pending')
        .get();
    final list = snap.docs.map((d) => TopUpRequestModel.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> approveTopUpRequest(TopUpRequestModel req) async {
    final reqRef = _db.collection('topup_requests').doc(req.id);
    final userRef = _db.collection('users').doc(req.uidKartu);
    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      if (reqSnap.data()?['status'] != 'pending') throw Exception('already_processed');
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('User not found');
      final currentSaldo = (userSnap.data()!['saldo'] ?? 0).toDouble();
      tx.update(userRef, {'saldo': currentSaldo + req.amount});
      final transRef = _db.collection('transactions').doc();
      tx.set(transRef, {
        'uid_kartu': req.uidKartu,
        'nominal': req.amount,
        'tipe': 'credit',
        'timestamp': FieldValue.serverTimestamp(),
        'keterangan': 'Top-up Saldo',
      });
      tx.update(reqRef, {'status': 'approved'});
    });
  }

  Future<void> rejectTopUpRequest(String requestId) async {
    await _db.collection('topup_requests').doc(requestId).update({'status': 'rejected'});
  }

  /// Marks pending requests older than [maxAge] as 'expired'. Call on admin screen init.
  Future<void> expireStaleRequests({Duration maxAge = const Duration(hours: 24)}) async {
    final cutoff = DateTime.now().subtract(maxAge);
    final snap = await _db
        .collection('topup_requests')
        .where('status', isEqualTo: 'pending')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'status': 'expired'});
    }
    if (snap.docs.isNotEmpty) await batch.commit();
  }

  // Action: Top-up
  Future<void> topUp(String uidKartu, double amount) async {
    final userRef = _db.collection('users').doc(uidKartu);
    await _db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) throw Exception("User not found");

      final currentSaldo = (userSnap.data()!['saldo'] ?? 0).toDouble();
      transaction.update(userRef, {'saldo': currentSaldo + amount});

      final transRef = _db.collection('transactions').doc();
      transaction.set(transRef, {
        'uid_kartu': uidKartu,
        'nominal': amount,
        'tipe': 'credit',
        'timestamp': FieldValue.serverTimestamp(),
        'keterangan': 'Top-up Saldo',
      });
    });
  }

  // Action: Process Topup/Daftar Card (tujuan='topup_daftar' mode)
  // Hardware scan kartu → app verify user exists + record UID for admin topup/daftar flow
  Future<void> processTopupDaftarCard(String uid, String machineId) async {
    try {
      final userRef = _db.collection('users').doc(_normalizeUid(uid));
      final machineRef = _db.collection('machine_commands').doc(machineId);

      await _db.runTransaction((tx) async {
        // Guard: prevent double-processing
        final machineSnap = await tx.get(machineRef);
        final machineStatus = machineSnap.data()?['status'] as String?;
        if (machineStatus != 'waiting_uid') throw Exception('already_processed');

        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) throw Exception('Kartu_tidak_terdaftar');

        // Success: UID recorded, admin app will proceed with topup/registration
        tx.set(machineRef, {
          'status': 'success',
          'last_uid': FieldValue.delete(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      if (e.toString().contains('already_processed')) return;
      debugPrint("Topup Daftar Error: $e");
      try {
        final errorMsg = e.toString().contains('tidak_terdaftar')
            ? 'Kartu tidak terdaftar di sistem'
            : 'Error memproses kartu';
        await _db.collection('machine_commands').doc(machineId).set({
          'status': 'error',
          'nama_result': errorMsg,
          'last_uid': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (e2) {
        debugPrint("Error writing error status: $e2");
      }
    }
  }
}
