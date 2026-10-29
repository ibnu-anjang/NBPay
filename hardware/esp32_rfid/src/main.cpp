#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <WiFiManager.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>
#include <Preferences.h>
#include <esp_idf_version.h>
#include <esp_task_wdt.h>
#include <ArduinoJson.h>
#include <time.h>

#define ENABLE_SERVICE_AUTH
#define ENABLE_FIRESTORE
#include <FirebaseClient.h>

// --- PIN DEFINITIONS FOR ESP32-S3 ---
// RFID SPI Pins
#define SPI_SCK  12
#define SPI_MISO 13
#define SPI_MOSI 11
#define RFID_CS   10
#define RFID_RST  9

// TFT Pins (Dipisah agar tidak tumpang tindih dengan RFID)
#define TFT_SDA   5  // Hubungkan pin SDA (MOSI) TFT ke GPIO 5
#define TFT_SCK   6  // Hubungkan pin SCK TFT ke GPIO 6
#define TFT_CS    14
#define TFT_RST   15
#define TFT_DC    16
#define TFT_BL    17

#define BUZZER_PIN 21

// --- PUSH BUTTONS PINS (15 PIN SETUP) ---
// Tombol 1
#define BTN1_VCC 1
#define BTN1_GND 2
#define BTN1_OUT 4
// Tombol 2
#define BTN2_VCC 7
#define BTN2_GND 8
#define BTN2_OUT 18
// Tombol 3
#define BTN3_VCC 38
#define BTN3_GND 39
#define BTN3_OUT 40
// Tombol 4
#define BTN4_VCC 41
#define BTN4_GND 42
#define BTN4_OUT 45
// Tombol 5 (Pin 0 diganti ke Pin 3)
#define BTN5_VCC 47
#define BTN5_GND 48
#define BTN5_OUT 3

// --- CONFIG ---
String MACHINE_ID = "kantin_01"; // Default, can be loaded from Preferences

// --- FIREBASE CONFIG ---
#define FIREBASE_PROJECT_ID "nbpay-55455"
#define FIREBASE_CLIENT_EMAIL "firebase-adminsdk-fbsvc@nbpay-55455.iam.gserviceaccount.com"
const char PRIVATE_KEY[] PROGMEM = "-----BEGIN PRIVATE KEY-----\n"
"MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDX88drKE6eTWYx\n"
"2w+dWw0Yi8VkB5t2kp0xnLfg9NuNPuvyfNOE2JdlNJ808FGZMF7gAL6+I1nYr9dF\n"
"13+ppMjtDlR//K/4OOtO/HvRqARrEuH2BfuJHaeUhL4elEd/TCi4gNN3h7ukvc9I\n"
"rZ5TJeGviUlZD7k2mVnz3RDYVfPFUl0BdtXumzWPVGKWjfWFKMx+9BD4I5veNlfn\n"
"tOmMa3n6ZLMcEoGgYdWtaWJhpIVsh+pwQ+mJyRvb0O0vllSrgf366GcAfByTUiGv\n"
"20Ok8iNzEgROcmaoITdj2HQSVXXEkFn/N0VLBcEAoo4oW7N84hI8KZsStmquyHhV\n"
"YRoFSlnfAgMBAAECggEAC2Kbq7obHvxx/ASSbQIyYri9EOTXx5IQ6IncezyINgj7\n"
"CTSXNY9HuBBkqQwBzqOUCkJFIXgdUgUUl+bgdlICPSvpZ5ABD633Ne8DcM5nYTpv\n"
"IE3jcNtX4kbMpocRwpPXfRa0T2kgCvOY3I+OuSUrogSzvGwi9c5y8B5CYkLHJdV0\n"
"15x1MX9ZZicapFqUJGdIYeJUDhEipn/aYRWxeYcei/DhaQVV8v600oFBNzxYMcIT\n"
"hcLzb9wQEMuQx6C0slbmovVk+xAYT0de8sVLokx8wsfq7ppZU7yISsJaE5N8wHvu\n"
"6QBANptOiICF9BkNSFDKZGvXkBm0wFc+Ll49gUsJdQKBgQDtpjf+nk4vDp3eVkAo\n"
"wS5yvKRH2FtWDruKBYllveprdUIrmvk5Latb+WqK1XvkR7fy0tjT2ZqnYI6+1l9Q\n"
"8OQ8indn9Fl+KQDDsoJ9LlJIbSQbVTCwS+maw8xDhvgAcvaalGJjLfMeyDE/Z5/L\n"
"eSbK33dgvoi/c9+twi54PmuNFQKBgQDooKjkukYeKaRw52oNy33RZI6xuAbzYrM7\n"
"9slv+6f8jF0+8ESROAuPEB+DNPXbYoLKw6bWZy0dUqV7v3Z8wTpWnxR46DhAMSrP\n"
"ZsxwmJ+nT9KkCrvh/noFUff/2Lyt3YjAX371MMFLiOPR7HXP1Vg2/AN4iIRLF6Ra\n"
"el7WUWHQIwKBgQC4wQ6rLltODikBX0CF7pmzraByEmv/nXiDNwa4SEtku0Z0LAkx\n"
"QKYF3QPNZ2bn9DG339+d44BuO4z+JB76CC0IPAXUlYy1nh7wBWmY9FgX4nG9ph8y\n"
"D/JO1YWJwfYwMzAwwMc0n9ZwyeYvitoaD9fuxIhEeBxL60OsDFigNrbaeQKBgQDo\n"
"mWPmuB5OIIMs5SbUvkiCq1JGfuRsTZ87cOo/j1iLm+nMeb+FmI1uMcfgkH7YKqru\n"
"hSz3qligvjd7AZk+6pIjdJKqxj8gaEkO8hGu79yLFbRfk+AC+0kUsr4PUq5uBlmr\n"
"SJEQJvzPQwPQreeqtP6sk9YAmjf1QaFzWnIjR2JPEwKBgFrwFuqEwDgNHRU8NG1L\n"
"IU2DdVECVt4aLBKZVqny1BSrBqlTLulGsMH0nMlNVEy2FHYeEslffSbqyu+8SHgl\n"
"6gcNaJqGsOw8nL3BcsUg5/QLAH87ZeqRyTLql7YPPJzQzwiO7Q/5Atu3X9Fk4kr9\n"
"Yr7n2lKQzJ/qya/6IaJbAUOQ\n"
"-----END PRIVATE KEY-----\n";

