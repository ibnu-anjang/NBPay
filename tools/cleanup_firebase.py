"""
Hapus data Firebase:
- users dengan role 'siswa'
- semua dokumen di koleksi 'transactions'

Simpan: users (penjual, admin), machine_commands, settings, menus
"""
import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_ACCOUNT = "/home/iben/NBPay/nbpay-55455-firebase-adminsdk-fbsvc-196ab6c4fb.json"

cred = credentials.Certificate(SERVICE_ACCOUNT)
firebase_admin.initialize_app(cred)
db = firestore.client()


def delete_in_batches(query, label):
    total = 0
    while True:
        docs = list(query.limit(400).stream())
        if not docs:
            break
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()
        total += len(docs)
        print(f"  Dihapus {total} {label}...")
    return total


print("=== Cleanup Firebase NBPay ===\n")

# 1. Hapus users dengan role siswa
print("1. Menghapus users (role=siswa)...")
query = db.collection("users").where("role", "==", "siswa")
n = delete_in_batches(query, "siswa users")
print(f"   Total: {n} dokumen dihapus\n")

# 2. Hapus semua transactions
print("2. Menghapus semua transactions...")
query = db.collection("transactions")
n = delete_in_batches(query, "transactions")
print(f"   Total: {n} dokumen dihapus\n")

print("=== Selesai! ===")
print("Yang tersisa: users (penjual & admin), machine_commands, settings, menus")
