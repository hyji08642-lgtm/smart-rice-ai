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


if __name__ == "__main__":
    test_flow()
    print("SMOKE PASS")