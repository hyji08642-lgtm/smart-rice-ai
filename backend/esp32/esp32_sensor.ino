/*
 * Smart Rice AI — ESP32(아두이노 코어) 센서 노드
 *
 * 실제 필드 배선/캘리브레이션 전용 함수로 구성한 스케치.
 * 아래 CONFIG 섹션만 각자 환경에 맞추면 된다.
 *
 * 동작:
 *   - 수위(HC-SR04 초음파) / ORP 전극 / EC 프로브 / 토양수분 /
 *     수온(DS18B20) / 배터리·태양광 전압 아날로그를 읽는다.
 *   - 5초마다 백엔드로 센서값 POST, 5초마다 수문/펌프 커맨드 폴링.
 *   - API_TOKEN이 정의되면 Authorization: Bearer 헤더를 붙인다.
 *
 * 필요 라이브러리(Arduino Library Manager):
 *   - ArduinoJson  (bblanchon/ArduinoJson)
 *   - OneWire, DallasTemperature  (수온 센서 사용 시)
 *   - HTTPClient  (ESP32 내장, WiFi 라이브러리 포함)
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ===================== CONFIG =====================
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASS = "YOUR_WIFI_PASS";
const char* API_BASE   = "http://YOUR_SERVER:8000";  // 예: http://smart-rice.example.com
const char* PADDY_ID   = "paddy_a";
const char* API_TOKEN  = "";   // 백엔드 API_TOKEN 설정 시 그 값, 없으면 ""

const unsigned long SEND_INTERVAL_MS = 5000;
const unsigned long POLL_INTERVAL_MS = 5000;

// ---- 수문/펌프 릴레이 GPIO (HIGH=작동) ----
const int PIN_RELAY_GATE = 27;
const int PIN_RELAY_PUMP = 26;

// ---- 센서 ADC 핀 (ESP32: 12bit 0~4095, 0~3.3V) ----
const int PIN_ORP   = 34;   // ORP 전극 -> 증폭/분배 회로
const int PIN_EC    = 35;   // EC 프로브 -> 증폭 회로
const int PIN_MOIST = 32;   // 토양수분 아날로그
const int PIN_BATT  = 33;   // 배터리 -> 전압 분배(1/2)
const int PIN_SOLAR = 36;   // 태양광 패널 -> 전압 분배(1/5) (선택)

// ---- 수위 초음파 HC-SR04 ----
const int PIN_TRIG = 25;
const int PIN_ECHO = 14;

// ---- 수온 DS18B20 (선택. 안 쓰면 PIN_DS18B20 = -1) ----
const int PIN_DS18B20 = 4;   // 또는 -1로 비활성화
// ==================================================

// ===================== 캘리브레이션 =====================
// ORP: probe mV = (rawVoltage - V_OFFSET) * mV_PER_V.
//  전극 스펙에 따라 (예: 0V=+414mV@2416mV ORP전극) 값이 다르다.
const float ORP_V_OFFSET   = 0.25;   // 분배값 보정(미보정 상태 기본값)
const float ORP_MV_PER_V   = 925.0;  // 증폭 이득 보정 TODO(센서 검교정)

// EC: 프로브 증폭 후 소금물 농도 매핑. 기본은 임시값.
const float EC_V_PER_DS    = 0.5;    // V -> dS/m TODO(EC 표준액 캘리브레이션)

// 토양수분: 아날로그 '건조'값 / '젖음'값(교차 보정)
const int   MOIST_DRY      = 4095;   // 공기 중(raw max)
const int   MOIST_WET      = 1300;   // 물에 담근 raw(센서에 따라 변경)

// 배터리: 리튬이온 3.3~4.2V = 0~100%. 분배비에 맞게 조정.
const float BATT_DIVIDER   = 2.0;    // R1=R2(1/2)면 2.0
// 태양광: 22V 패널을 1/5 분배로 ADC에 넣는 기준.
const float SOLAR_DIVIDER  = 5.0;
// ==================================================

const char* BEARER_HEADER  = API_TOKEN[0] != '\0' ? "Authorization" : nullptr;
const String BEARER_VALUE  = API_TOKEN[0] != '\0' ? String("Bearer ") + API_TOKEN : String();

// OneWire/DallasTemperature (PIN_DS18B20 > 0 일 때만 활성)
OneWire* oneWire = nullptr;
DallasTemperature* tempSensor = nullptr;

unsigned long lastSend = 0;
unsigned long lastPoll = 0;

// ---------------- WiFi ----------------
void connectWifi() {
  Serial.printf("[wifi] connecting %s\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries++ < 40) {
    delay(500);
  }
  Serial.printf("[wifi] connected, RSSI %d dBm\n", WiFi.RSSI());
}

// ---------------- ADC 유틸 ----------------
float readPinVolts(int pin) {
  int raw = 0;
  const int N = 8;
  for (int i = 0; i < N; i++) raw += analogRead(pin);
  return (raw / (float)N) * (3.3f / 4095.0f);
}

// ---------------- 센서 함수 ----------------
float readWaterLevelCm() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);
  long us = pulseIn(PIN_ECHO, HIGH, 30000);  // 30ms 타임아웃(약 5m)
  if (us == 0) return -1.0f;                 // 측정 실패
  float cm = us / 58.0f;
  // 센서가 수면 위에 있을 때: 물 깊이 = 설치 높이 - 거리
  const float MOUNT_HEIGHT_CM = 100.0f;      // TODO(설치 높이)
  float depth = MOUNT_HEIGHT_CM - cm;
  return depth < 0.0f ? 0.0f : depth;
}

float readOrpMv() {
  float v = readPinVolts(PIN_ORP);
  return (v - ORP_V_OFFSET) * ORP_MV_PER_V;
}

float readEc() {
  float v = readPinVolts(PIN_EC);
  float ec = v / EC_V_PER_DS;
  return ec < 0.0f ? 0.0f : ec;
}

float readSoilMoisturePct() {
  int raw = analogRead(PIN_MOIST);
  if (raw >= MOIST_DRY) return 0.0f;
  float pct = (1.0f - (raw - MOIST_WET) / (float)(MOIST_DRY - MOIST_WET)) * 100.0f;
  pct = constrain(pct, 0.0f, 100.0f);
  return pct;
}

float readWaterTempC() {
  if (tempSensor == nullptr) return -999.0f;  // 미사용
  tempSensor->requestTemperatures();
  float c = tempSensor->getTempCByIndex(0);
  if (c == DEVICE_DISCONNECTED_C) return -999.0f;
  return c;
}

float readBatteryPct() {
  float v = readPinVolts(PIN_BATT) * BATT_DIVIDER;
  // 3.3V ~ 4.2V 리튬이온 선형 매핑
  float pct = (v - 3.3f) / (4.2f - 3.3f) * 100.0f;
  pct = constrain(pct, 0.0f, 100.0f);
  return pct;
}

float readSolarV() {
  return readPinVolts(PIN_SOLAR) * SOLAR_DIVIDER;
}

// ---------------- 제어 ----------------
void applyCommand(bool gateOpen, bool pumpOn) {
  digitalWrite(PIN_RELAY_GATE, gateOpen ? HIGH : LOW);
  digitalWrite(PIN_RELAY_PUMP, pumpOn ? HIGH : LOW);
  Serial.printf("[cmd] gate=%d pump=%d\n", gateOpen, pumpOn);
}

void pollCommand(HTTPClient& http) {
  http.begin(String(API_BASE) + "/api/devices/" + PADDY_ID + "/command");
  http.setTimeout(4000);
  if (BEARER_HEADER) http.addHeader(BEARER_HEADER, BEARER_VALUE);
  int code = http.GET();
  if (code == HTTP_CODE_OK) {
    DynamicJsonDocument doc(512);
    DeserializationError err = deserializeJson(doc, http.getString());
    if (!err) {
      bool gate = doc["gate_open"] | false;
      bool pump = doc["pump_on"] | false;
      applyCommand(gate, pump);
    }
  }
  http.end();
}

// ---------------- 텔레메트리 ----------------
void sendTelemetry(HTTPClient& http) {
  float water = readWaterLevelCm();
  float orp    = readOrpMv();
  float ec     = readEc();
  float moist  = readSoilMoisturePct();
  float wtemp  = readWaterTempC();

  StaticJsonDocument<384> doc;
  doc["water_level"]   = water < 0 ? nullptr : water;
  doc["orp"]           = orp;
  doc["ec"]            = ec;
  doc["soil_moisture"] = moist;
  if (wtemp > -900) doc["water_temp"] = wtemp;
  doc["battery_soc"] = readBatteryPct();
  doc["solar_v"]     = readSolarV();
  doc["rssi"]        = WiFi.RSSI();

  String body;
  serializeJson(doc, body);

  http.begin(String(API_BASE) + "/api/devices/" + PADDY_ID + "/telemetry");
  http.setTimeout(4000);
  http.addHeader("Content-Type", "application/json");
  if (BEARER_HEADER) http.addHeader(BEARER_HEADER, BEARER_VALUE);
  int code = http.POST(body);
  http.end();

  Serial.printf("[tx] water=%0.1f orp=%0.0f ec=%0.2f moist=%0.0f -> %d\n",
                water, orp, ec, moist, code);
}

// ---------------- 프로토콜: 커맨드(HIGH) 처리 ----------------
void setup() {
  Serial.begin(115200);

  pinMode(PIN_TRIG, OUTPUT); pinMode(PIN_ECHO, INPUT);
  pinMode(PIN_RELAY_GATE, OUTPUT); pinMode(PIN_RELAY_PUMP, OUTPUT);
  pinMode(PIN_ORP, INPUT); pinMode(PIN_EC, INPUT);
  pinMode(PIN_MOIST, INPUT); pinMode(PIN_BATT, INPUT); pinMode(PIN_SOLAR, INPUT);

  if (PIN_DS18B20 >= 0) {
    oneWire = new OneWire(PIN_DS18B20);
    tempSensor = new DallasTemperature(oneWire);
    tempSensor->begin();
  }

  connectWifi();
  digitalWrite(PIN_RELAY_GATE, LOW);
  digitalWrite(PIN_RELAY_PUMP, LOW);
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) connectWifi();

  HTTPClient http;

  unsigned long now = millis();
  if (now - lastPoll >= POLL_INTERVAL_MS) {
    pollCommand(http);
    lastPoll = now;
  }
  if (now - lastSend >= SEND_INTERVAL_MS) {
    sendTelemetry(http);
    lastSend = now;
  }

  delay(50);
}