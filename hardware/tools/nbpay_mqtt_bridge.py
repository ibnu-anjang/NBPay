import firebase_admin
from firebase_admin import credentials, firestore
import paho.mqtt.client as mqtt
import threading
import time
import json
import ssl
import sys
import os

# --- CONFIGURATION ---
MACHINE_ID = os.environ.get("MACHINE_ID", "kantin_01")
SERVICE_ACCOUNT_KEY = "nbpay-55455-firebase-adminsdk-fbsvc-a8ce26b630.json"

MQTT_BROKER = "nbpay.pkk.darell.my.id"
MQTT_PORT = 8883

TOPIC_CMD_ESP32 = f"esp32/{MACHINE_ID}/commands"
TOPIC_STATUS_ESP32 = f"esp32/{MACHINE_ID}/status"
TOPIC_SCAN_ESP32 = f"esp32/{MACHINE_ID}/scan"

# --- INIT FIREBASE ---
try:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    machine_ref = db.collection("machine_commands").document(MACHINE_ID)
except Exception as e:
    print(f"🔥 Error initializing Firebase: {e}")
    sys.exit(1)

# --- GLOBALS ---
current_status = None
current_tujuan = None

def on_connect(client, userdata, flags, rc):
    print(f"📡 Connected to MQTT Broker with result code {rc}")
    client.subscribe(TOPIC_STATUS_ESP32)
    client.subscribe(TOPIC_SCAN_ESP32)

def on_message(client, userdata, msg):
    topic = msg.topic
    payload = msg.payload.decode('utf-8')
    
    if topic == TOPIC_STATUS_ESP32:
        try:
            data = json.loads(payload)
            # ESP32 sends {"status":"online", "uptime_sec":123, "free_heap":456}
            print(f"💓 Heartbeat received from ESP32: {payload}")
            machine_ref.update({"last_heartbeat": firestore.SERVER_TIMESTAMP})
        except json.JSONDecodeError:
            print("❌ Invalid JSON in status payload")
            
    elif topic == TOPIC_SCAN_ESP32:
        # ESP32 sends raw UID string, e.g. "A1B2C3D4"
        uid = payload.strip().upper()
        print(f"📲 NFC Tap received from ESP32: UID={uid}")
        if uid:
            # According to HARDWARE_DOCS.md, we just write last_uid.
            # If mode is cek_saldo, we also write status="waiting_check"
            # But the ESP32 can also just tell us it tapped, and we determine mode based on local state.
            
            update_data = {"last_uid": uid}
            if current_tujuan == "cek_saldo" and current_status == "idle":
                update_data["status"] = "waiting_check"
            
            try:
                machine_ref.update(update_data)
                print(f"✅ Forwarded tap to Firestore: {update_data}")
            except Exception as e:
                print(f"❌ Error updating Firestore: {e}")

# --- INIT MQTT ---
mqtt_client = mqtt.Client(client_id=f"nbpay_bridge_{MACHINE_ID}")
mqtt_client.on_connect = on_connect
mqtt_client.on_message = on_message

# SSL setup for port 8883 (MQTTS)
mqtt_client.tls_set(cert_reqs=ssl.CERT_NONE) # Use proper CA bundle in production
mqtt_client.tls_insecure_set(True)

def connect_mqtt():
    try:
        mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        mqtt_client.loop_start()
    except Exception as e:
        print(f"❌ Failed to connect to MQTT: {e}")
        sys.exit(1)

# --- FIREBASE LISTENER ---
def on_snapshot(doc_snapshot, changes, read_time):
    global current_status, current_tujuan
    for doc in doc_snapshot:
        data = doc.to_dict()
        if not data:
            continue
            
        status = data.get("status", "idle")
        tujuan = data.get("tujuan", "kasir")
        nama_result = data.get("nama_result", "")
        saldo_result = data.get("saldo_result", 0)
        amount = data.get("amount", 0)
        
        current_status = status
        current_tujuan = tujuan
        
        # Build command payload for ESP32
        # Format: status|tujuan|amount|nama_result|saldo_result
        cmd_payload = f"{status}|{tujuan}|{amount}|{nama_result}|{saldo_result}"
        
        print(f"🔄 State update from Firestore: {cmd_payload}")
        mqtt_client.publish(TOPIC_CMD_ESP32, cmd_payload)

def main():
    print("=" * 50)
    print(f"🚀 Starting NBPay MQTT-Firebase Bridge for [{MACHINE_ID}]")
    print("=" * 50)
    
    connect_mqtt()
    
    # Watch Firestore
    doc_watch = machine_ref.on_snapshot(on_snapshot)
    
    try:
        # Keep main thread alive
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Stopping bridge...")
        mqtt_client.loop_stop()
        mqtt_client.disconnect()
        doc_watch.unsubscribe()

if __name__ == "__main__":
    main()