// --- OBJECT INSTANTIATIONS ---
MFRC522 rfid(RFID_CS, RFID_RST);
// Menggunakan bit-bang (Software) SPI untuk TFT agar tidak perlu berbagi pin dengan RFID
Adafruit_ST7735 tft = Adafruit_ST7735(TFT_CS, TFT_DC, TFT_SDA, TFT_SCK, TFT_RST);
Preferences preferences;

// Firebase objects
WiFiClientSecure ssl_client;
using AsyncClient = AsyncClientClass;
AsyncClient aClient(ssl_client);

void timeStatusCB(uint32_t &ts) {
    ts = (uint32_t)time(nullptr);
}

ServiceAuth sa_auth(timeStatusCB, FIREBASE_CLIENT_EMAIL, FIREBASE_PROJECT_ID, PRIVATE_KEY);
FirebaseApp app;
Firestore::Documents Docs;

// --- HARGA MENU & CONFIG POS ---
#define HARGA_INDOMIE 6000
#define HARGA_SEDAAP  6000
#define HARGA_SUKSESS 8000 // Asumsi
#define HARGA_TELUR   2000 // Asumsi

// --- LOCAL STATE MACHINE ---
int currentMode = 0; 
// 0: Siaga, 1: Cek Saldo, 2: Transaksi, 4: Top-up
unsigned long modeTimeout = 0;

// Variabel Transaksi
long totalPesanan = 0;
int jumlahItem = 0;
int currentOrder[4] = {0,0,0,0}; // 0:Indomie, 1:Sedaap, 2:Suksess, 3:Telur

// Sinkronisasi Firebase
String fbStatus = "idle"; 
String fbTujuan = "";
String defaultTujuan = ""; // Menyimpan role default mesin
String fbNamaResult = "";
long fbSaldoResult = 0;
bool firebaseInitialized = false;
String lastFirebaseError = "";

unsigned long lastBtnPress = 0;

// Timers
unsigned long lastHeartbeat = 0;
unsigned long lastActivity = 0;
unsigned long lastPoll = 0;

// Watchdog
#define WDT_TIMEOUT 15 

// --- COLOR THEME (Adafruit_GFX RGB565) ---
#define COLOR_BG      0x0000 // Black
#define COLOR_CYAN    0x07FF
#define COLOR_BLUE_BG 0x01E9
#define COLOR_GREEN   0x07E0
#define COLOR_RED     0xF800
#define COLOR_YELLOW  0xFFE0
#define COLOR_GRAY    0x7BEF

// --- HARDWARE FUNCTIONS ---
void playBeep(int type) {
  int duration = 0;
  if (type == 1) duration = 50;
  else if (type == 2) duration = 150;
  else if (type == 3) {
    playBeep(1);
    delay(100);
    playBeep(1);
    return;
  }
  else if (type == 4) duration = 800;

  pinMode(BUZZER_PIN, OUTPUT);
  long delayVal = 250; // 250 microseconds (2000 Hz)
  if (type == 4) delayVal = 500; // 500 microseconds (1000 Hz)
  
  long numCycles = (long)duration * 1000L / (delayVal * 2);
  for (long i = 0; i < numCycles; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delayMicroseconds(delayVal);
    digitalWrite(BUZZER_PIN, LOW);
    delayMicroseconds(delayVal);
  }
  digitalWrite(BUZZER_PIN, LOW);
}

// --- DISPLAY UPDATE ---
String formatCurrency(long value) {
  bool isNegative = value < 0;
  String strVal = String(isNegative ? -value : value);
  int len = strVal.length();
  if (len <= 3) return (isNegative ? "-" : "") + strVal;
  
  String result = "";
  int count = 0;
  for (int i = len - 1; i >= 0; i--) {
    result = strVal[i] + result;
    count++;
    if (count % 3 == 0 && i != 0) {
      result = "." + result;
    }
  }
  return (isNegative ? "-" : "") + result;
}

