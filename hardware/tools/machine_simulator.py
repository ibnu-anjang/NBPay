"""
NBPay Machine Simulator (Hardware Mock)
=======================================
Script ini mensimulasikan mesin hardware ESP32 RFID NBPay.
Mendukung:
  1. Heartbeat otomatis agar mesin terdeteksi ONLINE di aplikasi HP/Web.
  2. Auto-listener: Otomatis mendeteksi saat Kasir meminta tap kartu (waiting_tap)
     atau saat Admin meminta scan kartu (waiting_uid).
  3. Cepat tap kartu: Cukup pilih nomor siswa (Budi, Ahmad, Siti) tanpa perlu ketik UID manual.
  4. Mode Semua Mesin Online: Membuat seluruh mesin kantin & lobby online sekaligus!

Usage:
  python hardware/tools/machine_simulator.py
"""

import os
import sys
import threading
import time
import firebase_admin
from firebase_admin import credentials, firestore

# ─── CONFIG & AUTHENTICATION ─────────────────────────────────────────────────
KEY_FILENAME = "nbpay-55455-firebase-adminsdk-fbsvc-196ab6c4fb.json"
POSSIBLE_PATHS = [
    KEY_FILENAME,
    os.path.join(os.path.dirname(__file__), KEY_FILENAME),
    os.path.join(os.path.dirname(__file__), "..", "..", "software", KEY_FILENAME),
    os.path.join(os.getcwd(), "software", KEY_FILENAME),
    os.path.join(os.getcwd(), KEY_FILENAME),
]

SERVICE_ACCOUNT_KEY = None
for p in POSSIBLE_PATHS:
    if os.path.exists(p):
        SERVICE_ACCOUNT_KEY = os.path.abspath(p)
        break

if not SERVICE_ACCOUNT_KEY:
    print(f"❌ Error: {KEY_FILENAME} tidak ditemukan di lokasi standar.")
    sys.exit(1)

try:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred)
except ValueError:
    pass  # Already initialized

db = firestore.client()


def get_machines():
    docs = db.collection("machine_commands").stream()
    return [{"id": d.id, **d.to_dict()} for d in docs]


def get_registered_students():
    docs = db.collection("users").where("role", "==", "siswa").stream()
    students = []
    for d in docs:
        data = d.to_dict()
        uid = data.get("uid_kartu") or d.id
        nama = data.get("nama", "Tanpa Nama")
        nis = data.get("nis", "-")
        saldo = data.get("saldo", 0)
        students.append({"uid": uid, "nama": nama, "nis": nis, "saldo": saldo})
    return students


def send_heartbeat_single(machine_id: str, stop_event: threading.Event):
    """Kirim heartbeat ke Firestore setiap 20 detik agar mesin selalu ONLINE."""
    while not stop_event.is_set():
        try:
            db.collection("machine_commands").document(machine_id).set({
                "last_heartbeat": firestore.SERVER_TIMESTAMP
            }, merge=True)
            # Silent heartbeat or minimal log
        except Exception as e:
            print(f"  [Heartbeat Error {machine_id}]: {e}")
        stop_event.wait(20)


def send_heartbeat_all(machine_ids: list, stop_event: threading.Event):
    """Kirim heartbeat untuk semua mesin sekaligus setiap 20 detik."""
    while not stop_event.is_set():
        try:
            batch = db.batch()
            for mid in machine_ids:
                ref = db.collection("machine_commands").document(mid)
                batch.set(ref, {"last_heartbeat": firestore.SERVER_TIMESTAMP}, merge=True)
            batch.commit()
            # print("  💓 [All Machines] Heartbeat terkirim — semua mesin Online!")
        except Exception as e:
            print(f"  [Heartbeat Batch Error]: {e}")
        stop_event.wait(20)


