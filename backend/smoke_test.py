"""Backend 스모크 테스트 — pytest 없이 직접 실행: python smoke_test.py"""

from fastapi.testclient import TestClient

from main import API_TOKEN, app

client = TestClient(app)
if API_TOKEN:
    client.headers.update({"Authorization": f"Bearer {API_TOKEN}"})

KNOWN_TYPES = {"methaneRisk", "awdDrain", "awdDry", "awdReflood", "awdFlood"}


def test_flow() -> None:
    assert client.get("/health").json()["ok"] is True

    if API_TOKEN:
        # 인증 안 하면 거부
        assert TestClient(app).get("/api/notifications").status_code == 401

    r = client.post(
        "/api/devices/paddy_a/telemetry",
        json={"water_level": 6.0, "soil_moisture": 38.0, "water_temp": 26.5},
    )
    assert r.status_code == 200 and r.json()["ok"]

    state = client.get("/api/state/paddy_a").json()
    t, tw = state["telemetry"], state["twin"]
    for key in ("orp", "ec", "water_level", "soil_moisture", "water_temp",
                "battery_soc", "solar_v", "gate_open", "pump_on", "rssi",
                "methane_score", "orp_delta_1h", "rain_3h", "paddy_id"):
        assert key in t, key
    for key in ("water_level", "predicted_level_3h", "orp", "predicted_orp_3h",
                "methane_score", "gate_open", "pump_on", "weather", "temp_c",
                "rain_3h", "awd_phase", "paddy_id"):
        assert key in tw, key
    assert tw["awd_phase"] in ("flooded", "draining", "dry", "reflood")
    print("state keys OK")

    r = client.post("/api/control/paddy_a", json={"gate_open": True})
    assert r.status_code == 200 and r.json()["twin"]["awd_phase"] == "draining"

    cmd = client.get("/api/devices/paddy_a/command").json()
    assert cmd["gate_open"] is True and cmd["phase"] == "draining"
    print("control/command OK")

    notifs = client.get("/api/notifications").json()
    assert notifs, "notifications empty"
    assert {n["type"] for n in notifs} <= KNOWN_TYPES, notifs
    first = notifs[0]
    r = client.post(f"/api/notifications/{first['id']}/read")
    assert r.status_code == 200
    assert client.get("/api/notifications").json()[0]["read"] is True
    print("notifications OK")

    client.post("/api/control/paddy_a", json={"emergency": True})
    cmd = client.get("/api/devices/paddy_a/command").json()
    assert cmd["gate_open"] is False and cmd["pump_on"] is False
    print("emergency OK")


def test_account_flow() -> None:
    """회원가입 → 로그인 → 기기 등록 → 논 생성(기기 연결) → 논 삭제."""
    c = TestClient(app)
    username = f"farmer_{__import__('time').time_ns()}"
    pw = "testpw1234"

    # 중복 가입 거부
    assert c.post("/api/auth/signup", json={"username": "demo", "password": pw}).status_code in (200, 409)

    r = c.post("/api/auth/signup", json={"username": username, "password": pw})
    assert r.status_code == 200, r.text
    token = r.json()["token"]
    assert r.json()["user"]["username"] == username
    c.headers.update({"Authorization": f"Bearer {token}"})

    # 인증 없이 거부
    assert TestClient(app).get("/api/devices").status_code == 401

    me = c.get("/api/auth/me")
    assert me.status_code == 200 and me.json()["user"]["username"] == username
    assert c.post("/api/auth/login", json={"username": username, "password": "wrong"}).status_code == 401

    # 기기 등록/목록/삭제
    r = c.post("/api/devices", json={"device_id": "esp-bc-cafe", "name": "수위 센서 A", "type": "sensor"})
    assert r.status_code == 200 and r.json()["device_id"] == "esp-bc-cafe"
    assert c.post("/api/devices", json={"device_id": "esp-bc-cafe", "name": "dup", "type": "sensor"}).status_code == 409
    devices = c.get("/api/devices").json()
    assert any(d["device_id"] == "esp-bc-cafe" for d in devices)

    # 논 생성 + 기기 연결 + 조회
    r = c.post("/api/paddies", json={
        "name": "새 논", "stage": "담수기", "area": "1,000㎡",
        "device_ids": ["esp-bc-cafe", "esp-xyz-99"],
    })
    assert r.status_code == 200, r.text
    paddy_id = r.json()["id"]
    assert set(r.json()["device_ids"]) == {"esp-bc-cafe", "esp-xyz-99"}

    paddies = c.get("/api/paddies").json()
    assert any(p["id"] == paddy_id for p in paddies)
    mine = next(p for p in paddies if p["id"] == paddy_id)
    assert "esp-bc-cafe" in mine["device_ids"]

    # 논-기기 매핑 수정
    r = c.patch(f"/api/paddies/{paddy_id}/devices", json={"device_ids": ["esp-bc-cafe"]})
    assert r.status_code == 200 and r.json()["device_ids"] == ["esp-bc-cafe"]

    # 사용자 전용 논 상태 조회 가능
    state = c.get(f"/api/state/{paddy_id}")
    assert state.status_code == 200 and state.json()["telemetry"]["paddy_id"] == paddy_id

    # 논/기기 삭제
    assert c.delete(f"/api/paddies/{paddy_id}").status_code == 200
    assert c.delete("/api/devices/esp-bc-cafe").status_code == 200
    assert c.delete("/api/devices/esp-xyz-99").status_code == 404
    print("account/device/paddy OK")


if __name__ == "__main__":
    test_flow()
    test_account_flow()
    print("SMOKE PASS")