void updateDisplay() {
  tft.fillScreen(COLOR_BG);
  tft.drawRect(0, 0, tft.width(), tft.height(), COLOR_GRAY); // Outer Border
  
  tft.setTextSize(1);
  tft.setCursor(5, 5);
  tft.setTextColor(COLOR_CYAN);
  
  if (currentMode == 0) {
    if (fbTujuan == "cek_saldo") {
        tft.println("CEK SALDO");
        tft.drawLine(0, 15, tft.width(), 15, COLOR_GRAY);
        tft.setTextColor(ST7735_WHITE);
        tft.setCursor(10, 50); tft.setTextSize(2);
        tft.println("TAP KARTU");
    } else if (fbTujuan == "topup_daftar") {
        tft.println("DAFTAR & TOP-UP");
        tft.drawLine(0, 15, tft.width(), 15, COLOR_GRAY);
        tft.setTextColor(ST7735_WHITE);
        tft.setCursor(10, 50); tft.setTextSize(2);
        if (fbStatus == "waiting_uid") {
           tft.println("TAP KARTU");
        } else {
           tft.setCursor(4, 50);
           tft.println("TUNGGU APP");
        }
    } else {
        tft.println("KANTIN BABEH - SIAP");
        tft.drawLine(0, 15, tft.width(), 15, COLOR_GRAY);
        tft.setTextColor(ST7735_WHITE);
        tft.setCursor(10, 50); tft.setTextSize(2);
        tft.println("TAP KARTU");
        tft.setCursor(20, 80); tft.setTextSize(1);
        tft.println("Atau Pilih Menu");
    }
  } 
  else if (currentMode == 1) {
    tft.println("CEK SALDO MANDIRI");
    tft.drawLine(0, 15, tft.width(), 15, COLOR_GRAY);
    
    if (fbStatus == "idle") {
      tft.setTextColor(ST7735_WHITE);
      tft.setCursor(10, 50); tft.setTextSize(2);
      tft.println("TAP KARTU");
    }
    else if (fbStatus == "waiting_check") {
      tft.setTextColor(COLOR_YELLOW);
      tft.setCursor(10, 50); tft.println("Mengecek saldo...");
    } else if (fbStatus == "showing_saldo" || fbStatus == "success") {
      tft.setTextColor(ST7735_WHITE);
      tft.setCursor(10, 30); tft.print("Halo, "); tft.println(fbNamaResult);
      tft.setTextColor(COLOR_GREEN);
      String balStr = "Rp " + formatCurrency(fbSaldoResult);
      tft.setCursor(10, 50);
      if (balStr.length() > 10) {
        tft.setTextSize(1);
        tft.setCursor(10, 54);
      } else {
        tft.setTextSize(2);
      }
      tft.println(balStr);
    } else {
      tft.setTextColor(COLOR_RED);
      tft.setCursor(10, 50); tft.println("Gagal Cek Saldo!");
    }
  }
  else if (currentMode == 2) {
    tft.println("KASIR - TRANSAKSI");
    tft.drawLine(0, 15, tft.width(), 15, COLOR_GRAY);
    
    if (fbStatus == "idle") {
      tft.setTextColor(ST7735_WHITE);
      tft.setCursor(10, 30); tft.print("Item: "); tft.println(jumlahItem);
      tft.setTextColor(COLOR_YELLOW);
      String orderStr = "Rp " + formatCurrency(totalPesanan);
      tft.setCursor(10, 50);
      if (orderStr.length() > 10) {
        tft.setTextSize(1);
        tft.setCursor(10, 54);
      } else {
        tft.setTextSize(2);
      }
      tft.println(orderStr);
      tft.setTextSize(1); tft.setTextColor(COLOR_CYAN);
      tft.setCursor(13, 90); tft.println(">>> TAP KARTU <<<");
    } 
    else if (fbStatus == "waiting_tap") {
      tft.setTextColor(ST7735_WHITE);
      tft.setCursor(10, 30); tft.println("Instruksi dari App:");
      tft.setTextColor(COLOR_YELLOW);
      String orderStr = "Rp " + formatCurrency(totalPesanan);
      tft.setCursor(10, 50);
      if (orderStr.length() > 10) {
        tft.setTextSize(1);
        tft.setCursor(10, 54);
      } else {
        tft.setTextSize(2);
      }
      tft.println(orderStr);
      tft.setTextSize(1); tft.setTextColor(COLOR_CYAN);
      tft.setCursor(13, 90); tft.println(">>> TAP KARTU <<<");
    }
    else if (fbStatus == "waiting_process") {
      tft.setTextColor(COLOR_YELLOW);
      tft.setCursor(10, 50); tft.println("Memproses bayar...");
    }
    else if (fbStatus == "success") {
      tft.fillScreen(COLOR_GREEN);
      tft.setTextColor(COLOR_BG);
      tft.setCursor(20, 40); tft.setTextSize(2); tft.println("SUKSES!");
      tft.setCursor(10, 70); tft.setTextSize(1); tft.print("Sisa: Rp "); tft.println(formatCurrency(fbSaldoResult));
      playBeep(3);
    }
    else if (fbStatus == "error") {
      tft.fillScreen(COLOR_RED);
      tft.setTextColor(ST7735_WHITE);
      tft.setCursor(20, 40); tft.setTextSize(2); tft.println("GAGAL!");
      tft.setCursor(10, 70); tft.setTextSize(1); tft.println(fbNamaResult);
      playBeep(4);
    }
  }
  else if (currentMode == 4) {
    tft.println("TOP-UP & DAFTAR");
    tft.drawLine(0, 15, tft.width(), 15, COLOR_GRAY);
    if (fbStatus == "idle") {
        tft.setTextColor(ST7735_WHITE);
        tft.setCursor(10, 50); tft.println("Tunggu dari App...");
    }
    else if (fbStatus == "waiting_uid") {
        tft.setTextColor(ST7735_WHITE);
        tft.setCursor(10, 50); tft.setTextSize(2); tft.println("TAP KARTU");
    } else if (fbStatus == "success") {
        tft.setTextColor(COLOR_GREEN);
        tft.setCursor(28, 50); tft.setTextSize(2); tft.println("UID OK");
        tft.setCursor(30, 80); tft.setTextSize(1); tft.println("Terbaca!");
        playBeep(3);
    }
  }

  // Draw Firebase Status Bar
  if (fbStatus != "success" && fbStatus != "error" && fbStatus != "showing_saldo") {
    tft.fillRect(0, tft.height() - 13, tft.width(), 13, COLOR_BG);
    tft.setCursor(5, tft.height() - 10); tft.setTextSize(1); 
    if (firebaseInitialized && app.ready()) {
      tft.setTextColor(COLOR_GREEN); tft.print("FB CONNECTED");
    } else {
      tft.setTextColor(COLOR_YELLOW);
      time_t now = time(nullptr);
      if (now < 24 * 3600) {
        tft.print("NTP SYNC ERR");
      } else if (lastFirebaseError.length() > 0) {
        tft.printf("ERR: %s", lastFirebaseError.substring(0, 13).c_str());
      } else {
        static unsigned long lastDnsCheck = 0;
        static bool dnsOk = false;
        if (millis() - lastDnsCheck > 5000 || lastDnsCheck == 0) {
          lastDnsCheck = millis();
          IPAddress ip;
          dnsOk = WiFi.hostByName("oauth2.googleapis.com", ip);
        }
        if (!dnsOk) {
          tft.print("NO INTERNET");
        } else {
          tft.print("FB AUTH...");
        }
      }
    }
  }
}

