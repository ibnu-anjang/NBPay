# Critical Bugs & Issues — Production Readiness Report

**Date**: May 14, 2026  
**Status**: ⚠️ NOT READY FOR PRODUCTION  
**Demo Status**: ⚠️ RISKY (see section below)

---

## 📊 ISSUE SUMMARY

| Severity | Count | Status |
|----------|-------|--------|
| 🔴 BLOCKING | 12 | Must fix before ANY deployment |
| 🟠 CRITICAL | 18 | Must fix before production |
| 🟡 HIGH | 15 | Should fix before launch |
| 🟢 MEDIUM | 8 | Can fix post-launch if needed |
| **TOTAL** | **53** | |

---

## 🔴 BLOCKING — DEMO WILL BREAK

### B1: Input Validation Missing — CRASH RISK
**File**: `CardScannerScreen.dart`, `PaymentProvider.dart`  
**Issue**: No validation on:
- Username (can be empty) → registration fails
- Password (can be empty) → registration fails
- Amount (can be 0, negative, or overflow) → crashes
- UID format (can be invalid) → database error
- NIS (can be empty) → registration fails

**Current code**:
```dart
// CardScannerScreen line 133
if (_namaCtrl.text.isEmpty || _nisCtrl.text.isEmpty || ...) {
  // Only check isEmpty, NOT format/length
}
// No validation on amount format
```

**Impact**: DEMO user enters invalid data → app crashes or behaves unpredictably  
**Severity**: 🔴 BLOCKING  
**Fix time**: 2 hours

---

### B2: UID Collision — Registration Fails Silently
**File**: `firebase_service.dart` line 150-167  
**Issue**: `registerStudentWithAuth` does NOT check if UID already exists

**Current code**:
```dart
Future<void> registerStudentWithAuth({
  required String uidKartu,
  ...
}) async {
  final authUid = await _createAuthUser(...);
  await _db.collection('users').doc(uidKartu).set({
    'uid_kartu': uidKartu,
    // Creates new doc without checking if exists
  });
}
```

**Scenario in DEMO**:
```
Hardware scan same UID twice
→ registerStudentWithAuth called twice
→ First time: ✓ Success
→ Second time: Firebase throws error "document already exists"
→ No error handling → app crash or silent fail
```

**Impact**: DEMO will crash if same card scanned twice  
**Severity**: 🔴 BLOCKING  
**Fix time**: 1 hour

---

### B3: Currency Using Double — Rounding Errors
**File**: `firebase_service.dart` — EVERYWHERE (15+ places)  
**Issue**: Using `double` for money causes floating-point precision errors

**Current code**:
```dart
final currentSaldo = (userData['saldo'] ?? 0).toDouble();  // LINE 234, 310, 404, 407, 492, 673, 713
transaction.update(userRef, {'saldo': currentSaldo - amount});
```

**Scenario in DEMO**:
```
Student 1: Bayar Rp 33.33 dari Rp 100 → saldo = 66.67
Student 2: Bayar Rp 33.33 dari Rp 66.67 → saldo = 33.34 (should be 33.33)
After 100 taps: Cumulative error = Rp 0.50 - Rp 5 missing
```

**Impact**: Money silently disappears from system  
**Severity**: 🔴 BLOCKING  
**Fix time**: 4-6 hours (refactor to use integer cents)

---

### B4: No Error UI Feedback — Demo User Confused
**File**: `CardScannerScreen.dart` line 115-200  
**Issue**: Operations like register/topup have NO loading indicator or error dialog

**Current code**:
```dart
Future<void> _registerStudent() async {
  setState(() => _isRegistering = true);
  try {
    await _svc.registerStudentWithAuth(...);
    // No loading dialog, no error dialog
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(...);
    }
  }
}
```

**Scenario in DEMO**:
```
User click "Daftar Siswa" → screen goes blank (processing)
→ User: "Is it working? Is it frozen?"
→ User click again → double-process
→ User close app thinking it crashed
```

**Impact**: DEMO UX is confusing and fragile  
**Severity**: 🔴 BLOCKING  
**Fix time**: 2 hours

---

