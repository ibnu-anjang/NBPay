# NBPay – Hardware Integration Docs

Dokumen ini untuk engineer hardware (firmware/embedded). Semua komunikasi mesin ke sistem dilakukan lewat **Firebase Firestore**. Tidak ada REST API, tidak ada server lain — cukup baca/tulis Firestore.

---

## 1. Setup Awal

### Firebase Credentials
Minta file `nbpay-55455-firebase-adminsdk-fbsvc-196ab6c4fb.json` dari software engineer (Ibnu).

Nama file tersebut yang dipakai di semua kode. Jangan rename.

### Collection yang dipakai mesin
```
machine_commands/{machine_id}
```
Setiap mesin punya 1 dokumen. `machine_id` ditentukan saat admin daftarkan mesin (contoh: `kantin_01`, `lobby_02`).

### Cara mesin tau ID-nya sendiri
ID mesin dibuat oleh **software engineer (Ibnu)** dari admin app, lalu dikasih tau ke hardware engineer untuk di-hardcode di firmware atau disimpan di file config lokal di device.

Alurnya:
1. Ibnu daftarkan mesin dari admin app → tentukan ID (contoh: `kantin_01`)
2. Ibnu kasih tau ID tersebut ke hardware engineer
3. Hardware engineer hardcode ID di firmware device yang bersangkutan

Simpan di firmware atau file config:
```
MACHINE_ID=kantin_01
```

Setiap device fisik punya ID unik. Jangan pakai ID yang sama di dua device sekaligus.

---

## 2. Struktur Dokumen Mesin

```json
{
  "nama": "Mesin Kantin 1",
  "tujuan": "kasir",
  "status": "idle",
  "amount": 0,
  "last_heartbeat": <Timestamp>
}
```

> Field `last_uid`, `saldo_result`, `nama_result` **tidak ada saat idle** — field ini dihapus (bukan di-set null) setelah setiap transaksi selesai. Jangan asumsikan field ini selalu ada, selalu pakai `.get("field", default)`.

| Field | Tipe | Ditulis oleh | Keterangan |
|---|---|---|---|
| `nama` | string | Admin app | Nama tampilan mesin |
| `tujuan` | string | Admin app | Mode mesin: `kasir` / `cek_saldo` / `topup_daftar` |
| `status` | string | Keduanya | Status aktif mesin |
| `amount` | number | Admin app | Nominal pembayaran (khusus mode kasir) |
| `last_uid` | string | **Mesin** | UID kartu NFC yang terakhir ditap |
| `saldo_result` | number | Admin app | Hasil cek saldo (khusus mode cek_saldo) |
| `nama_result` | string | Admin app | Nama siswa hasil cek saldo |
| `last_heartbeat` | Timestamp | **Mesin** | Waktu terakhir mesin kirim sinyal hidup |

---

## 3. Heartbeat (Wajib)

Mesin harus kirim heartbeat ke Firestore **setiap 30 detik** selama menyala.

```
WRITE machine_commands/{machine_id}:
  last_heartbeat: <server timestamp>
```

Jika tidak ada heartbeat selama **> 60 detik**, admin app akan tandai mesin sebagai **offline** (abu-abu).

### Pseudocode
```python
while True:
    firestore.update(f"machine_commands/{MACHINE_ID}", {
        "last_heartbeat": SERVER_TIMESTAMP
    })
    sleep(30)
```

---

## 4. Baca Konfigurasi Mesin

Saat boot, mesin baca field `tujuan` untuk tau harus jalan di mode apa.

```
READ machine_commands/{machine_id}
  → ambil field: tujuan
```

Mesin juga harus **listen realtime** ke dokumen ini, karena admin bisa ganti `tujuan` kapan saja tanpa restart mesin.

```python
firestore.listen(f"machine_commands/{MACHINE_ID}", on_change=handle_config_change)
```

---

## 5. Alur Per Mode

### Mode A: `kasir` — Pembayaran

```
Admin set amount → mesin status: waiting_tap
Siswa tap kartu → mesin tulis last_uid
App proses bayar → mesin baca status: success / error
Mesin reset → idle
```

**Step by step:**