// --- NETWORK FUNCTIONS ---
void setup_wifi() {
  tft.fillScreen(COLOR_BG);
  tft.setTextColor(COLOR_CYAN);
  tft.setTextSize(2);
  tft.setCursor(20, 30);
  tft.println("NBPAY EDC");
  
  tft.setTextColor(ST7735_WHITE);
  tft.setTextSize(1);
  tft.setCursor(20, 60);
  tft.println("Booting System...");
  delay(1000);
  
  esp_task_wdt_delete(NULL); 

  WiFiManager wm;
  bool res = wm.autoConnect("NBPAY-EDC-AP");

  esp_task_wdt_add(NULL); 

  if(!res) {
    Serial.println("[ERROR] WiFiManager failed to connect to WiFi! System will restart in 3 seconds.");
    tft.println("Failed to connect");
    delay(3000);
    ESP.restart();
  }

  Serial.println("[INFO] WiFi connected successfully.");
  tft.fillScreen(COLOR_GREEN);
  tft.setTextColor(COLOR_BG);
  tft.setTextSize(2);
  tft.setCursor(20, 50);
  tft.println("WIFI OK");
  playBeep(3); 
  delay(1000);
}

void asyncCB(AsyncResult &aResult) {
  if (aResult.isEvent()) {
    Serial.printf("[INFO] Firebase Event: %s\n", aResult.eventLog().message().c_str());
  }
  if (aResult.isDebug()) {
    Serial.printf("[DEBUG] Firebase: %s\n", aResult.debug().c_str());
  }
  if (aResult.isError()) {
    Serial.printf("[ERROR] Firebase Error: %s (code: %d)\n", aResult.error().message().c_str(), aResult.error().code());
    lastFirebaseError = aResult.error().message().c_str();
    updateDisplay();
  }
}

void pollFirestore() {
  unsigned long currentPollInterval = (fbStatus == "idle") ? 5000 : 2000; 
  if (millis() - lastPoll < currentPollInterval) return; 
  lastPoll = millis();

  if (!app.ready()) return;

  String path = "machine_commands/" + MACHINE_ID;
  String payload = Docs.get(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), path, GetDocumentOptions());
  
  if (aClient.lastError().code() == 0) {
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, payload);
    if (!error) {
      JsonObject fields = doc["fields"];
      String newStatus = fields["status"]["stringValue"] | "idle";

      String fetchedTujuan = fields["tujuan"]["stringValue"] | "kasir";
      if (fetchedTujuan != "") {
        fbTujuan = fetchedTujuan;
        if (defaultTujuan == "") {
          defaultTujuan = fetchedTujuan; // Simpan role default saat pertama kali booting
        }
      }

      long remoteAmount = 0;
      if (!fields["amount"]["integerValue"].isNull()) {
        remoteAmount = fields["amount"]["integerValue"].as<long>();
      } else if (!fields["amount"]["doubleValue"].isNull()) {
        remoteAmount = fields["amount"]["doubleValue"].as<long>();
      }

      // Debugging logs
      Serial.print("[INFO] pollFirestore -> Status: "); Serial.print(newStatus);
      Serial.print(" | Tujuan: "); Serial.println(fbTujuan);

      if (fbStatus == "idle" && newStatus == "idle") {
        if (fbTujuan == "cek_saldo" && currentMode != 1) { 
            Serial.println("[INFO] Switched to Mode 1 (Cek Saldo)");
            currentMode = 1; updateDisplay(); 
        }
        else if (fbTujuan == "topup_daftar" && currentMode != 4) { 
            Serial.println("[INFO] Switched to Mode 4 (Topup/Daftar)");
            currentMode = 4; updateDisplay(); 
        }
        else if (fbTujuan == "kasir" && currentMode != 0) { 
            Serial.println("[INFO] Switched to Mode 0 (Kasir)");
            currentMode = 0; updateDisplay(); 
        }
      }

      if (fbTujuan == "kasir" && newStatus == "waiting_tap" && fbStatus != "waiting_tap" && fbStatus != "waiting_process") {
          currentMode = 2; 
          fbStatus = newStatus;
          totalPesanan = remoteAmount;
          updateDisplay();
      }

      if (fbTujuan == "topup_daftar" && newStatus == "waiting_uid" && fbStatus != "waiting_uid" && fbStatus != "waiting_process") {
          currentMode = 4;
          fbStatus = newStatus;
          updateDisplay();
      }
      
      if (currentMode == 1 && fbStatus == "waiting_check" && (newStatus == "showing_saldo" || newStatus == "success" || newStatus == "error")) {
        fbNamaResult = fields["nama_result"]["stringValue"] | "";
        
        if (!fields["saldo_result"]["integerValue"].isNull()) {
          fbSaldoResult = fields["saldo_result"]["integerValue"].as<long>();
        } else {
          fbSaldoResult = fields["saldo_result"]["doubleValue"].as<long>();
        }
        
        fbStatus = newStatus;
        modeTimeout = millis();
        updateDisplay();
      }
      else if (currentMode == 2 && (fbStatus == "waiting_process" || fbStatus == "waiting_tap") && (newStatus == "success" || newStatus == "error")) {
        fbNamaResult = fields["nama_result"]["stringValue"] | "";
        
        if (!fields["saldo_result"]["integerValue"].isNull()) {
          fbSaldoResult = fields["saldo_result"]["integerValue"].as<long>();
        } else {
          fbSaldoResult = fields["saldo_result"]["doubleValue"].as<long>();
        }
        
        fbStatus = newStatus;
        
        memset(currentOrder, 0, sizeof(currentOrder));
        totalPesanan = 0; jumlahItem = 0;
        modeTimeout = millis();
        updateDisplay();
      }

      if (newStatus == "idle" && fbStatus != "idle" && fbStatus != "success" && fbStatus != "error" && fbStatus != "showing_saldo") {
          fbStatus = "idle";
          if (fbTujuan == "cek_saldo") currentMode = 1;
          else if (fbTujuan == "topup_daftar") currentMode = 4;
          else currentMode = 0;
          totalPesanan = 0; jumlahItem = 0;
          memset(currentOrder, 0, sizeof(currentOrder));
          updateDisplay();
      }
    } else {
      Serial.printf("[ERROR] JSON Deserialization failed: %s\n", error.c_str());
    }
  } else {
    Serial.printf("[ERROR] pollFirestore failed: %s (code: %d)\n", aClient.lastError().message().c_str(), aClient.lastError().code());
  }
}

