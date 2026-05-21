# NBPay System Requirements & Limitations

## ⚠️ CRITICAL ARCHITECTURAL REQUIREMENT

### Cek Saldo Mode Requires Admin App Online

**Mode**: `cek_saldo` (Siswa cek saldo mandiri di mesin)

**Requirement**: Admin app **MUST** be running and online during operation.

**Why**: 
- Saat siswa tap kartu di mesin, hardware kirim request ke Firestore
- Admin app listen ke request dan process lookup saldo
- Admin app write hasil saldo kembali ke Firestore
- Hardware baca hasil dan tampilkan

**What happens if admin app offline:**
- ❌ Hardware tunggu max 10 detik
- ❌ Timeout → mesin show "Sistem tidak merespons"
- ❌ Siswa cannot check saldo
- ❌ Mesin stuck (harus reset manual)

---

## ✅ OPERATIONAL REQUIREMENTS

### During School Hours
Admin app MUST be:
1. **Running** on admin device (tablet/laptop)
2. **Logged in** as admin user
3. **Connected to internet** (WiFi/cellular)
4. **Screen active** (or at least in background, not closed)

### Recommended Setup
- Use dedicated tablet in admin office
- Keep app running all day
- Have backup device with app installed
- Test connection to Firebase regularly

---

## 📋 MODE COMPARISON

| Mode | Requires App? | Duration | Timeout | Recovery |
|------|---------------|----------|---------|----------|
| **Kasir** (Pembayaran) | ✅ Yes | ~3 sec | 15 sec | Auto-reset |
| **Cek Saldo** | ✅ Yes (CRITICAL) | ~3 sec | 10 sec | Auto-reset, but no result shown |
| **Topup/Daftar** | ✅ Yes | ~5 sec | 10 sec | Manual reset |

---

## 🚨 FAILURE SCENARIOS

### Scenario 1: App crashes during cek_saldo
```
Student tap kartu
Hardware: waiting_check → app process... CRASH
Hardware: Tunggu 10 sec → timeout
Hardware: Show "Sistem tidak merespons"
Admin: Harus restart app dan reset mesin manual
```

**Mitigation**: Monitor app health, auto-restart on crash (future feature)

---

### Scenario 2: Network disconnect
```
Hardware: Send UID to Firestore ✓
App: Receive notification... but Internet gone ✗
Hardware: Tunggu 10 sec → timeout
```

**Mitigation**: App retry logic with exponential backoff (implemented)

---

### Scenario 3: Multiple mesin in cek_saldo mode simultaneously
```
Mesin A: waiting_check + student A
Mesin B: waiting_check + student B
App: Process A... then B
Timing: OK (sequential processing)
```

**Status**: ✅ Safe (transaction guards prevent race conditions)

---

## 🔧 DEPLOYMENT CHECKLIST

Before going live with cek_saldo mode:

- [ ] Dedicated admin device identified (tablet/laptop)
- [ ] Admin training on app requirements
- [ ] Internet connection verified (redundancy plan)
- [ ] Backup device with app ready
- [ ] Manual reset procedure documented for staff
- [ ] Monitoring setup (detect app crashes)
- [ ] Support contact info posted near mesin

---

## 📞 SUPPORT

If mesin stuck in "Menunggu Tap" or any other state:

1. **Check admin app** — Is it open and online?
2. **If app offline**: Restart app and go online
3. **If still stuck**: Click "Reset" button in Mesin Management screen
4. **If that fails**: Contact software engineer (Ibnu)

---

## FUTURE IMPROVEMENTS (Post-Launch)

- [ ] App health monitoring + auto-restart
- [ ] Fallback mode (offline balance cache)
- [ ] Admin notification when app goes offline
- [ ] Hardware-side timeout UI improvements
- [ ] Load testing for multi-mesin scenarios

---

**Last updated**: May 14, 2026  
**Status**: Ready for deployment with understanding of above requirements  
**Contact**: ibnumaulidi08@gmail.com
