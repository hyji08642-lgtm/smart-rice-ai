// Smart Rice AI — ESP32(아두이노) 센서 노드 스케치 뼈대
//
// 이 파일은 실제 필드에 붙일 스케치의 시작점이다.
// 아래 "TODO(센서 연결)" 표시 부분에 센서를 실제로 읽도록 채우면 된다.
//
// 동작: 3초마다 센서값을 백엔드로 POST하고,
//       백엔드가 내려준 수문/펌프 커맨드를 폴링해서 액추에이터에 반영한다.
//
// 빌드 전: 보드에 맞는 WiFi 라이브러리, HTTPClient 라이브러리를 포함한다.
// LAN9325/ESP32 와이파이 연결 정보는 아래 WIFI_SSID/WIFI_PASS를 각자 채운다.

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

const char* WIFI_SSID = "YOUR_WIFI";       // TODO: 필드 와이파이/라우터
const char* WIFI_PASS = "YOUR_PASSWORD";
const char* API_BASE   = "http://YOUR_SERVER:8000"; // TODO: 백엔드 주소
const char* PADDY_ID   = "paddy_a";

const int  PIN_GATE  = 12;   // TODO: 실제 수문 액추에이터 GPIO
const int  PIN_PUMP  = 13;   // TODO: 실제 펌프 릴레이 GPIO
const unsigned long INTERVAL_MS = 3000;

// ---- 센서 핀 (TODO: 실제 연결에 맞게 조정) -------------------------------
const int PIN_WATER  = 34;   // 아날로그 수위센서(값 0~4095)
const int PIN_MOIST  = 35;   // 토양수분 센서 아날로그
const int PIN_ORP    = 36;   // ORP 전극(전압 분배 후 아날로그)
const int PIN_TEMP   = 4;    // DS18B20 (OneWire 라이브러리 필요)

unsigned long lastMillis = 0;

void connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 40) {
    delay(500);
    tries++;
  }
}

// ---- 센서 읽기 (TODO: 실제 센서 드라이버로 교체) --------------------------
float readWaterLevel() {
  // 예: 아날로그 0~4095 -> 0~9cm 매핑. 부트(적산/터널) 구조면 HC-SR04로 대체.
  int raw = analogRead(PIN_WATER);
  return (raw / 4095.0) * 9.0;
}

float readSoilMoisture() {
  int raw = analogRead(PIN_MOIST);
  return 100.0 - (raw / 4095.0) * 100.0;   // 습할수록 아날로그 낮음(센서에 따라 반대)
}

float readWaterTemp() {
  // TODO: OneWire로 DS18B20을 읽어 섭씨 반환
  return 26.0;
}

void applyCommand(bool gateOpen, bool pumpOn) {
  // TODO: 릴레이/액추에이터 구동(서보/밸브/펌프)
  digitalWrite(PIN_GATE, gateOpen ? HIGH : LOW);
  digitalWrite(PIN_PUMP, pumpOn ? HIGH : LOW);
}

void sendTelemetry(float water, float moist, float wtemp) {
  HTTPClient http;
  http.begin(String(API_BASE) + "/api/devices/" + PADDY_ID + "/telemetry");
  http.addHeader("Content-Type", "application/json");

  StaticJsonDocument<256> doc;
  doc["water_level"] = water;
  doc["soil_moisture"] = moist;
  doc["water_temp"] = wtemp;
  // TODO: 실제 ORP/EC 측정 시 아래 주석 해제
  // doc["orp"] = readOrp();
  // doc["ec"] = readEc();
  doc["battery_soc"] = 80.0;

  String body;
  serializeJson(doc, body);
  int code = http.POST(body);
  http.end();
  (void)code;
}

void pollCommand() {
  HTTPClient http;
  http.begin(String(API_BASE) + "/api/devices/" + PADDY_ID + "/command");
  int code = http.GET();
  if (code == 200) {
    DynamicJsonDocument doc(512);
    deserializeJson(doc, http.getString());
    bool gate = doc["gate_open"] | false;
    bool pump = doc["pump_on"] | false;
    applyCommand(gate, pump);
  }
  http.end();
}

void setup() {
  pinMode(PIN_GATE, OUTPUT);
  pinMode(PIN_PUMP, OUTPUT);
  Serial.begin(115200);
  connectWifi();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWifi();
  }
  pollCommand();
  float water = readWaterLevel();
  float moist = readSoilMoisture();
  float wtemp = readWaterTemp();
  sendTelemetry(water, moist, wtemp);

  delay(INTERVAL_MS);
  (void)lastMillis;
}