void sendHeartbeat() {
  if (millis() - lastHeartbeat >= 30000) {
    lastHeartbeat = millis();
    
    if (!app.ready()) return;

    String path = "machine_commands/" + MACHINE_ID;
    
    // Ambil waktu UTC saat ini dan format ke ISO-8601 (YYYY-MM-DDTHH:MM:SSZ)
    time_t now = time(nullptr);
    struct tm timeinfo;
    gmtime_r(&now, &timeinfo);
    char timeStr[30];
    strftime(timeStr, sizeof(timeStr), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
    
    // Create patch payload using FirebaseClient Document class
    Document<Values::Value> doc;
    String content = "{\"fields\":{\"last_heartbeat\":{\"timestampValue\":\"" + String(timeStr) + "\"}}}";
    doc.setContent(content.c_str()); 
    
    PatchDocumentOptions patchOptions(DocumentMask("last_heartbeat"), DocumentMask(), Precondition());
    Docs.patch(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), path, patchOptions, doc);
    
    if (aClient.lastError().code() != 0) {
      Serial.printf("[ERROR] Heartbeat error: %s (code: %d)\n", aClient.lastError().message().c_str(), aClient.lastError().code());
    } else {
      Serial.println("[INFO] Heartbeat sent successfully.");
    }
  }
}

void updateFirestoreTransactionState(String status, long amount) {
  if (!app.ready()) return;
  String path = "machine_commands/" + MACHINE_ID;
  Document<Values::Value> doc;
  
  if (status == "idle") {
    doc.setContent("{\"fields\":{\"status\":{\"stringValue\":\"idle\"}, \"amount\":{\"integerValue\":\"0\"}, \"last_uid\":{\"stringValue\":\"\"}, \"tujuan\":{\"stringValue\":\"kasir\"}}}");
    PatchDocumentOptions patchOptions(DocumentMask("status,amount,last_uid,tujuan"), DocumentMask(), Precondition());
    Docs.patch(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), path, patchOptions, doc);
  } else {
    // Saat masuk waiting_tap, kosongkan last_uid agar App Flutter dapat mendeteksi perubahan UID baru secara bersih
    doc.setContent("{\"fields\":{\"status\":{\"stringValue\":\"" + status + "\"}, \"amount\":{\"integerValue\":\"" + String(amount) + "\"}, \"tujuan\":{\"stringValue\":\"kasir\"}, \"last_uid\":{\"stringValue\":\"\"}}}");
    PatchDocumentOptions patchOptions(DocumentMask("status,amount,tujuan,last_uid"), DocumentMask(), Precondition());
    Docs.patch(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), path, patchOptions, doc);
  }

  if (aClient.lastError().code() != 0) {
    Serial.printf("[ERROR] Firestore state update failed: %s (code: %d)\n", aClient.lastError().message().c_str(), aClient.lastError().code());
  } else {
    Serial.printf("[INFO] Firestore state updated to: %s with amount: %ld\n", status.c_str(), amount);
  }
}

