# Hardware — ESP32 Firmware

Folder ini berisi kode firmware untuk ESP32 yang terintegrasi dengan sistem NBPay.

## Struktur

```
hardware/
├── esp32_rfid/        ← Kode utama ESP32 + RFID reader
└── README.md
```

## Cara Kontribusi

1. Clone repo ini
2. Buat branch baru: `git checkout -b hardware/nama-fitur`
3. Tambahkan kode di folder ini
4. Buat Pull Request ke `main` untuk direview

## Dependensi

- Arduino IDE / PlatformIO
- Library: `Firebase ESP Client`, `MFRC522` (RFID)
- Board: ESP32 Dev Module

## Koneksi ke Firebase

Firmware ini berkomunikasi dengan Firestore via WiFi. Lihat [docs/hardware.md](../docs/hardware.md) untuk detail wiring dan konfigurasi.
