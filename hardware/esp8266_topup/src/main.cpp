#include <ESP8266WiFi.h>
#include <PubSubClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// --- PIN DEFINITIONS FOR ESP8266 (NodeMCU) ---
// Hardware SPI Pins: SCK=D5, MISO=D6, MOSI=D7

// MFRC522 Pins
#define RFID_CS   15  // D8
#define RFID_RST  0   // D3

// OLED 0.96" SPI Pins
#define OLED_DC   4   // D2
#define OLED_CS   5   // D1
#define OLED_RST  2   // D4
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

// --- OBJECT INSTANTIATIONS ---
MFRC522 rfid(RFID_CS, RFID_RST);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &SPI, OLED_DC, OLED_RST, OLED_CS);

// Network
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* mqtt_server = "server.darell.my.id";
const int mqtt_port = 1883;

WiFiClient espClient;
PubSubClient client(espClient);

// --- STATE MACHINE ---
enum SystemMode {
  MODE_0_STANDBY,
  MODE_1_READ_INFO,
  MODE_2_AWAIT_WEB,
  MODE_3_EXECUTE
};

SystemMode currentMode = MODE_0_STANDBY;

// Top-up State Variables
String currentUid = "";
uint32_t currentBalance = 0;
uint32_t topupNominal = 0;
unsigned long awaitWebStartTime = 0;

// MFRC522 Key (Default FFFFFFFFFFFF)
MFRC522::MIFARE_Key key;

// Struct to store data on RFID block (Sector 1, Block 4)
#define DATA_BLOCK 4
struct CardData {
  uint8_t role; // 1 = Pembeli, 2 = Penjual
  uint32_t balance;
  uint8_t padding[11];
};

// --- FUNCTION PROTOTYPES ---
void showStandbyScreen();
void showInfoScreen(String uid, uint32_t balance);
void showAwaitWebScreen();
void showExecuteScreen(uint32_t nominal);
void showSuccessScreen(uint32_t newBalance);
void showErrorScreen(String msg);
bool readCardData(CardData* data);
bool writeCardData(CardData* data);

// --- NETWORK FUNCTIONS ---
void setup_wifi() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 10);
  display.println("Connecting WiFi...");
  display.display();

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  display.println("WiFi Connected!");
  display.display();
  delay(1000);
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String messageTemp;
  for (int i = 0; i < length; i++) messageTemp += (char)payload[i];
  
  if (String(topic) == "esp8266/commands") {
    // Expected format: execute_topup|UID|Nominal
    if (messageTemp.startsWith("execute_topup|")) {
      int firstPipe = messageTemp.indexOf('|');
      int secondPipe = messageTemp.indexOf('|', firstPipe + 1);

      if (firstPipe > 0 && secondPipe > 0) {
        String targetUid = messageTemp.substring(firstPipe + 1, secondPipe);
        uint32_t nominal = messageTemp.substring(secondPipe + 1).toInt();
        
        if (currentMode == MODE_2_AWAIT_WEB && targetUid == currentUid) {
          topupNominal = nominal;
          currentMode = MODE_3_EXECUTE;
          showExecuteScreen(topupNominal);
        }
      }
    }
  }
}

void reconnect() {
  if (!client.connected()) {
    String clientId = "TopUp-ESP8266-";
    clientId += String(random(0, 0xffff), HEX);
    if (client.connect(clientId.c_str())) {
      client.subscribe("esp8266/commands");
    }
  }
}

// --- DISPLAY FUNCTIONS ---
void showStandbyScreen() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("--- TOP-UP TERMINAL ---");
  
  display.setTextSize(2);
  display.setCursor(0, 25);
  display.println("TAP KARTU");
  display.display();
}

void showInfoScreen(String uid, uint32_t balance) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("UID: " + uid);
  display.setCursor(0, 15);
  display.println("Saldo Saat Ini:");
  
  display.setTextSize(2);
  display.setCursor(0, 30);
  display.print("Rp ");
  display.println(balance);
  display.display();
}

void showAwaitWebScreen() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("UID: " + currentUid);
  
  display.setCursor(0, 20);
  display.println("Menunggu Admin");
  display.println("memasukkan nominal");
  display.println("di Website...");
  display.display();
}

void showExecuteScreen(uint32_t nominal) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("Tambah Saldo:");
  
  display.setTextSize(2);
  display.setCursor(0, 15);
  display.print("Rp ");
  display.println(nominal);
  
  display.setTextSize(1);
  display.setCursor(0, 45);
  display.println("-> TAP KARTU LAGI <-");
  display.display();
}