// --- MAIN LOGIC ---
void readButtons() {
  if (millis() - lastBtnPress < 250) return; // Debounce
  
  static bool last_b1 = false, last_b2 = false, last_b3 = false, last_b4 = false, last_b5 = false;
  
  bool cur_b1 = digitalRead(BTN1_OUT) == HIGH;
  bool cur_b2 = digitalRead(BTN2_OUT) == HIGH;
  bool cur_b3 = digitalRead(BTN3_OUT) == HIGH;
  bool cur_b4 = digitalRead(BTN4_OUT) == HIGH;
  bool cur_b5 = digitalRead(BTN5_OUT) == HIGH;

  bool b1 = cur_b1 && !last_b1;
  bool b2 = cur_b2 && !last_b2;
  bool b3 = cur_b3 && !last_b3;
  bool b4 = cur_b4 && !last_b4;
  bool b5 = cur_b5 && !last_b5;

  last_b1 = cur_b1;
  last_b2 = cur_b2;
  last_b3 = cur_b3;
  last_b4 = cur_b4;
  last_b5 = cur_b5;
  
  if (b1 || b2 || b3 || b4 || b5) {
    Serial.printf("[BUTTON] Pressed -> B1:%d, B2:%d, B3:%d, B4:%d, B5:%d\n", b1, b2, b3, b4, b5);
    lastBtnPress = millis();
    lastActivity = millis();
    playBeep(1);

    if (fbTujuan == "kasir" && (currentMode == 0 || (currentMode == 2 && (fbStatus == "idle" || fbStatus == "waiting_tap")))) {
      currentMode = 2; // Masuk mode transaksi
      bool isCancel = false;
      if (b1) { totalPesanan += HARGA_INDOMIE; jumlahItem++; currentOrder[0]++; }
      else if (b2) { totalPesanan += HARGA_SEDAAP; jumlahItem++; currentOrder[1]++; }
      else if (b3) { totalPesanan += HARGA_SUKSESS; jumlahItem++; currentOrder[2]++; }
      else if (b4) { totalPesanan += HARGA_TELUR; jumlahItem++; currentOrder[3]++; }
      else if (b5) { 
        isCancel = true;
        totalPesanan = 0; jumlahItem = 0;
        memset(currentOrder, 0, sizeof(currentOrder));
        currentMode = 0; fbStatus = "idle";
        updateFirestoreTransactionState("idle", 0);
      }
      
      if (!isCancel && totalPesanan > 0) {
        fbStatus = "waiting_tap";
        updateFirestoreTransactionState("waiting_tap", totalPesanan);
      }
      updateDisplay();
    }
  }
}