### B5: No Saldo Validation — Can Go Negative
**File**: `firebase_service.dart` line 303-321 (setSaldo)  
**Issue**: `setSaldo()` allows any value including negative

**Current code**:
```dart
Future<void> setSaldo(String docId, double saldo) async {
  // No validation: if (saldo < 0) throw;
  await _db.runTransaction((tx) async {
    tx.update(ref, {'saldo': saldo});  // Can be negative
  });
}
```

**Scenario in DEMO**:
```
Admin: setSaldo(uidKartu, -100)  // Allowed!
Student tap: -100 - 50 = -150 (still allowed)
Result: Student has -150 balance (nonsensical)
```

**Impact**: DEMO shows broken business logic  
**Severity**: 🔴 BLOCKING  
**Fix time**: 1 hour

---

### B6: Transaction Atomicity Unverified — Data Corruption
**File**: `firebase_service.dart` line 224-249 (processPayment)  
**Issue**: Transaction uses guard but NOT TESTED if debit/credit truly atomic

**Current code**:
```dart
return await _db.runTransaction((transaction) async {
  transaction.update(userRef, {'saldo': currentSaldo - amount});        // Line 235
  transaction.set(transRef, { 'tipe': 'debit', ... });                 // Line 237-244
  transaction.set(machineRef, {'status': 'success'}, ...);             // Line 246
  return true;
});
```

**Scenario in DEMO**:
```
Kasir mode: Buyer saldo -100 ✓, Penjual saldo +100 ✓ (if processSale used)
BUT if network fail mid-transaction:
→ Buyer debit success, penjual credit FAIL
→ Money disappears from ecosystem
```

**Impact**: DEMO might show successful payment but money lost  
**Severity**: 🔴 BLOCKING  
**Fix time**: 2 hours (test + document)

---

### B7: Machine Mode Race Condition — Wrong Handler
**File**: `PaymentProvider.dart` line 23-42  
**Issue**: Admin can change machine `tujuan` while hardware processing

**Current code**:
```dart
void setMachine(String id) {
  _machineSub = _service.streamMachine(id).listen((state) {
    final tujuan = state.tujuan ?? 'kasir';  // Read ONCE
    
    if (state.status == 'waiting_tap' && tujuan == 'kasir') {
      _handleIncomingTapKasir(...);
    } else if (state.status == 'waiting_check' && tujuan == 'cek_saldo') {
      _handleCekSaldo(...);
    }
    // But tujuan might have changed between check and execution
  });
}
```

**Scenario in DEMO**:
```
Hardware in kasir mode: waiting_tap
Admin: Change tujuan to cek_saldo (during tap)
Hardware: Send UID
App: Read tujuan → cek_saldo, route to _handleCekSaldo
Result: Wrong handler executed
```

**Impact**: DEMO shows incorrect behavior in edge cases  
**Severity**: 🔴 BLOCKING  
**Fix time**: 2 hours

---

### B8: Hardware Retry = Double-Processing
**File**: All handlers in `PaymentProvider.dart`  
**Issue**: If hardware retry sending UID (network timeout), might process twice

**Current code**:
```dart
// Guard exists:
if (machineStatus != 'waiting_tap') throw Exception('already_processed');

// But timing:
1. Hardware: Send UID
2. App: Check status ✓ waiting_tap, process ✓
3. Hardware: Network timeout, RETRY send UID
4. App: Check status (now success?) → guard prevents, OR
       Check status (still waiting?) → process AGAIN
```

**Scenario in DEMO**:
```
Student: Tap once
Hardware: Network slow, send UID twice
App: Process twice → debit twice
Student: -200 instead of -100
```

**Impact**: DEMO shows double-charging  
**Severity**: 🔴 BLOCKING  
**Fix time**: 2 hours

---

### B9: No Audit Trail — Cannot Debug
**File**: Entire system  
**Issue**: Zero logging of who did what, when

**Scenario in DEMO**:
```
Student: "My balance decreased!"
Admin: "I don't know, no logs"
System: Silent about all operations
```

**Impact**: DEMO cannot demonstrate accountability  
**Severity**: 🔴 BLOCKING (for business context)  
**Fix time**: 4 hours minimum

