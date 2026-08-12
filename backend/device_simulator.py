"""Smart Rice AI — 장치(ESP32/아두이노) 시뮬레이터.

실제 하드웨어가 준비되기 전까지, ESP32가 할 일을 그대로 흉내낸다:
  - 3초마다 센서값을 백엔드로 POST
  - 백엔드 커맨드(수문/펌프)를 폴링해서 그대로 물리 수위에 반영

실행:
  python device_simulator.py            # 기본 http://127.0.0.1:8000
  python device_simulator.py --paddy paddy_a --url http://192.168.0.10:8000
"""

import argparse
import random
import time
import urllib.request

import json


def _post(url: str, payload: dict) -> None:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as res:
        if res.status != 200:
            raise RuntimeError(f"POST {url} -> {res.status}")


def _get(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=5) as res:
        return json.loads(res.read().decode("utf-8"))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--paddy", default="paddy_a")
    ap.add_argument("--url", default="http://127.0.0.1:8000")
    args = ap.parse_args()

    base = args.url.rstrip("/")
    telemetry_url = f"{base}/api/devices/{args.paddy}/telemetry"
    command_url = f"{base}/api/devices/{args.paddy}/command"

    water = 5.8
    print(f"[sim] {args.paddy} -> {telemetry_url}")

    while True:
        try:
            cmd = _get(command_url)
            if cmd["gate_open"]:
                water = max(0.0, water - 0.12)
            elif cmd["pump_on"]:
                water = min(7.0, water + 0.10)
            else:
                water = max(0.0, water - 0.01)

            payload = {
                "water_level": round(water, 2),
                "ec": round(1.0 + random.uniform(-0.1, 0.1), 2),
                "soil_moisture": round(30 + random.uniform(-3, 3), 1),
                "water_temp": round(26 + random.uniform(-0.5, 0.5), 1),
                "battery_soc": 78.0,
                "solar_v": round(18 + random.uniform(-1, 1), 1),
                "rssi": round(-62 + random.randint(0, 4)),
            }
            _post(telemetry_url, payload)
            print(
                f"[sim] water={payload['water_level']} "
                f"phase={cmd['phase']} gate={cmd['gate_open']} pump={cmd['pump_on']}"
            )
        except Exception as e:  # noqa: BLE001
            print(f"[sim] error: {e}")
        time.sleep(3)


if __name__ == "__main__":
    main()