void handleRFID() {
  // Check for card presence using both REQA (standard) and WUPA (wakeup) to handle ISO 14443-4 (Flazz/Brizzi)
  byte bufferATQA[2];
  byte bufferSize = sizeof(bufferATQA);
  
  // Clear Tx/Rx mode and ModWidth to prepare for request
  rfid.PCD_WriteRegister(rfid.TxModeReg, 0x00);
  rfid.PCD_WriteRegister(rfid.RxModeReg, 0x00);
  rfid.PCD_WriteRegister(rfid.ModWidthReg, 0x26);
  
  // Try standard Request A (REQA)
  MFRC522::StatusCode result = rfid.PICC_RequestA(bufferATQA, &bufferSize);
  
  // If REQA fails, try Wakeup A (WUPA)
  if (result != MFRC522::STATUS_OK && result != MFRC522::STATUS_COLLISION) {
    result = rfid.PICC_WakeupA(bufferATQA, &bufferSize);
  }
  
  // If still no card detected, return
  if (result != MFRC522::STATUS_OK && result != MFRC522::STATUS_COLLISION) {
    return;
  }

  // Read card serial (UID)
  if (!rfid.PICC_ReadCardSerial()) return;

  if (fbStatus == "waiting_check" || fbStatus == "waiting_process" || fbStatus == "showing_saldo") {
    playBeep(4); rfid.PICC_HaltA(); rfid.PCD_StopCrypto1(); return;
  }

  lastActivity = millis();
  playBeep(2);
  
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    uid += String(rfid.uid.uidByte[i] < 0x10 ? "0" : "");
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  Serial.print("[INFO] Card Tapped: "); Serial.println(uid);

  // 1. Prioritas Top-up / Daftar (Jika sedang menunggu UID)
  if (currentMode == 4 && fbStatus == "waiting_uid") {
    if (app.ready()) {
        String path = "machine_commands/" + MACHINE_ID;
        Document<Values::Value> doc;
        doc.setContent("{\"fields\":{\"last_uid\":{\"stringValue\":\"" + uid + "\"}}}");
        PatchDocumentOptions patchOptions(DocumentMask("last_uid"), DocumentMask(), Precondition());
        Docs.patch(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), path, patchOptions, doc);
        
        if (aClient.lastError().code() != 0) {
          Serial.printf("[ERROR] Top-up registration UID patch failed: %s (code: %d)\n", aClient.lastError().message().c_str(), aClient.lastError().code());
        } else {
          Serial.println("[INFO] Top-up registration UID patched successfully.");
        }
        
        fbStatus = "success"; 
        modeTimeout = millis();
        updateDisplay();
    }
    rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
    return;
  }

  // 2. Prioritas Transaksi Kasir
  if (currentMode == 2) {
    if (fbStatus == "idle" && totalPesanan > 0) {
        fbStatus = "waiting_process";
        modeTimeout = millis(); 
        updateDisplay();
        
        if (app.ready()) {
          String path = "machine_commands/" + MACHINE_ID;
          Document<Values::Value> doc;
          doc.setContent("{\"fields\":{\"status\":{\"stringValue\":\"waiting_process\"}, \"tujuan\":{\"stringValue\":\"kasir\"}, \"amount\":{\"integerValue\":\"" + String(totalPesanan) + "\"}, \"last_uid\":{\"stringValue\":\"" + uid + "\"}}}");
          PatchDocumentOptions patchOptions(DocumentMask("status,tujuan,amount,last_uid"), DocumentMask(), Precondition());
          Docs.patch(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), path, patchOptions, doc);
          
          if (aClient.lastError().code() != 0) {
            Serial.printf("[ERROR] Transaction initialization patch failed: %s (code: %d)\n", aClient.lastError().message().c_str(), aClient.lastError().code());
          } else {
            Serial.println("[INFO] Transaction initialization patch successful.");
          }
        }
        rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
        return;
    } else if (fbStatus == "waiting_tap") {
        fbStatus = "waiting_process";
        updateDisplay();
        
        if (app.ready()) {
          String path = "machine_commands/" + MACHINE_ID;
          Document<Values::Value> doc;
          doc.setContent("{\"fields\":{\"status\":{\"stringValue\":\"waiting_process\"}, \"last_uid\":{\"stringValue\":\"" + uid + "\"}}}");
          PatchDocumentOptions patchOptions(DocumentMask("status,last_uid"), DocumentMask(), Precondition());
          Docs.patch(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), path, patchOptions, doc);
          
          if (aClient.lastError().code() != 0) {
            Serial.printf("[ERROR] Transaction card tap patch failed: %s (code: %d)\n", aClient.lastError().message().c_str(), aClient.lastError().code());
          } else {
            Serial.println("[INFO] Transaction card tap patch successful.");
          }
        }
        rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
        return;
    }
  }

  // 3. Cek Saldo Mandiri (Aktif jika role mesin adalah Cek Saldo atau kartu di-tap langsung di mode Idle Kasir)
  if (currentMode == 1 || (currentMode == 0 && fbStatus == "idle" && totalPesanan == 0)) {
    if (currentMode == 0) {
      currentMode = 1; // Ubah sementara ke mode cek saldo
    }
    fbStatus = "waiting_check";
    modeTimeout = millis(); 
    updateDisplay();
    
    if (app.ready()) {
      Serial.printf("[INFO] Cek saldo mandiri langsung dari Firestore untuk UID: %s\n", uid.c_str());
      String userPath = "users/" + uid;
      String userPayload = Docs.get(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), userPath, GetDocumentOptions());
      
      if (aClient.lastError().code() == 0) {
        JsonDocument userDoc;
        DeserializationError err = deserializeJson(userDoc, userPayload);
        if (!err && !userDoc["fields"].isNull()) {
          JsonObject uFields = userDoc["fields"];
          bool isFrozen = false;
          if (!uFields["is_frozen"].isNull()) {
            isFrozen = uFields["is_frozen"]["booleanValue"] | false;
          }
          
          if (isFrozen) {
            fbStatus = "error";
            fbNamaResult = "KARTU DIBEKUKAN!";
            fbSaldoResult = 0;
            modeTimeout = millis();
            updateDisplay();
            playBeep(4);
            Serial.println("[WARN] Kartu ini sedang dibekukan oleh pemilik.");
          } else {
            fbNamaResult = uFields["nama"]["stringValue"] | "Siswa";
            if (!uFields["saldo"]["integerValue"].isNull()) {
              fbSaldoResult = uFields["saldo"]["integerValue"].as<long>();
            } else if (!uFields["saldo"]["doubleValue"].isNull()) {
              fbSaldoResult = uFields["saldo"]["doubleValue"].as<long>();
            } else {
              fbSaldoResult = 0;
            }
            fbStatus = "showing_saldo";
            modeTimeout = millis();
            updateDisplay();
            playBeep(3);
            Serial.printf("[INFO] Saldo ditemukan: Rp %ld untuk %s\n", fbSaldoResult, fbNamaResult.c_str());
          }
          
          // Sinkronisasi status ke machine_commands agar termonitor di dashboard admin/web
          String path = "machine_commands/" + MACHINE_ID;
          Document<Values::Value> doc;
          doc.setContent("{\"fields\":{\"status\":{\"stringValue\":\"" + fbStatus + "\"}, \"tujuan\":{\"stringValue\":\"cek_saldo\"}, \"last_uid\":{\"stringValue\":\"" + uid + "\"}, \"nama_result\":{\"stringValue\":\"" + fbNamaResult + "\"}, \"saldo_result\":{\"integerValue\":\"" + String(fbSaldoResult) + "\"}}}");
          PatchDocumentOptions patchOptions(DocumentMask("status,tujuan,last_uid,nama_result,saldo_result"), DocumentMask(), Precondition());
          Docs.patch(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), path, patchOptions, doc);
        } else {
          fbStatus = "error";
          fbNamaResult = "Kartu Tak Dikenal";
          fbSaldoResult = 0;
          modeTimeout = millis();
          updateDisplay();
          playBeep(4);
          Serial.println("[ERROR] UID tidak terdaftar di koleksi users.");
        }
      } else {
        Serial.printf("[ERROR] Gagal membaca user doc: %s (code %d)\n", aClient.lastError().message().c_str(), aClient.lastError().code());
        fbStatus = "error";
        fbNamaResult = "Koneksi Gagal";
        fbSaldoResult = 0;
        modeTimeout = millis();
        updateDisplay();
        playBeep(4);
      }
    }
  }

  rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
}

void setup() {
  Serial.begin(115200);
  delay(1500); // Tunggu USB CDC siap
  Serial.println("\n=================================");
  Serial.println("[SYSTEM] ESP32-S3 NBPay EDC Starting...");
  Serial.println("=================================");

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  playBeep(2); // Bunyi bip tanda baru mulai booting

  // Setup Fake VCC, Fake GND, dan OUT untuk 5 Tombol
  int btnVccPins[] = {BTN1_VCC, BTN2_VCC, BTN3_VCC, BTN4_VCC, BTN5_VCC};
  int btnGndPins[] = {BTN1_GND, BTN2_GND, BTN3_GND, BTN4_GND, BTN5_GND};
  int btnOutPins[] = {BTN1_OUT, BTN2_OUT, BTN3_OUT, BTN4_OUT, BTN5_OUT};
  
  for(int i = 0; i < 5; i++) {
    pinMode(btnVccPins[i], OUTPUT);
    digitalWrite(btnVccPins[i], HIGH); // Output 3.3V buatan
    
    pinMode(btnGndPins[i], OUTPUT);
    digitalWrite(btnGndPins[i], LOW);  // Output 0V (GND) buatan
    
    pinMode(btnOutPins[i], INPUT_PULLDOWN); // Wajib pulldown agar tidak floating
  }

  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, HIGH);
  lastActivity = millis();

