# Hardware — NBPay Embedded Devices & Enclosure

Folder ini berisi seluruh aset hardware untuk ekosistem NBPay (Mesin EDC Kasir Kantin, Mesin Top-Up, Tool Integrasi, dan Casing 3D).

## Struktur Direktori

```
hardware/
├── esp32_rfid/          ← Firmware utama ESP32-S3 + RFID reader & ST7735 TFT (PlatformIO)
│   ├── platformio.ini   ← Konfigurasi board N16R8 (16MB Flash, 8MB PSRAM)
│   ├── src/main.cpp     ← Logika transaksi, scan kartu, dan listener Firestore
│   └── wire.md          ← Skema pinout lengkap & konfigurasi fake power
├── esp8266_topup/       ← Firmware pendukung ESP8266 Top-Up reader (OLED + MFRC522)
│   ├── platformio.ini   ← Konfigurasi NodeMCU v2
│   └── src/main.cpp     ← Firmware MQTT top-up reader
├── enclosure/           ← Model 3D Enclosure / Casing EDC & Desktop Dock
│   ├── *.scad           ← Source file OpenSCAD parametrik
│   ├── *.stl            ← Model siap cetak 3D (Bambu Lab / FDM)
│   └── README.md        ← Panduan spesifikasi & cetak 3D
├── tools/               ← Utility & Bridge
│   ├── machine_simulator.py  ← Simulator software untuk testing alur Firestore
│   └── nbpay_mqtt_bridge.py  ← MQTT-to-Firestore bridge untuk telemetry & scan
├── hardware.md          ← Dokumentasi arsitektur komunikasi Firestore & state machine
└── README.md            ← Panduan hardware ini
```

## Spesifikasi Perangkat Utama (ESP32-S3 EDC)

- **Microcontroller**: ESP32-S3 DevKitC-1 (16MB Flash / 8MB PSRAM)
- **NFC/RFID**: MFRC522 SPI 13.56 MHz
- **Display**: ST7735 1.8" TFT (SPI Bit-bang)
- **Audio Feedback**: Active Buzzer (GPIO 21)
- **Button Matrix**: 5 Push Buttons (menggunakan Fake VCC & Fake GND)
- **Konektivitas**: WiFi direct ke Firebase Firestore & MQTT Bridge

## Cara Memulai Firmware ESP32

1. Buka folder `hardware/esp32_rfid` di VS Code dengan ekstensi **PlatformIO IDE**.
2. Hubungkan board ESP32-S3 via port USB Type-C.
3. Build & upload firmware:
   ```bash
   pio run --target upload
   ```
4. Buka Serial Monitor (115200 baud):
   ```bash
   pio device monitor
   ```

## Panduan Kontribusi Hardware

1. Buat branch baru untuk fitur hardware: `git checkout -b hardware/nama-fitur`
2. Pastikan file build lokal (`.pio/`, `compile_commands.json`) dan kredensial (`*.json`) tidak ikut ter-commit.
3. Lakukan pengujian menggunakan `tools/machine_simulator.py` atau device fisik.
4. Buat Pull Request ke branch `main`.