def simulate_nfc_tap(machine_id: str, uid_kartu: str):
    """Simulasi tap kartu RFID ke mesin."""
    ref = db.collection("machine_commands").document(machine_id)
    doc = ref.get().to_dict() or {}
    tujuan = doc.get("tujuan", "kasir")
    status = doc.get("status", "idle")

    print(f"\n  📡 [NFC TAP] Menempelkan kartu UID: {uid_kartu} ke mesin [{machine_id}]...")

    if tujuan == "cek_saldo" or status == "waiting_check":
        print(f"  🔍 Mengecek saldo kartu {uid_kartu} di database...")
        user_snap = db.collection("users").document(uid_kartu).get()
        if not user_snap.exists:
            print(f"  ❌ Kartu {uid_kartu} tidak terdaftar di database!")
            ref.set({
                "status": "error",
                "nama_result": "Kartu Tak Dikenal",
                "last_uid": uid_kartu,
                "tujuan": "cek_saldo",
            }, merge=True)
            time.sleep(3)
            ref.set({"status": "idle"}, merge=True)
            return

        user_data = user_snap.to_dict()
        nama = user_data.get("nama", "Siswa")
        saldo = user_data.get("saldo", 0)
        is_frozen = user_data.get("is_frozen", False)

        if is_frozen:
            print(f"  ⚠️ KARTU DIBEKUKAN! Milik {nama} ({uid_kartu})")
            ref.set({
                "status": "error",
                "nama_result": "KARTU DIBEKUKAN!",
                "last_uid": uid_kartu,
                "tujuan": "cek_saldo",
            }, merge=True)
            time.sleep(3)
            ref.set({"status": "idle"}, merge=True)
            return

        print(f"  ✅ Layar Mesin: Halo {nama} | Saldo: Rp {saldo:,.0f}")
        ref.set({
            "status": "showing_saldo",
            "last_uid": uid_kartu,
            "nama_result": nama,
            "saldo_result": saldo,
            "tujuan": "cek_saldo",
        }, merge=True)
        time.sleep(4)
        ref.set({
            "status": "idle",
            "last_uid": firestore.DELETE_FIELD,
            "saldo_result": firestore.DELETE_FIELD,
            "nama_result": firestore.DELETE_FIELD,
        }, merge=True)
        print("  🔄 Mesin reset ke status idle (siap).\n")
        return

    # Kasir atau Top-up / Scan
    ref.set({"last_uid": uid_kartu}, merge=True)
    print(f"  📲 UID dikirim ke Firestore. Menunggu aplikasi memproses transaksi...")

    for _ in range(20):  # max 10s wait
        time.sleep(0.5)
        cur = ref.get().to_dict() or {}
        st = cur.get("status")
        if st == "success":
            print(f"  🎉 Transaksi BERHASIL! (Layar hardware: SUKSES)\n")
            return
        elif st == "error":
            print(f"  ❌ Transaksi GAGAL (Saldo tidak cukup / dibekukan / batas harian)\n")
            return
        elif st == "idle":
            print(f"  ✅ Selesai dan kembali ke idle.\n")
            return

    print("  ⏱️ Timeout: Tidak ada perubahan status dari aplikasi.")


def reset_machine(machine_id: str):
    db.collection("machine_commands").document(machine_id).set({
        "status": "idle",
        "last_uid": firestore.DELETE_FIELD,
        "saldo_result": firestore.DELETE_FIELD,
        "nama_result": firestore.DELETE_FIELD,
    }, merge=True)
    print(f"  🔄 Mesin [{machine_id}] direset ke idle")


def pick_student_card(students):
    """Menampilkan daftar kartu siswa siap pakai."""
    print("\n  Pilih kartu siswa untuk ditap:")
    for idx, s in enumerate(students):
        print(f"    [{idx + 1}] {s['nama']} (NIS: {s['nis']}) | UID: {s['uid']} | Saldo: Rp {s['saldo']:,.0f}")
    print(f"    [M] Masukkan UID manual")
    print(f"    [B] Batal")
    ans = input("  Pilihan kartu [1]: ").strip()
    if not ans or ans == "1":
        return students[0]["uid"] if students else "34A4FB24"
    if ans.lower() == "b":
        return None
    if ans.lower() == "m":
        return input("  Ketik UID manual: ").strip()
    try:
        num = int(ans) - 1
        if 0 <= num < len(students):
            return students[num]["uid"]
    except ValueError:
        pass
    return ans