1. **Listen** perubahan field `status` di dokumen mesin
2. Jika `status == "waiting_tap"`:
   - Aktifkan NFC reader
   - Tampilkan: *"Tempel kartu untuk bayar"*
3. Siswa tap kartu → mesin dapat UID kartu
4. **WRITE** ke Firestore:
   ```json
   {
     "last_uid": "<uid_kartu_siswa>"
   }
   ```
5. Tunggu `status` berubah jadi `success` atau `error`
6. Jika `success`: tampilkan *"Pembayaran berhasil!"* selama 3 detik, lalu **WRITE reset**:
   ```python
   machine_ref.update({
       "status": "idle",
       "last_uid": firestore.DELETE_FIELD,
   })
   ```
7. Jika `error`: tampilkan *"Gagal! Saldo tidak cukup"* selama 3 detik, lalu **WRITE reset** yang sama seperti step 6

> ⚠️ **Mesin WAJIB reset Firestore setelah success/error** — ini berbeda dari dokumentasi lama. Kalau tidak direset, mesin stuck dan admin app harus klik reset manual untuk setiap transaksi. Di kantin ramai ini tidak praktis.
>
> Admin app tetap punya tombol reset sebagai **fallback** (misalnya kalau mesin mati mendadak saat proses), tapi di kondisi normal hardware yang reset.

---

### Mode B: `cek_saldo` — Cek Saldo Mandiri

```
Mesin idle → siswa tap kartu
Mesin tulis last_uid + status: waiting_check
App lookup saldo → tulis saldo_result + status: showing_saldo
Mesin baca & tampilkan saldo
Mesin reset → idle setelah 5 detik
```

> ⚠️ **PENTING:** Setelah tampil saldo, mesin **WAJIB** reset Firestore ke idle (step 9). Kalau tidak direset, saldo siswa sebelumnya akan bocor ke siswa berikutnya.

**Step by step:**

1. Mesin dalam kondisi idle, NFC reader aktif terus
2. Tampilkan: *"Tempel kartu untuk cek saldo"*
3. Siswa tap kartu → mesin dapat UID
4. **WRITE** ke Firestore:
   ```json
   {
     "status": "waiting_check",
     "last_uid": "<uid_kartu_siswa>"
   }
   ```
5. Tampilkan loading: *"Mengambil data..."*
6. Tunggu `status` berubah jadi `showing_saldo` atau `error`
7. Jika `showing_saldo`:
   - Baca `nama_result` dan `saldo_result` dari dokumen
   - Tampilkan:
     ```
     Halo, Ahmad Fauzi!
     Saldo kamu: Rp 15.000
     ```
   - Tampilkan selama 5 detik
8. Jika `error`:
   - Baca `nama_result` (berisi pesan error, misal: "Kartu tidak dikenal")
   - Tampilkan pesan error selama 3 detik
   - **WRITE** reset — wajib, sama seperti step 9:
   ```python
   machine_ref.update({
       "status": "idle",
       "last_uid": firestore.DELETE_FIELD,
       "nama_result": firestore.DELETE_FIELD,
   })
   ```
9. **WRITE** reset ke Firestore setelah `showing_saldo` — **wajib dilakukan, jangan dilewat:**
   ```python
   machine_ref.update({
       "status": "idle",
       "last_uid": firestore.DELETE_FIELD,
       "saldo_result": firestore.DELETE_FIELD,
       "nama_result": firestore.DELETE_FIELD,
   })
   ```
   > ⚠️ **Jangan set ke `null`** — gunakan `DELETE_FIELD`. Set ke `null` masih menyisakan field di dokumen dan bisa menyebabkan saldo siswa sebelumnya muncul ke siswa berikutnya yang tap kartu.

---

### Mode C: `topup_daftar` — Scan Kartu untuk Daftar/Topup

Mode ini dipakai admin saat mau daftarkan siswa baru atau topup manual pakai kartu fisik.

```
Admin trigger dari app → mesin status: waiting_uid
Siswa tap kartu → mesin tulis last_uid
App baca UID → proses daftar/topup
```

**Step by step:**

1. **Listen** perubahan `status`
2. Jika `status == "waiting_uid"`:
   - Aktifkan NFC reader
   - Tampilkan: *"Tempel kartu siswa"*
