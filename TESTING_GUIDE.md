# NBPay Software-Hardware Sync Testing Guide

## Status: ✅ Ready for Integration Testing

### Changes Completed (May 14, 2026)

**1. Data Model Enhancement**
- ✅ MachineCommandModel: Added `tujuan`, `saldo_result`, `nama_result`, `lastHeartbeat`
- ✅ Helper method `isOnline()` for heartbeat detection (> 60 sec = offline)

**2. Payment Processing**
- ✅ PaymentProvider: Added handlers for all 3 modes
  - Mode 1: `kasir` (pembayaran) — existing flow, now with proper state routing
  - Mode 2: `cek_saldo` (cek saldo) — NEW: wait for `waiting_check`, process via `processCekSaldo()`
  - Mode 3: `topup_daftar` (daftar/topup kartu) — NEW: process via `processTopupDaftarCard()`

**3. Firebase Operations**
- ✅ `resetMachine()`: Now properly deletes `saldo_result` and `nama_result` (not just `last_uid`)
- ✅ `processTopupDaftarCard()`: NEW method for topup_daftar mode
- ✅ `processCekSaldo()`: Existing but verified to handle all cek_saldo flow correctly

**4. Hardware Status Monitoring**
- ✅ MachineManagementScreen: Heartbeat offline detection (> 60 sec no ping = offline/gray)
- ✅ UI shows all status states: idle, waiting_tap, waiting_check, showing_saldo, success, error

---

## Testing Checklist

### Prerequisites
```bash
pip install firebase-admin
# Make sure nbpay-55455-firebase-adminsdk-fbsvc-196ab6c4fb.json exists in same folder
```

### Test 1: Mode Kasir (Pembayaran)
**What**: Admin app triggers payment, hardware tap kartu, app process & reset

1. Open admin app → Manajemen Mesin
2. Select machine with `tujuan: kasir`
3. Click "Bayar" button → set amount
4. Run simulator: select same machine → action [1] NFC tap
5. **Expect**:
   - ✅ Hardware sends `last_uid`
   - ✅ App status → `success` (if saldo OK) or `error` (if insufficient)
   - ✅ Hardware reads status and resets to `idle`
   - ✅ `last_uid` field deleted after reset

**Duration**: ~5 seconds

---

### Test 2: Mode Cek Saldo (Cek Saldo Mandiri)
**What**: Standalone balance check — no admin app trigger needed

1. Open admin app → Manajemen Mesin
2. Select machine with `tujuan: cek_saldo`
3. Run simulator: select machine → action [1] NFC tap
4. **Expect**:
   - ✅ Hardware sends status `waiting_check` + `last_uid`
   - ✅ App (running in background) receives & processes
   - ✅ App writes `saldo_result`, `nama_result`, status → `showing_saldo`
   - ✅ Hardware reads and displays: "Halo, [nama]! Saldo: Rp [amount]" for 5 sec
   - ✅ Hardware resets all fields to `idle`
   - ✅ Fields deleted: `last_uid`, `saldo_result`, `nama_result`

**Duration**: ~10 seconds

**Critical**: Admin app must be running. If app closed:
- Hardware waits max 10 sec → timeout → shows error
- This is expected behavior ✓

---

### Test 3: Mode Topup/Daftar (Registrasi & Topup Kartu)
**What**: Admin uses hardware to scan kartu untuk daftar siswa baru atau topup manual

1. Open admin app → Manajemen Mesin
2. Select machine with `tujuan: topup_daftar`
3. From admin app: trigger "Scan Kartu" (if implemented) OR use simulator
4. Run simulator: select machine → action [1] NFC tap
5. **Expect**:
   - ✅ Hardware sends `last_uid`
   - ✅ App receives & acknowledges (status → `success`)
   - ✅ Admin app shows scanned UID in UI
   - ✅ Admin can proceed with topup/registration flow

**Duration**: ~3 seconds

---

### Test 4: Heartbeat & Offline Detection
**What**: Verify heartbeat ping and offline status detection

1. Start simulator on any machine → action [1] NFC tap
2. **During active simulation**:
   - ✅ Simulator sends heartbeat every 30 sec (line 51 in machine_simulator.py)
   - ✅ Admin app shows machine status GREEN/ONLINE
3. **Stop simulator** (action [4] Keluar)
4. **Wait 65 seconds**
5. **Refresh admin app** (pull down or click refresh icon)
   - ✅ Machine now shows GRAY/OFFLINE

---

### Test 5: Multi-Machine Scenario
**What**: Test 2+ machines with different tujuan simultaneously

1. Create 2-3 machines via admin app:
   - Machine A: tujuan=kasir
   - Machine B: tujuan=cek_saldo
   - Machine C: tujuan=topup_daftar

2. Run simulator on Machine A
3. Separately, simulate Machine B & C by changing machine (action [3] Ganti mesin)
4. **Expect**: Each machine responds with appropriate flow

---

## Common Issues & Fixes

### Issue: "Kartu tidak dikenal" error
- **Cause**: UID format mismatch or user not in `users` collection
- **Fix**: Use actual UID from Firestore > users collection (doc ID)
- **Note**: Hardware must send UID as HEX UPPERCASE, no spaces (e.g., `A1B2C3D4`)

### Issue: Simulator waits > 10 sec then timeout
- **Cause**: Admin app not running or processing slow
- **Fix**: Make sure Flutter app is open and connected to same Firebase project
- **Expected**: App should process within ~10 sec for cek_saldo mode

### Issue: Machine stuck in "Menunggu Tap" state
- **Cause**: App crashed mid-transaction or admin didn't reset manually
- **Fix**: Admin app has reset button in Machine Management screen
- **Note**: Hardware should handle reset after success/error, but manual fallback exists

### Issue: Fields not deleted properly (saldo_result still visible)
- **Cause**: resetMachine() not called or using `null` instead of `FieldValue.delete()`
- **Fix**: Verify firebase_service.dart line ~200 uses `FieldValue.delete()`
- **Status**: ✅ Fixed in this update

---

## Regression Tests

After testing new modes, verify kasir mode still works:

- [ ] Kasir payment succeeds when saldo OK
- [ ] Kasir payment fails when saldo insufficient
- [ ] Machine resets cleanly after kasir transaction
- [ ] Heartbeat detection still works

---

## Next Steps

1. **Run full test suite** using checklist above
2. **Hardware integration** when physical device ready
3. **Load testing** with simulator running continuously (test for memory leaks, timeout accumulation)
4. **Error scenarios** (network disconnect, app crash mid-flow, multiple concurrent taps)

---

## Contact

For Firebase credentials or Firebase project details, contact: ibnumaulidi08@gmail.com