def main():
    print("=" * 60)
    print("  🚀 NBPay Hardware Simulator (ESP32 RFID Mock)")
    print("=" * 60)

    machines = get_machines()
    if not machines:
        print("❌ Tidak ada mesin terdaftar di Firestore.")
        sys.exit(1)

    students = get_registered_students()

    print("\nDaftar Mesin:")
    print("  [0] ⚡ AKTIFKAN SEMUA MESIN SEKALIGUS (Online Background)")
    for i, m in enumerate(machines):
        tujuan = m.get("tujuan", "-")
        print(f"  [{i+1}] {m.get('nama', m['id'])} | id: {m['id']} | tipe: {tujuan}")
    print()

    try:
        raw = input("Pilih mesin yang ingin disimulasikan [0]: ").strip()
        choice = int(raw) if raw else 0
    except ValueError:
        choice = 0

    stop_event = threading.Event()

    if choice == 0:
        # All machines online
        mids = [m["id"] for m in machines]
        hb_thread = threading.Thread(target=send_heartbeat_all, args=(mids, stop_event), daemon=True)
        hb_thread.start()
        print("\n💚 SEMUA MESIN SEKARANG ONLINE!")
        print("   Silakan buka aplikasi di HP Anda (https://nbpay-iben-darel.web.app).")
        print("   Mesin-mesin akan terus berstatus ONLINE (Hijau) selama script ini berjalan.\n")

        # Snapshot listeners for incoming requests
        def on_snapshot(doc_snapshot, changes, read_time):
            for change in changes:
                doc = change.document.to_dict() or {}
                mid = change.document.id
                st = doc.get("status")
                amt = doc.get("amount", 0)
                if st == "waiting_tap":
                    print(f"\n🔔 [REQUEST KASIR] Mesin [{mid}] diminta TAP KARTU untuk tagihan Rp {amt:,.0f}!")
                    print("   Ketik 't' lalu tekan Enter untuk tap kartu!")
                elif st == "waiting_uid":
                    print(f"\n🔔 [REQUEST APP] Mesin [{mid}] diminta SCAN KARTU (Top-up / Pendaftaran)!")
                    print("   Ketik 't' lalu tekan Enter untuk scan kartu!")

        for mid in mids:
            db.collection("machine_commands").document(mid).on_snapshot(on_snapshot)

        current_machine_id = mids[0]
        while True:
            print("\nAksi:")
            print(f"  [t] Tap kartu ke mesin [{current_machine_id}]")
            print("  [g] Ganti target mesin tap")
            print("  [r] Reset semua mesin ke idle")
            print("  [q] Keluar")
            act = input("> ").strip().lower()

            if act == "t":
                uid = pick_student_card(students)
                if uid:
                    simulate_nfc_tap(current_machine_id, uid)
                    # Refresh students saldo
                    students = get_registered_students()
            elif act == "g":
                print("Pilih target mesin tap:")
                for i, m in enumerate(machines):
                    print(f"  [{i+1}] {m.get('nama', m['id'])} ({m['id']})")
                sel = input("Nomor: ").strip()
                try:
                    current_machine_id = machines[int(sel) - 1]["id"]
                    print(f"✅ Target tap diubah ke: {current_machine_id}")
                except Exception:
                    print("Pilihan tidak valid.")
            elif act == "r":
                for m in mids:
                    reset_machine(m)
            elif act == "q":
                stop_event.set()
                print("Simulator berhenti.")
                break
        return

    # Single machine mode
    machine = machines[choice - 1]
    machine_id = machine["id"]
    tujuan = machine.get("tujuan", "kasir")
    print(f"\n✅ Mesin dipilih: {machine.get('nama', machine_id)} (id: {machine_id})")

    hb_thread = threading.Thread(target=send_heartbeat_single, args=(machine_id, stop_event), daemon=True)
    hb_thread.start()
    print("💚 Heartbeat aktif — status mesin di aplikasi HP/Web akan ONLINE (Hijau)!\n")

    # Real-time listener
    def on_single_snapshot(doc_snapshot, changes, read_time):
        for change in changes:
            doc = change.document.to_dict() or {}
            st = doc.get("status")
            amt = doc.get("amount", 0)
            if st == "waiting_tap":
                print(f"\n🔔 [REQUEST KASIR] Tagihan masuk: Rp {amt:,.0f}!")
                print("   Tekan [1] untuk langsung tap kartu siswa!")
            elif st == "waiting_uid":
                print(f"\n🔔 [REQUEST SCAN] Aplikasi meminta scan kartu UID!")
                print("   Tekan [1] untuk langsung scan kartu siswa!")

    db.collection("machine_commands").document(machine_id).on_snapshot(on_single_snapshot)

    while True:
        print("\nAksi:")
        print("  [1] Simulasi NFC Tap (Pilih Kartu Siswa)")
        print("  [2] Reset mesin ke idle")
        print("  [3] Keluar")
        act = input("> ").strip()

        if act == "1":
            uid = pick_student_card(students)
            if uid:
                simulate_nfc_tap(machine_id, uid)
                students = get_registered_students()
        elif act == "2":
            reset_machine(machine_id)
        elif act == "3":
            stop_event.set()
            print("Simulator berhenti.")
            break


if __name__ == "__main__":
    main()