3. Kartu ditap → dapat UID
4. **WRITE** ke Firestore:
   ```json
   {
     "last_uid": "<uid_kartu>"
   }
   ```
   *(Tidak perlu tulis status — app yang handle setelah baca UID)*
5. Tunggu instruksi berikutnya dari app (status akan berubah ke `idle` atau command lain)

---

## 6. Status Reference

| Status | Siapa set | Artinya |
|---|---|---|
| `idle` | App / Mesin | Siap, tidak ada proses |
| `waiting_tap` | App | Menunggu kartu untuk bayar (mode kasir) |
| `waiting_check` | **Mesin** | Menunggu app lookup saldo (mode cek_saldo) |
| `waiting_uid` | App | Menunggu scan kartu (mode topup_daftar) |
| `showing_saldo` | App | Saldo sudah ada, mesin baca dan tampilkan |
| `success` | App | Transaksi berhasil |
| `error` | App | Gagal (saldo kurang / kartu tidak dikenal) |

---

## 7. Listen Realtime vs Polling

**Gunakan realtime listener**, bukan polling. Firebase SDK (Python, Node.js, Go, C++) semua support `on_snapshot`.

```python
# Python (firebase-admin)
def on_snapshot(doc_snapshot, changes, read_time):
    doc = doc_snapshot[0]
    data = doc.to_dict()
    status = data.get("status")
    tujuan = data.get("tujuan")
    handle_status_change(status, tujuan, data)

doc_ref = db.collection("machine_commands").document(MACHINE_ID)
doc_watch = doc_ref.on_snapshot(on_snapshot)
```

---

## 8. Contoh Implementasi Lengkap (Python)

> ⚠️ **Jangan taruh blocking call di dalam snapshot callback.** Firebase menjalankan `on_snapshot` di background thread — kalau callback diblock dengan `time.sleep()` atau `wait_for_nfc_tap()`, listener berhenti menerima update sampai blocking selesai. Setelah transaksi pertama, mesin bisa berhenti bereaksi.
>
> Solusi: gunakan `queue.Queue` untuk komunikasi antar thread. Snapshot callback hanya menaruh pesan ke queue, worker thread yang handle logic.

