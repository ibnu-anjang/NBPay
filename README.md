# NBPay — SmartSchool Cashless Ecosystem

> Sistem pembayaran cashless berbasis RFID/NFC untuk lingkungan sekolah, dibangun dengan Flutter + Firebase + ESP32.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Tentang Proyek

NBPay mengganti transaksi tunai di sekolah dengan kartu RFID/NFC untuk pencatatan keuangan yang transparan dan real-time.

**Aktor:**
- **Siswa** — Cek saldo & riwayat transaksi via mobile app
- **Kasir/Admin** — Input transaksi, top-up saldo, manajemen kartu & pengguna
- **Penjual** — Terima pembayaran & kelola withdrawal

## Arsitektur

```
Flutter App (Mobile/Web/Tablet)
        │
        ▼
   Firebase (Firestore + Auth)
        │
        ▼
   ESP32 + RFID Reader (RC522/PN532)
```

**Stack:** Flutter · Firebase Firestore · Firebase Auth · ESP32 · RFID/NFC

## Alur Pembayaran

1. Admin set `machine_commands/{id}` → `status: waiting_tap`
2. ESP32 mendeteksi perubahan via Firebase Stream
3. Siswa tap kartu → ESP32 kirim UID ke Firebase
4. Server validasi saldo → update `users`, `transactions`, `machine_commands`
5. Admin menerima konfirmasi `status: success` + nota digital

## Struktur Data (Firestore)

| Koleksi | Field Utama |
|---|---|
| `users` | uid_kartu, nama, role, saldo, nis |
| `transactions` | uid_kartu, nominal, tipe, timestamp, keterangan |
| `machine_commands` | machine_id, status, amount |

## Requirements

- Flutter SDK >= 3.x
- Firebase project dengan Firestore & Authentication aktif
- ESP32 + RFID Reader (untuk integrasi hardware)

## Setup

```bash
flutter pub get
# Tambahkan google-services.json (Android) ke android/app/
# Tambahkan GoogleService-Info.plist (iOS) ke ios/Runner/
flutter run
```

## Tools

| File | Fungsi |
|---|---|
| `tools/machine_simulator.py` | Simulator ESP32 untuk testing tanpa hardware fisik |

## Dokumentasi

| File | Isi |
|---|---|
| [docs/hardware.md](docs/hardware.md) | Setup ESP32, wiring RFID, firmware |
| [docs/system-requirements.md](docs/system-requirements.md) | Kebutuhan sistem & dependensi |
| [docs/testing.md](docs/testing.md) | Panduan testing manual & skenario uji |

## License

Copyright (c) 2026 **Ibnu Maulidi** — [MIT License](LICENSE)