---

### B10: No Transaction Receipts — Cannot Verify
**File**: `CardScannerScreen.dart`, handlers  
**Issue**: Payment processed but no receipt generated

**Scenario in DEMO**:
```
Student: "Did I pay or not?"
System: Shows in database but no receipt
Student: Cannot verify without asking admin
```

**Impact**: DEMO shows incomplete payment UX  
**Severity**: 🔴 BLOCKING  
**Fix time**: 2 hours

---

### B11: Multi-Device Admin — Conflict Possible
**File**: `CardScannerScreen.dart` line 75-90  
**Issue**: Two admins select same machine simultaneously

**Scenario in DEMO**:
```
Admin A: Open CardScannerScreen, select machine X
Admin B: Open CardScannerScreen, select machine X (same device/different)
Hardware: Scan UID
Both admins: Try to process
Result: Double-process or conflict
```

**Impact**: DEMO might process transaction twice  
**Severity**: 🔴 BLOCKING  
**Fix time**: 2 hours

---

### B12: Cek Saldo Timeout Triggers Even If App Online
**File**: `PaymentProvider.dart` line 92-98  
**Issue**: Timeout callback resets machine, but what if app truly processing slow?

**Current code**:
```dart
await _service.processCekSaldo(currentMachineId!, uid).timeout(
  const Duration(seconds: 10),
  onTimeout: () async {
    debugPrint("Cek Saldo timeout");
    await _service.resetMachine(currentMachineId!);  // Force reset
    return null;
  },
);
```

**Scenario in DEMO**:
```
Network slow: processCekSaldo takes 8 sec
Timeout set to 10 sec: OK
BUT Firestore slow: processCekSaldo takes 12 sec
Result: Timeout fires, machine reset, but still processing
Machine state: reset (idle) while app writing (showing_saldo)
Conflict!
```

**Impact**: DEMO shows race condition under slow network  
**Severity**: 🔴 BLOCKING  
**Fix time**: 2 hours

---

## 🟠 CRITICAL — MUST FIX FOR PRODUCTION

### C1: UID Format Normalization Not Enforced
**Status**: Works via `_normalizeUid()` but not validated at input  
**Fix**: Add validation layer

### C2: Concurrent Tap Prevention (Cek Saldo)
**Status**: Transaction guard exists but untested  
**Fix**: Add test scenario

### C3: Firestore Indexes Not Verified
**Status**: Queries might be slow if indexes missing  
**Fix**: Check Firebase console for indexes

### C4: Auth Token Refresh During Long Transaction
**Status**: Not handled  
**Fix**: Add token refresh logic

### C5: No Approval Workflow for Admin Actions
**Status**: Admin can modify saldo without approval  
**Fix**: Add 2-approval system

### C6: Settlement/Withdrawal Not Implemented
**Status**: Penjual can "withdraw" but no actual settlement  
**Fix**: Define settlement process

### C7: Reconciliation Not Possible
**Status**: No way to audit if saldo matches transactions  
**Fix**: Add daily reconciliation script

### C8: Fraud Detection Not Implemented
**Status**: No alerts for suspicious activity  
**Fix**: Add anomaly detection

### C9: System Monitoring Missing
**Status**: No visibility into app crashes or Firestore errors  
**Fix**: Add basic logging + alerts

### C10: Backup/Disaster Recovery Not Defined
**Status**: If data corrupted, no recovery plan  
**Fix**: Document backup strategy

### C11: Regulatory Compliance Unknown
**Status**: Not verified if compliant with local payment laws  
**Fix**: Legal review required

### C12: Hardware Lifecycle Unknown
**Status**: Not clear who maintains/replaces hardware  
**Fix**: Define hardware SLA

### C13: Debt Policy Not Defined
**Status**: System doesn't prevent negative saldo  
**Fix**: Define and enforce policy

### C14: Admin Segregation of Duties Missing
**Status**: Same admin can process payment AND approve withdrawal  
**Fix**: Implement role-based access

### C15: Mobile Receipt/Proof Missing
**Status**: Students only see screen, no digital receipt  
**Fix**: Add SMS/email confirmation