```python
import firebase_admin
from firebase_admin import credentials, firestore
import threading, queue, time

MACHINE_ID = "kantin_01"

cred = credentials.Certificate("nbpay-55455-firebase-adminsdk-fbsvc-196ab6c4fb.json")
firebase_admin.initialize_app(cred)
db = firestore.client()
machine_ref = db.collection("machine_commands").document(MACHINE_ID)

# Queue untuk komunikasi snapshot → worker
event_queue = queue.Queue()

# ── Heartbeat ─────────────────────────────────────────────────────────────────

def send_heartbeat():
    while True:
        machine_ref.update({"last_heartbeat": firestore.SERVER_TIMESTAMP})
        time.sleep(30)

# ── Snapshot callback (NON-BLOCKING) ──────────────────────────────────────────

def on_snapshot(doc_snapshot, changes, read_time):
    # Callback ini TIDAK boleh blocking. Hanya kirim data ke queue.
    data = doc_snapshot[0].to_dict()
    event_queue.put(data)

# ── Worker thread (boleh blocking) ────────────────────────────────────────────

def worker():
    current_status = None  # track status terakhir untuk hindari proses ulang

    while True:
        try:
            data = event_queue.get(timeout=1)
        except queue.Empty:
            continue

        tujuan = data.get("tujuan", "kasir")
        status = data.get("status", "idle")

        # Skip kalau status tidak berubah (Firestore kadang kirim snapshot duplikat)
        if status == current_status:
            continue
        current_status = status

        if tujuan == "cek_saldo":
            if status == "idle":
                display("Tempel kartu untuk cek saldo")
                uid = wait_for_nfc_tap()           # boleh blocking di sini
                uid = uid.strip().upper()          # normalisasi format — wajib uppercase
                machine_ref.update({
                    "status": "waiting_check",
                    "last_uid": uid,
                })
                display("Mengambil data...")
                current_status = "waiting_check"

            elif status == "showing_saldo":
                nama = data.get("nama_result", "Siswa")
                saldo = data.get("saldo_result", 0)
                display(f"Halo, {nama}!\nSaldo: Rp {saldo:,.0f}")
                time.sleep(5)
                machine_ref.update({
                    "status": "idle",
                    "last_uid": firestore.DELETE_FIELD,
                    "saldo_result": firestore.DELETE_FIELD,
                    "nama_result": firestore.DELETE_FIELD,
                })
                current_status = "idle"

            elif status == "error":
                pesan = data.get("nama_result", "Kartu tidak dikenal")
                display(f"Gagal: {pesan}")
                time.sleep(3)
                machine_ref.update({
                    "status": "idle",
                    "last_uid": firestore.DELETE_FIELD,
                    "nama_result": firestore.DELETE_FIELD,
                })
                current_status = "idle"

        elif tujuan == "kasir":
            if status == "waiting_tap":
                display("Tempel kartu untuk bayar")
                uid = wait_for_nfc_tap()           # boleh blocking di sini
                uid = uid.strip().upper()          # normalisasi format — wajib uppercase
                machine_ref.update({"last_uid": uid})
                display("Memproses...")
                current_status = "waiting_tap"     # tetap waiting_tap sampai app balas

            elif status == "success":
                display("Pembayaran berhasil!")
                time.sleep(3)
                # Mesin reset Firestore — tanpa ini admin harus klik reset manual tiap transaksi
                machine_ref.update({
                    "status": "idle",
                    "last_uid": firestore.DELETE_FIELD,
                })
                current_status = "idle"

            elif status == "error":
                display("Gagal! Saldo tidak cukup")
                time.sleep(3)
                machine_ref.update({
                    "status": "idle",
                    "last_uid": firestore.DELETE_FIELD,
                })
                current_status = "idle"

        elif tujuan == "topup_daftar":
            if status == "waiting_uid":
                display("Tempel kartu siswa")
                uid = wait_for_nfc_tap()
                uid = uid.strip().upper()
                machine_ref.update({"last_uid": uid})
                display("Kartu terbaca, tunggu...")

# ── Main ──────────────────────────────────────────────────────────────────────

threading.Thread(target=send_heartbeat, daemon=True).start()
threading.Thread(target=worker, daemon=True).start()

doc_watch = machine_ref.on_snapshot(on_snapshot)

while True:
    time.sleep(1)
```

---

## 9. Library yang Bisa Dipakai

| Platform | Library |
|---|---|
| Python (Raspberry Pi) | `firebase-admin` |
| Node.js | `firebase-admin` (npm) |
| Arduino / ESP32 | Tidak support Firestore native — gunakan REST API via HTTP |
| Go | `cloud.google.com/go/firestore` |

### ESP32 / Arduino (via REST)

> ⚠️ **Peringatan untuk ESP32:** Ini jauh lebih kompleks dari Raspberry Pi. Firestore REST API butuh OAuth2 Bearer token yang **expire setiap 60 menit** dan harus di-refresh. Di embedded C++ kamu harus:
> 1. Implement JWT signing pakai RSA private key dari service account JSON
> 2. Request access token ke `https://oauth2.googleapis.com/token`
> 3. Pakai token itu di setiap request
> 4. Detect ketika token expire dan refresh otomatis
>
> **Rekomendasi:** Kalau pakai ESP32, pertimbangkan Raspberry Pi Zero W (murah, ~$15) yang bisa jalankan Python firebase-admin langsung. Lebih simpel dan lebih reliable untuk proyek ini.
>
> Kalau tetap mau ESP32, hubungi software engineer (Ibnu) untuk setup token refresh.

Contoh request setelah token didapat:
```
PATCH https://firestore.googleapis.com/v1/projects/nbpay-55455/databases/(default)/documents/machine_commands/{MACHINE_ID}
Authorization: Bearer <oauth2_access_token>
Content-Type: application/json

{
  "fields": {
    "last_heartbeat": { "timestampValue": "2025-05-14T10:00:00Z" },
    "last_uid": { "stringValue": "A1B2C3D4" }
  }
}
```

---

## 10. Format UID Kartu NFC — Wajib Konsisten

