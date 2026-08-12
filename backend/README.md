# Smart Rice AI — 실제 센서 연동

이 폴더는 앱이 **진짜 센서 데이터**로 동작하도록 하는 백엔드·장치 코드다.
현재 앱은 `--dart-define=API_BASE_URL` 없이 빌드하면 데모용 `MockApi`(시뮬레이션)로
동작하고, 지정하면 실제 백엔드에 연결한다.

```
ESP32/아두이노(센서) ──HTTP POST──▶ FastAPI 백엔드 ──GET/POST──▶ Flutter 앱
        │                               ▲
        └────── 커맨드 폴링 ◀───────────┘
```

## 구성

| 파일 | 역할 |
|---|---|
| `main.py` | FastAPI 백엔드. 센서값 수신·AWD 사이클 판단·상태/알림/제어 API |
| `device_simulator.py` | ESP32 대신 센서 시뮬레이터(하드웨어 준비 전 테스트용) |
| `esp32/esp32_sensor.ino` | ESP32 스케치 뼈대 — 센서 연결·WIFI/서버 주소만 채우면 동작 |
| `requirements.txt` | Python 의존성 |

## 1) 백엔드 실행

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

## 2) 장치 시뮬레이터 실행 (하드웨어 없이 종단 간 테스트)

```bash
python device_simulator.py --paddy paddy_a
```

## 3) 앱을 실제 백엔드에 연결

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
# 웹 배포용 빌드
flutter build web --release --base-href /smart-rice-ai/ \
  --dart-define=API_BASE_URL=https://your-server.com
```

> GitHub Pages는 정적 호스팅이라 백엔드는 별도 서버(VPS/클라우드)가 필요하다.
> API 인증·HTTPS는 백엔드가 담당한다(CORS는 현재 `*` 허용).

## API 계약 (앱 `RealApi`와 1:1)

- `POST /api/devices/{paddy_id}/telemetry` — 장치가 센서값 보고 (orp/ec/water_level/soil_moisture/water_temp/battery_soc/solar_v/rssi 중 원하는 것만)
- `GET  /api/devices/{paddy_id}/command` — 장치가 내릴 수문/펌프 커맨드 폴링
- `GET  /api/state/{paddy_id}` — `{"telemetry": {...}, "twin": {...}}` (앱이 표시)
- `GET  /api/notifications` — AWD 단계 알림 목록(최신순)
- `POST /api/notifications/{id}/read` — 알림 읽음 처리
- `POST /api/control/{paddy_id}` — 앱의 수문/펌프/긴급정지 명령

## 실제 ESP32 연결 순서

1. `esp32_sensor.ino`의 `WIFI_SSID`/`API_BASE`/`PADDY_ID`를 채우고 보드에 업로드
2. 센서 배선: 수위(아날로그 또는 HC-SR04), ORP/EC 전극(전압 분배), 토양수분, DS18B20 수온, 배터리 전압(분배 후 ADC)
3. 수문·펌프는 릴레이(12V/220V 격리)로 GPIO 구동
4. `readWaterLevel()` 등 `TODO(센서 연결)` 함수를 실제 드라이버로 교체하고 캘리브레이션
5. 백엔드/디바이스/앱 순으로 켜고 확인

## 참고

- AWD 사이클 판단(담수→배수→건조→재관수)은 **백엔드가 담당**한다. 앱은 `awd_phase`를 받아 표시만 하고, 제어 명령만 보낸다.
- 수위는 장치가 측정한 값을 쓴다. 서버는 ORP(산화환원) 응답만 모델링해 단계 전환 기준에 쓴다.