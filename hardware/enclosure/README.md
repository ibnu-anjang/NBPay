# NBPay EDC Enclosure (3D Models)

Folder ini berisi file 3D CAD (OpenSCAD `.scad`) dan file siap cetak 3D (`.stl`) untuk casing perangkat EDC NBPay (terminal pembayaran kantin).

## Model Files

- `top_half.scad` / `top_half.stl`: Bagian atas casing (faceplate dengan cutout untuk layar ST7735 dan slot RFID/tombol).
- `bottom_half.stl`: Bagian bawah penutup casing dengan dudukan PCB/ESP32-S3.
- `desktop_dock.scad` / `desktop_dock.stl`: Docking stand meja untuk meletakkan mesin EDC di kasir/meja kantin.

## Spesifikasi & Rekomendasi Cetak

- **Printer Target**: Dioptimalkan untuk Bambu Lab A1 Mini (atau printer FDM sejenis).
- **Dimensi Kasar**: 120 mm x 70 mm x 20 mm.
- **Support**: Dirancang tanpa perlu support (`No Supports`).
- **Nozzle**: 0.4 mm.
- **Perimeter/Wall**: 4 perimeter (1.6 mm wall thickness) untuk durabilitas harian di kantin.
- **Toleransi Sambungan**: 0.2 mm (friction-fit snap).
- **Material Rekomendasi**: PETG atau PLA+ (lebih tahan benturan).
