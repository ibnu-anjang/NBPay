1. PRD (Product Requirements Document)
Dokumen ini menjelaskan apa yang dibangun dan mengapa.

Nama Proyek: SmartSchool Cashless Ecosystem (E-Money Prototype)
Tujuan: Mengganti transaksi tunai di sekolah dengan kartu RFID/NFC guna pencatatan keuangan yang transparan.

Fitur Utama:
Aplikasi Siswa (Mobile): Login, Cek Saldo Real-time, Riwayat Transaksi.

Aplikasi Admin/Kantin (Web/Tablet):

Kasir: Input nominal belanja dan perintah "Tap" ke ESP32.

Top-up: Menambah saldo siswa setelah bayar tunai.

User Management: Daftar kartu baru (Link UID kartu ke nama siswa).

Integrasi Hardware: ESP32 sebagai reader yang terhubung ke Firebase via WiFi.

Kebutuhan Non-Fungsional:
Real-time: Perubahan saldo harus terlihat di HP siswa dalam < 2 detik setelah tap.

Keamanan: Logika pengurangan saldo dilakukan di sisi server/app admin, bukan di kartu.

2. ERD (Entity Relationship Diagram)
Ini adalah rancangan struktur data di Firebase Firestore. Karena Firestore adalah NoSQL, kita akan memodelkannya dalam bentuk koleksi.

Koleksi: users (Siswa & Admin)
uid_kartu (String, PK): ID unik dari RFID.

nama (String)

role (String): "siswa" / "admin"

saldo (Number)

nis (String)

Koleksi: transactions (Log)
transaction_id (String, PK)

uid_kartu (String, FK)

nominal (Number)

tipe (String): "debit" (jajan) / "credit" (topup)

timestamp (Timestamp)

keterangan (String)

Koleksi: machine_commands (Jembatan ESP32)
machine_id (String, PK)

status (String): "idle" / "waiting_tap" / "success" / "error"

amount (Number)

3. TRD (Technical Requirements Document)
Ini menjelaskan bagaimana teknologi tersebut bekerja sama.

Stack Teknologi:
Frontend: Flutter (Mobile untuk Siswa, Web/Tablet untuk Admin).

Backend: Firebase (Firestore sebagai database, Auth untuk login).

Hardware: ESP32 + RFID Reader (RC522/PN532).

Protokol Komunikasi: Firebase Stream (Listen) — ESP32 akan selalu subscribe ke dokumen di machine_commands.

Alur Teknis Pembayaran:
Aplikasi Admin mengubah dokumen machine_commands/kantin_01 menjadi status waiting_tap.

ESP32 mendeteksi perubahan status tersebut via WiFi.

Siswa menempelkan kartu. ESP32 membaca UID dan mengirimnya ke Firebase.

Firebase/Logic memvalidasi saldo. Jika cukup:

Update saldo di koleksi users.

Tambah dokumen di koleksi transactions.

Update status machine_commands menjadi success.

Aplikasi Admin menangkap status success dan menampilkan nota digital.