void showSuccessScreen(uint32_t newBalance) {
  display.clearDisplay();
  display.setTextSize(2);
  display.setCursor(20, 10);
  display.println("SUKSES!");
  
  display.setTextSize(1);
  display.setCursor(0, 35);
  display.println("Saldo Baru:");
  display.print("Rp ");
  display.println(newBalance);
  display.display();
}

void showErrorScreen(String msg) {
  display.clearDisplay();
  display.setTextSize(2);
  display.setCursor(20, 10);
  display.println("GAGAL!");
  
  display.setTextSize(1);
  display.setCursor(0, 35);
  display.println(msg);
  display.display();
}

// --- RFID DATA FUNCTIONS ---
bool authenticateBlock(uint8_t blockAddr) {
  MFRC522::StatusCode status = rfid.PCD_Authenticate(MFRC522::PICC_CMD_MF_AUTH_KEY_A, blockAddr, &key, &(rfid.uid));
  return status == MFRC522::STATUS_OK;
}

bool readCardData(CardData* data) {
  if (!authenticateBlock(DATA_BLOCK)) return false;
  
  uint8_t buffer[18];
  uint8_t size = sizeof(buffer);
  
  MFRC522::StatusCode status = rfid.MIFARE_Read(DATA_BLOCK, buffer, &size);
  if (status == MFRC522::STATUS_OK) {
    memcpy(data, buffer, sizeof(CardData));
    return true;
  }
  return false;
}

bool writeCardData(CardData* data) {
  if (!authenticateBlock(DATA_BLOCK)) return false;
  
  uint8_t buffer[16];
  memcpy(buffer, data, sizeof(CardData));
  
  MFRC522::StatusCode status = rfid.MIFARE_Write(DATA_BLOCK, buffer, 16);
  return status == MFRC522::STATUS_OK;
}

// --- MAIN LOGIC ---
void handleRFID() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    return; // No card
  }

  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    uid += String(rfid.uid.uidByte[i] < 0x10 ? "0" : "");
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();

  CardData cardData;
  if (readCardData(&cardData)) {
    
    if (currentMode == MODE_0_STANDBY) {
      if (cardData.role == 1) { // Pembeli
        currentUid = uid;
        currentBalance = cardData.balance;
        
        currentMode = MODE_1_READ_INFO;
        showInfoScreen(uid, currentBalance);
        
        // Notify website that a top-up request is pending
        String reqMsg = "{\"uid\":\"" + uid + "\",\"currentBalance\":" + String(currentBalance) + "}";
        client.publish("esp8266/topup_request", reqMsg.c_str());
        
        delay(2000);
        currentMode = MODE_2_AWAIT_WEB;
        showAwaitWebScreen();
        awaitWebStartTime = millis();
      } else {
        showErrorScreen("Bukan Kartu Pembeli!");
        delay(2000);
        showStandbyScreen();
      }
    }
    else if (currentMode == MODE_3_EXECUTE) {
      if (uid == currentUid) {
        // Apply Top-up
        cardData.balance += topupNominal;
        
        if (writeCardData(&cardData)) {
          showSuccessScreen(cardData.balance);
          
          // Send transaction to Next.js dashboard
          String txMsg = "{\"uid\":\"" + uid + "\",\"nominal\":" + String(topupNominal) + ",\"newBalance\":" + String(cardData.balance) + "}";
          client.publish("esp8266/topup_success", txMsg.c_str());

          delay(3000);
        } else {
          showErrorScreen("Gagal Tulis Kartu!");
          delay(2000);
        }
      } else {
        showErrorScreen("UID Berbeda!");
        delay(2000);
      }
      
      // Reset State
      currentMode = MODE_0_STANDBY;
      currentUid = "";
      topupNominal = 0;
      showStandbyScreen();
    }
  } else {
    if (currentMode == MODE_0_STANDBY) {
      showErrorScreen("Kartu Kosong!");
      delay(2000);
      showStandbyScreen();
    }
  }

  // Halt PICC
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

void setup() {
  Serial.begin(115200);

  // Initialize OLED
  if(!display.begin(SSD1306_SWITCHCAPVCC)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;);
  }
  
  // Initialize RFID
  SPI.begin();
  rfid.PCD_Init();
  
  // Set default key to FFFFFFFFFFFF
  for (byte i = 0; i < 6; i++) key.keyByte[i] = 0xFF;

  setup_wifi();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(mqttCallback);

  showStandbyScreen();
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  
  // Timeout for Await Web (30 seconds)
  if (currentMode == MODE_2_AWAIT_WEB) {
    if (millis() - awaitWebStartTime > 30000) {
      currentMode = MODE_0_STANDBY;
      showStandbyScreen();
    }
  }

  handleRFID();
}
