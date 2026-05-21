# NBPay

Sistem pembayaran digital untuk kantin sekolah berbasis RFID dan Firebase.

## Struktur Repo

```
NBPay/
├── software/        ← Aplikasi Flutter (admin, penjual, siswa)
├── hardware/        ← Firmware ESP32 + RFID reader
│   ├── esp32_rfid/
│   ├── tools/
│   └── hardware.md
└── README.md
```

## Cara Mulai

### Software (Flutter)
```bash
cd software
flutter pub get
flutter run
```

### Hardware (ESP32)
Lihat [`hardware/README.md`](hardware/README.md) untuk panduan wiring dan upload firmware.

## Teknologi

| Layer | Stack |
|-------|-------|
| Mobile/Web | Flutter (Dart) |
| Backend | Firebase Firestore + Auth |
| Hardware | ESP32 + MFRC522 (RFID) |
