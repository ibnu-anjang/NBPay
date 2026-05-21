"""
NBPay Machine Simulator
=======================
Script ini mensimulasikan perilaku mesin hardware NBPay.
Gunakan untuk testing integrasi Firebase sebelum hardware asli jadi.

Requirements:
    pip install firebase-admin

Usage:
    python machine_simulator.py

Pastikan file serviceAccountKey.json ada di folder yang sama.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import threading
import time
import sys

# ─── CONFIG ───────────────────────────────────────────────────────────────────
SERVICE_ACCOUNT_KEY = "nbpay-55455-firebase-adminsdk-fbsvc-196ab6c4fb.json"  # jangan rename file ini
# ──────────────────────────────────────────────────────────────────────────────

cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
firebase_admin.initialize_app(cred)
db = firestore.client()


def get_machines():
    docs = db.collection("machine_commands").stream()
    return [{"id": d.id, **d.to_dict()} for d in docs]


def print_machines(machines):
    print("\n=== Daftar Mesin ===")
    for i, m in enumerate(machines):
        tujuan = m.get("tujuan", "-")
        status = m.get("status", "idle")
        print(f"  [{i+1}] {m['nama']} | id: {m['id']} | tujuan: {tujuan} | status: {status}")
    print()


def send_heartbeat(machine_id: str, stop_event: threading.Event):
    """Kirim heartbeat ke Firestore setiap 30 detik."""
    while not stop_event.is_set():
        db.collection("machine_commands").document(machine_id).update({
            "last_heartbeat": firestore.SERVER_TIMESTAMP
        })
        print(f"  💓 Heartbeat dikirim [{machine_id}]")
        stop_event.wait(30)


def simulate_nfc_tap(machine_id: str, tujuan: str, uid_kartu: str):
    """Simulasi siswa menempel kartu ke NFC reader."""
    ref = db.collection("machine_commands").document(machine_id)

    if tujuan == "cek_saldo":
        ref.set({
            "status": "waiting_check",
            "last_uid": uid_kartu,
        }, merge=True)
        print(f"  📲 NFC tap → uid={uid_kartu} | status: waiting_check")

        # Tunggu app balas dengan showing_saldo atau error
        print("  ⏳ Menunggu respons dari app...")
        for _ in range(20):  # max 10 detik
            time.sleep(0.5)
            doc = ref.get().to_dict()
            status = doc.get("status")
            if status == "showing_saldo":
                nama = doc.get("nama_result", "?")
                saldo = doc.get("saldo_result", 0)
                print(f"\n  ✅ Tampilkan di layar mesin:")
                print(f"     Halo, {nama}!")
                print(f"     Saldo kamu: Rp {saldo:,.0f}")
                time.sleep(5)
                # Reset
                ref.set({
                    "status": "idle",
                    "last_uid": firestore.DELETE_FIELD,
                    "saldo_result": firestore.DELETE_FIELD,
                    "nama_result": firestore.DELETE_FIELD,
                }, merge=True)
                print("  🔄 Mesin reset ke idle")
                return
            elif status == "error":
                pesan = doc.get("nama_result", "Kartu tidak dikenal")
                print(f"\n  ❌ Error: {pesan}")
                time.sleep(3)
                ref.set({"status": "idle"}, merge=True)
                return
        print("  ⏰ Timeout — tidak ada respons dari app")

    elif tujuan == "kasir":
        ref.set({"last_uid": uid_kartu}, merge=True)
        print(f"  📲 NFC tap → uid={uid_kartu} (menunggu app proses bayar)")

        print("  ⏳ Menunggu respons dari app...")
        for _ in range(30):  # max 15 detik
            time.sleep(0.5)
            doc = ref.get().to_dict()
            status = doc.get("status")
            if status == "success":
                print("  ✅ Pembayaran berhasil!")
                time.sleep(3)
                return
            elif status == "error":
                print("  ❌ Gagal! Saldo tidak cukup atau kartu tidak dikenal")
                time.sleep(3)
                return
        print("  ⏰ Timeout — tidak ada respons dari app")

    elif tujuan == "topup_daftar":
        ref.set({"last_uid": uid_kartu}, merge=True)
        print(f"  📲 NFC tap → uid={uid_kartu} (dikirim ke app untuk topup/daftar)")


def reset_machine(machine_id: str):
    db.collection("machine_commands").document(machine_id).set({
        "status": "idle",
        "last_uid": firestore.DELETE_FIELD,
        "saldo_result": firestore.DELETE_FIELD,
        "nama_result": firestore.DELETE_FIELD,
    }, merge=True)
    print(f"  🔄 Mesin [{machine_id}] direset ke idle")


def main():
    print("=" * 50)
    print("  NBPay Machine Simulator")
    print("=" * 50)

    machines = get_machines()
    if not machines:
        print("❌ Tidak ada mesin terdaftar di Firestore.")
        print("   Daftarkan mesin dulu dari admin app.")
        sys.exit(1)

    print_machines(machines)

    # Pilih mesin
    try:
        choice = int(input("Pilih mesin [nomor]: ")) - 1
        machine = machines[choice]
    except (ValueError, IndexError):
        print("Pilihan tidak valid.")
        sys.exit(1)

    machine_id = machine["id"]
    tujuan = machine.get("tujuan", "kasir")
    print(f"\n✅ Mesin dipilih: {machine['nama']} (tujuan: {tujuan})")

    # Start heartbeat
    stop_event = threading.Event()
    hb_thread = threading.Thread(target=send_heartbeat, args=(machine_id, stop_event), daemon=True)
    hb_thread.start()
    print("💚 Heartbeat aktif (setiap 30 detik)\n")

    # Menu interaktif
    while True:
        print("\nAksi:")
        print("  [1] Simulasi NFC tap")
        print("  [2] Reset mesin ke idle")
        print("  [3] Ganti mesin")
        print("  [4] Keluar")
        action = input("> ").strip()

        if action == "1":
            uid = input("  UID kartu (cek di Firestore > users > doc ID): ").strip()
            if uid:
                simulate_nfc_tap(machine_id, tujuan, uid)
            else:
                print("  UID tidak boleh kosong")

        elif action == "2":
            reset_machine(machine_id)

        elif action == "3":
            stop_event.set()
            machines = get_machines()
            print_machines(machines)
            try:
                choice = int(input("Pilih mesin [nomor]: ")) - 1
                machine = machines[choice]
                machine_id = machine["id"]
                tujuan = machine.get("tujuan", "kasir")
                print(f"✅ Ganti ke: {machine['nama']} (tujuan: {tujuan})")
                stop_event = threading.Event()
                hb_thread = threading.Thread(target=send_heartbeat, args=(machine_id, stop_event), daemon=True)
                hb_thread.start()
                print("💚 Heartbeat aktif\n")
            except (ValueError, IndexError):
                print("Pilihan tidak valid.")

        elif action == "4":
            stop_event.set()
            print("Simulator dihentikan.")
            break


if __name__ == "__main__":
    main()