UID kartu yang dikirim ke `last_uid` **harus format yang sama persis** di semua mode (kasir, cek_saldo, topup_daftar).

Alasannya: saat siswa didaftarkan via mode `topup_daftar`, UID yang dikirim hardware langsung jadi **doc ID** di Firestore collection `users`. Kalau saat cek_saldo hardware kirim format berbeda → user tidak ketemu → selalu error.

**Kesepakatan format yang harus dipakai:**
```
Format  : HEX UPPERCASE tanpa spasi/titik dua
Contoh  : A1B2C3D4  ✅
Jangan  : a1b2c3d4  ❌  (lowercase)
Jangan  : A1:B2:C3:D4  ❌  (ada titik dua)
Jangan  : 161 178 195 212  ❌  (desimal)
```

Pastikan library NFC yang dipakai dikonversi ke format ini sebelum dikirim ke Firestore.

```python
# Contoh konversi di Python
uid_bytes = nfc_reader.get_uid()  # misal: b'\xa1\xb2\xc3\xd4'
uid_str = uid_bytes.hex().upper()  # hasil: "A1B2C3D4"
```

---

## 11. Keterbatasan Sistem & Yang Harus Dihandle Firmware

### Cek Saldo butuh admin app aktif
Mode `cek_saldo` diproses oleh admin app Flutter. Artinya **admin app harus buka dan online** saat siswa tap kartu. Kalau app ditutup → mesin nunggu selamanya.

**Firmware wajib implementasi timeout — gunakan event, bukan polling:**

```python
# ❌ JANGAN begini — setiap loop = 1 Firestore read, 20 reads per timeout
# for _ in range(20):
#     time.sleep(0.5)
#     doc = machine_ref.get().to_dict()

# ✅ Pakai event yang di-set dari snapshot callback (sudah punya listener aktif)
# Tambahkan di worker():

TIMEOUT = 10  # detik

def wait_for_app_response(timeout_sec):
    """Tunggu status berubah dari waiting_check. Return status baru atau None jika timeout."""
    result = queue.Queue()

    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        try:
            data = event_queue.get(timeout=0.5)
            status = data.get("status")
            if status in ("showing_saldo", "error"):
                return data
        except queue.Empty:
            continue
    return None  # timeout

# Penggunaan di worker setelah write waiting_check:
result_data = wait_for_app_response(TIMEOUT)
if result_data is None:
    display("Sistem tidak merespons. Coba lagi.")
    time.sleep(3)
    machine_ref.update({
        "status": "idle",
        "last_uid": firestore.DELETE_FIELD,
    })
```

> Pendekatan ini tidak menambah Firestore reads — data sudah datang via listener yang aktif.

### Jangan tap kartu saat mesin sedang proses
Jika `status != "idle"` saat kartu ditap, firmware harus **abaikan tap** dan tampilkan *"Mesin sedang sibuk"*.

```python
doc = machine_ref.get().to_dict()
if doc.get("status") != "idle":
    display("Mesin sedang sibuk, tunggu sebentar")
    return  # abaikan tap
```

---

## 12. Testing Tanpa Hardware

Sebelum hardware jadi, gunakan script simulator untuk verifikasi integrasi Firebase sudah benar.

### Setup
```bash
pip install firebase-admin
# Pastikan file nbpay-55455-firebase-adminsdk-fbsvc-196ab6c4fb.json ada di folder yang sama
python machine_simulator.py
```

### Yang bisa ditest
- Simulasi NFC tap kartu → lihat app admin bereaksi
- Heartbeat → lihat status mesin berubah hijau di app
- Stop heartbeat → lihat mesin jadi abu-abu (offline) dalam beberapa detik (simulator langsung set timestamp ke 2 menit lalu)
- Cek saldo → simulator otomatis tunggu respons dan tampilkan hasilnya

### Cara dapat UID kartu untuk testing
Buka Firebase Console → Firestore → collection `users` → ambil doc ID salah satu siswa (itu adalah uid_kartu-nya).

---

## 13. Kontak

Untuk PROJECT_ID, serviceAccountKey, atau pertanyaan teknis lainnya — hubungi software engineer (Ibnu).