#if defined(ESP_IDF_VERSION_MAJOR) && ESP_IDF_VERSION_MAJOR >= 5
  esp_task_wdt_config_t twdt_config = {
      .timeout_ms = WDT_TIMEOUT * 1000,
      .idle_core_mask = 0,
      .trigger_panic = true,
  };
  esp_task_wdt_init(&twdt_config);
#else
  esp_task_wdt_init(WDT_TIMEOUT, true);
#endif
  esp_task_wdt_add(NULL);

  preferences.begin("edc_config", false);
  MACHINE_ID = preferences.getString("machine_id", "kantin_01");

  tft.initR(INITR_BLACKTAB);
  tft.setRotation(2); // Portrait kebalik (180 derajat)
  
  SPI.begin(SPI_SCK, SPI_MISO, SPI_MOSI, RFID_CS);
  rfid.PCD_Init();
  rfid.PCD_SetAntennaGain(MFRC522::RxGain_max); // Maksimal penguatan untuk e-money / Flazz / Brizzi
  
  setup_wifi();
  
  // Initialize NTP Time (Strictly UTC untuk Firebase JWT)
  Serial.println("[INFO] Syncing time (UTC)...");
  configTime(0, 0, "time.google.com", "id.pool.ntp.org", "pool.ntp.org");
  
  tft.fillRect(0, tft.height() - 13, tft.width(), 13, COLOR_BG);
  tft.setCursor(5, tft.height() - 10); tft.setTextSize(1); tft.setTextColor(COLOR_YELLOW);
  tft.print("SYNC TIME...");
  
  time_t now = time(nullptr);
  int ntp_timeout = 0;
  while (now < 24 * 3600 && ntp_timeout < 300) { // 30s timeout
    delay(100);
    esp_task_wdt_reset(); // Wajib feed watchdog
    now = time(nullptr);
    ntp_timeout++;
  }
  
  if (now < 24 * 3600) {
    Serial.println("\n[ERROR] NTP Sync failed! Will retry in loop.");
  } else {
    Serial.println("\n[INFO] Time synced successfully (UTC)!");
  }
  
  // Initialize Firebase
  Firebase.printf("Firebase Client v%s\n", FIREBASE_CLIENT_VERSION);
  ssl_client.setInsecure(); // Ignore cert validation
  
  if (now >= 24 * 3600) {
    Serial.println("[INFO] Initializing Firebase...");
    initializeApp(aClient, app, getAuth(sa_auth), asyncCB, "authTask");
    app.getApp<Firestore::Documents>(Docs);
    firebaseInitialized = true;
  } else {
    Serial.println("[WARNING] Firebase initialization deferred (waiting for NTP sync).");
  }

  updateDisplay();
}

void loop() {
  esp_task_wdt_reset();

  static unsigned long lastDebugPrint = 0;
  if (millis() - lastDebugPrint > 5000) {
    lastDebugPrint = millis();
    Serial.printf("[DEBUG] WiFi:%d | Time:%ld | FBInit:%d | FBReady:%d | Mode:%d | Status:%s\n",
                  WiFi.status() == WL_CONNECTED,
                  (long)time(nullptr),
                  firebaseInitialized,
                  firebaseInitialized ? app.ready() : 0,
                  currentMode,
                  fbStatus.c_str());
  }

  if (firebaseInitialized) {
    app.loop(); // Required for internal authentication mechanisms

    if (app.ready()) {
      pollFirestore();
      sendHeartbeat();
    }
  } else {
    // Check if time is now synced
    time_t now = time(nullptr);
    if (now >= 24 * 3600) {
      Serial.println("[INFO] Time synced in loop. Initializing Firebase...");
      initializeApp(aClient, app, getAuth(sa_auth), asyncCB, "authTask");
      app.getApp<Firestore::Documents>(Docs);
      firebaseInitialized = true;
      updateDisplay();
    }
  }

  readButtons();
  handleRFID();
  
  if (firebaseInitialized && app.ready() && (fbStatus == "success" || fbStatus == "error" || fbStatus == "showing_saldo") && (millis() - modeTimeout > 5000)) {
    // Kembalikan ke role default mesin
    if (defaultTujuan != "") {
      fbTujuan = defaultTujuan;
    }

    if (fbTujuan == "cek_saldo") currentMode = 1;
    else if (fbTujuan == "topup_daftar") currentMode = 4;
    else currentMode = 0;
    
    fbStatus = "idle";
    totalPesanan = 0; jumlahItem = 0;
    memset(currentOrder, 0, sizeof(currentOrder));
    updateDisplay();
    
    String path = "machine_commands/" + MACHINE_ID;
    Document<Values::Value> doc;
    // Kembalikan status ke idle dan tujuan ke defaultTujuan mesin
    doc.setContent("{\"fields\":{\"status\":{\"stringValue\":\"idle\"}, \"tujuan\":{\"stringValue\":\"" + fbTujuan + "\"}}}");
    PatchDocumentOptions patchOptions(DocumentMask("status,tujuan"), DocumentMask(), Precondition());
    Docs.patch(aClient, Firestore::Parent(FIREBASE_PROJECT_ID), path, patchOptions, doc);
    
    if (aClient.lastError().code() != 0) {
      Serial.printf("[ERROR] Reset status to idle patch failed: %s (code: %d)\n", aClient.lastError().message().c_str(), aClient.lastError().code());
    } else {
      Serial.println("[INFO] Reset status to idle patch successful.");
    }
  }
}