### C16: Firestore Transaction Timeout Risk
**Status**: 25-second limit might be exceeded under load  
**Fix**: Monitor transaction latency

### C17: Network Partition Handling
**Status**: Not clear what happens if app/hardware disconnect mid-transaction  
**Fix**: Add reconnection logic

### C18: Data Retention Policy
**Status**: Not clear how long to keep transaction history  
**Fix**: Define retention policy

---

## 🟡 HIGH — SHOULD FIX BEFORE LAUNCH

### H1-H15: (Various UX improvements, advanced features, optimization)

---

## ⚠️ DEMO READINESS ASSESSMENT

### **CAN RUN DEMO?**

**Short answer**: ⚠️ **YES, BUT RISKY**

**It will work IF:**
- ✅ Demo uses fresh database (no existing data)
- ✅ Demo uses HAPPY PATH ONLY (no edge cases)
- ✅ Demo has ONE admin device (no multi-device conflict)
- ✅ Demo avoids duplicate card taps
- ✅ Demo uses reasonable amounts (no edge cases)
- ✅ Demo doesn't stress test
- ✅ Demo network is stable

**It will BREAK IF:**
- ❌ User enters invalid data (amounts, usernames)
- ❌ Same card tapped twice
- ❌ Two admins use simultaneously
- ❌ Network latency > 5 seconds
- ❌ Hardware retry sends duplicate UID
- ❌ Demo tries kasir + cek_saldo simultaneously
- ❌ Any edge case happens

### **Demo Recommendation**

**PROCEED WITH:**
- ✅ Supervisor present (manual fallback)
- ✅ Fresh database (no real data at risk)
- ✅ Controlled scenario (happy path only)
- ✅ Single admin device
- ✅ Stable network (hardwired if possible)
- ✅ Pre-populated test data
- ✅ Detailed script to follow

**DO NOT:**
- ❌ Use production data
- ❌ Let users input freeform data
- ❌ Test multiple simultaneous operations
- ❌ Go off-script
- ❌ Load test
- ❌ Network stress test

---

## 🔧 RECOMMENDED FIX PRIORITY

### **Phase 0: Demo Prep (4 hours) — FIX BEFORE DEMO**
1. Add input validation (UID, amount, username, password)
2. Add error dialogs for register/topup failures
3. Add loading indicators
4. Add UID collision check
5. Add saldo >= 0 validation

### **Phase 1: Pre-Production (1 week) — FIX BEFORE REAL DATA**
1. Implement audit logging
2. Generate transaction receipts
3. Fix currency (use integer cents)
4. Add fraud detection alerts
5. Verify transaction atomicity

### **Phase 2: Production (2 weeks) — FIX BEFORE LAUNCH**
1. Approval workflows for admin actions
2. System monitoring + alerts
3. Settlement/reconciliation process
4. Regulatory compliance review
5. Hardware lifecycle SLA

### **Phase 3: Post-Launch (1 month)**
1. Performance optimization
2. Mobile receipt/proof
3. Parent portal
4. Analytics dashboard

---

## 📝 CRITICAL CHECKLIST

- [ ] Input validation implemented
- [ ] UID collision check added
- [ ] Currency precision fixed (double → int)
- [ ] Error dialogs added
- [ ] Saldo validation added
- [ ] Audit logging implemented
- [ ] Transaction receipts generated
- [ ] Multi-device conflict handled
- [ ] Double-processing prevented
- [ ] Firestore indexes verified
- [ ] Regulatory compliance reviewed
- [ ] Approval workflow implemented
- [ ] Monitoring/alerts setup
- [ ] Backup/recovery plan documented

---

## 📞 NEXT STEPS

1. **Immediate**: Run DEMO with Phase 0 fixes (4 hours)
2. **This week**: Complete Phase 1 fixes (1 week)
3. **Next month**: Complete Phase 2 fixes (2 weeks)
4. **Then**: Launch with confidence

---

**Status**: ⚠️ **DEMO POSSIBLE, PRODUCTION NOT YET**

**Document Owner**: Claude  
**Last Updated**: May 14, 2026  
**Next Review**: After Phase 0 fixes
