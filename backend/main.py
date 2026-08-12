"""Smart Rice AI — 센서 → 앱 연동 백엔드 (FastAPI).

역할:
  - ESP32/아두이노 디바이스가 센서값을 POST 하면 저장
  - AWD(간단관개) 사이클을 서버에서 판단(담수→배수→건조→재관수)
  - 앱이 GET /api/state 로 텔레메트리·트윈을 받아감
  - 앱 제어 명령 게이트/펌프를 디바이스로 내려줌(디바이스는 커맨드 폴링)

실행:
  pip install -r requirements.txt
  uvicorn main:app --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import asyncio
import threading
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

TICK_SECONDS = 3.0
MAX_NOTIFICATIONS = 40

app = FastAPI(title="Smart Rice AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

_lock = threading.Lock()


class TelemetryIn(BaseModel):
    """디바이스가 올리는 센서값. 제공된 필드만 반영된다(orp/전압 등 선택)."""

    orp: Optional[float] = None
    ec: Optional[float] = None
    water_level: Optional[float] = None
    soil_moisture: Optional[float] = None
    water_temp: Optional[float] = None
    battery_soc: Optional[float] = None
    solar_v: Optional[float] = None
    rssi: Optional[float] = None


class ControlIn(BaseModel):
    gate_open: Optional[bool] = None
    pump_on: Optional[bool] = None
    emergency: Optional[bool] = None


@dataclass
class Notification:
    id: str
    time: str
    type: str
    title: str
    body: str
    read: bool = False

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "time": self.time,
            "type": self.type,
            "title": self.title,
            "body": self.body,
            "read": self.read,
        }


@dataclass
class PaddyState:
    paddy_id: str
    name: str
    sky: str
    rain_3h: bool
    phase: str = "flooded"
    phase_tick: int = 0
    orp: float = 320.0
    ec: float = 1.1
    water_level: float = 5.0
    soil_moisture: float = 42.0
    water_temp: float = 26.0
    battery_soc: float = 80.0
    solar_v: float = 18.0
    rssi: float = -62.0
    gate_open: bool = False
    pump_on: bool = False
    tick: int = 0
    notif_seq: int = 0
    notifications: list[Notification] = field(default_factory=list)

    def clamp(self, v: float, lo: float, hi: float) -> float:
        return max(lo, min(hi, v))

    def _now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def add_notification(self, ntype: str, title: str, body: str) -> None:
        self.notif_seq += 1
        self.notifications.insert(
            0,
            Notification(
                id=f"{self.paddy_id}_{self.notif_seq}_{ntype}",
                time=self._now(),
                type=ntype,
                title=title,
                body=body,
            ),
        )
        if len(self.notifications) > MAX_NOTIFICATIONS:
            self.notifications.pop()

    def set_phase(self, phase: str) -> bool:
        """단계 전환. 바뀌면 알림을 남기고 True."""
        if self.phase == phase:
            return False
        self.phase = phase
        self.phase_tick = 0
        wl = f"{self.water_level:.1f}"
        orp = round(self.orp)
        if phase == "draining":
            self.add_notification(
                "awdDrain",
                f"{self.name} · AWD 배수 시작",
                f"ORP {orp} mV로 메탄 위험이 커져 수문을 열고 배수를 시작했어요.",
            )
        elif phase == "dry":
            self.add_notification(
                "awdDry",
                f"{self.name} · 건조 단계",
                f"수위 {wl} cm로 토양이 드러났어요. ORP가 회복되고 있어요.",
            )
        elif phase == "reflood":
            self.add_notification(
                "awdReflood",
                f"{self.name} · 재관수 시작",
                "건조가 끝났어요. 수문을 닫고 물을 채워 목표 수위 5~7cm를 맞춰요.",
            )
        else:  # flooded
            self.add_notification(
                "awdFlood",
                f"{self.name} · 담수 완료",
                f"수위 {wl} cm에 도달했어요. 다음 AWD 주기를 준비해요.",
            )
        return True

    def advance(self) -> None:
        """3초 틱마다 호출. 단계별 ORP 응답 + 단계 전환 판단.

        수위는 디바이스가 측정해 올린 값을 사용한다(서버는 ORP만 모델링).
        """
        self.tick += 1
        self.phase_tick += 1
        if self.phase == "flooded":
            self.gate_open = False
            self.pump_on = False
            self.orp = self.clamp(self.orp - 1.2, 120.0, 420.0)
            if self.orp <= 300 or self.phase_tick >= 40:
                self.set_phase("draining")
        elif self.phase == "draining":
            self.gate_open = True
            self.pump_on = False
            self.orp = self.clamp(self.orp + 2.5, 120.0, 420.0)
            if self.water_level <= 0.3:
                self.set_phase("dry")
        elif self.phase == "dry":
            self.gate_open = False
            self.pump_on = False
            self.orp = self.clamp(self.orp + 0.5, 120.0, 420.0)
            if self.phase_tick >= 20:
                self.set_phase("reflood")
        else:  # reflood
            self.gate_open = False
            self.pump_on = True
            self.orp = self.clamp(self.orp - 0.6, 120.0, 420.0)
            if self.water_level >= 5.5:
                self.set_phase("flooded")

    def methane_score(self) -> float:
        return self.clamp((360.0 - self.orp) / 60.0, 0.15, 0.95)

    def predicted_level_3h(self) -> float:
        if self.phase == "draining":
            return self.clamp(self.water_level - 2.0, 0.0, 9.0)
        if self.phase == "dry":
            return self.water_level
        if self.phase == "reflood":
            return self.clamp(self.water_level + 2.0, 0.0, 9.0)
        return self.clamp(self.water_level + 0.5, 0.0, 9.0)

    def predicted_orp_3h(self) -> float:
        if self.phase == "draining":
            return self.orp + 20
        if self.phase == "dry":
            return self.orp + 10
        if self.phase == "reflood":
            return self.orp + 3
        return self.orp - 5

    def state_json(self) -> tuple[dict, dict]:
        methane = self.methane_score()
        telemetry = {
            "paddy_id": self.paddy_id,
            "orp": self.orp,
            "ec": self.ec,
            "water_level": self.water_level,
            "soil_moisture": self.soil_moisture,
            "water_temp": self.water_temp,
            "battery_soc": self.battery_soc,
            "solar_v": self.solar_v,
            "gate_open": self.gate_open,
            "pump_on": self.pump_on,
            "rssi": self.rssi,
            "methane_score": methane,
            "orp_delta_1h": -10.3 + self.tick * 0.2,
            "rain_3h": self.rain_3h,
        }
        twin = {
            "paddy_id": self.paddy_id,
            "water_level": self.water_level,
            "predicted_level_3h": self.predicted_level_3h(),
            "orp": self.orp,
            "predicted_orp_3h": self.predicted_orp_3h(),
            "methane_score": methane,
            "gate_open": self.gate_open,
            "pump_on": self.pump_on,
            "weather": self.sky,
            "temp_c": self.water_temp + 2.0,
            "rain_3h": self.rain_3h,
            "awd_phase": self.phase,
        }
        return telemetry, twin

    def seed_notifications(self) -> None:
        """알림이 비어 있을 때 현재 상태 기준 시드를 넣는다(앱 첫 진입용)."""
        if self.notifications:
            return
        wl = f"{self.water_level:.1f}"
        orp = round(self.orp)
        ntype = {
            "draining": "awdDrain",
            "dry": "awdDry",
            "reflood": "awdReflood",
        }.get(self.phase, "awdFlood")
        self.add_notification(
            ntype,
            f"{self.name} · AWD {self.phase} 중",
            f"현재 간단관개 사이클은 \"{self.phase}\" 단계예요. ORP {orp} mV.",
        )
        if self.methane_score() >= 0.6:
            self.add_notification(
                "methaneRisk",
                f"{self.name} · 메탄 위험",
                f"메탄 위험도 {self.methane_score():.2f}로 높아 AWD 배수를 판단 중이에요. ORP {orp} mV.",
            )

    def apply_control(self, c: ControlIn) -> None:
        if c.emergency:
            self.pump_on = False
            self.gate_open = False
            self.set_phase("dry" if self.water_level < 0.5 else "flooded")
            return
        if c.gate_open is not None:
            self.gate_open = c.gate_open
            if c.gate_open and self.phase != "draining":
                self.set_phase("draining")
            elif not c.gate_open and self.phase == "draining":
                self.set_phase("dry" if self.water_level < 0.5 else "flooded")
        if c.pump_on is not None:
            self.pump_on = c.pump_on
            if c.pump_on and self.phase != "reflood":
                self.set_phase("reflood")
            elif not c.pump_on and self.phase == "reflood":
                self.set_phase("flooded" if self.water_level >= 4.0 else "dry")

    def apply_telemetry(self, t: TelemetryIn) -> None:
        if t.orp is not None:
            self.orp = t.orp
        if t.ec is not None:
            self.ec = t.ec
        if t.water_level is not None:
            self.water_level = t.water_level
        if t.soil_moisture is not None:
            self.soil_moisture = t.soil_moisture
        if t.water_temp is not None:
            self.water_temp = t.water_temp
        if t.battery_soc is not None:
            self.battery_soc = t.battery_soc
        if t.solar_v is not None:
            self.solar_v = t.solar_v
        if t.rssi is not None:
            self.rssi = t.rssi


def _make_paddies() -> dict[str, PaddyState]:
    return {
        "paddy_a": PaddyState(
            paddy_id="paddy_a", name="논 A", sky="sunny", rain_3h=False,
            phase="flooded", phase_tick=34, orp=310.2, water_level=5.8,
            soil_moisture=40.2, water_temp=26.0, ec=1.28,
            battery_soc=78.5, solar_v=18.2, rssi=-62.0,
        ),
        "paddy_b": PaddyState(
            paddy_id="paddy_b", name="논 B", sky="cloudy", rain_3h=False,
            phase="flooded", orp=385.0, water_level=4.2, soil_moisture=48.0,
            water_temp=25.0, ec=0.9, battery_soc=92.0, solar_v=19.0, rssi=-58.0,
        ),
        "paddy_c": PaddyState(
            paddy_id="paddy_c", name="논 C", sky="rain", rain_3h=False,
            phase="dry", phase_tick=6, orp=352.0, water_level=0.1,
            soil_moisture=24.0, water_temp=27.0, ec=1.6,
            battery_soc=41.0, solar_v=17.0, rssi=-70.0,
        ),
    }


PADDIES: dict[str, PaddyState] = _make_paddies()


async def _ticker() -> None:
    while True:
        await asyncio.sleep(TICK_SECONDS)
        with _lock:
            for p in PADDIES.values():
                p.advance()


@app.on_event("startup")
async def _startup() -> None:
    asyncio.create_task(_ticker())


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.post("/api/devices/{paddy_id}/telemetry")
def ingest_telemetry(paddy_id: str, t: TelemetryIn) -> dict:
    with _lock:
        p = PADDIES.get(paddy_id)
        if p is None:
            raise HTTPException(status_code=404, detail="unknown paddy")
        p.apply_telemetry(t)
    return {"ok": True, "paddy_id": paddy_id}


@app.get("/api/devices/{paddy_id}/command")
def device_command(paddy_id: str) -> dict:
    with _lock:
        p = PADDIES.get(paddy_id)
        if p is None:
            raise HTTPException(status_code=404, detail="unknown paddy")
        return {
            "gate_open": p.gate_open,
            "pump_on": p.pump_on,
            "phase": p.phase,
        }


@app.get("/api/state/{paddy_id}")
def get_state(paddy_id: str) -> dict:
    with _lock:
        p = PADDIES.get(paddy_id)
        if p is None:
            raise HTTPException(status_code=404, detail="unknown paddy")
        telemetry, twin = p.state_json()
    return {"telemetry": telemetry, "twin": twin}


@app.get("/api/notifications")
def get_notifications() -> list[dict]:
    with _lock:
        # 현재 선택 논(마지막 조회) 기준 시드 생성
        for p in PADDIES.values():
            p.seed_notifications()
        out = PADDIES["paddy_a"].notifications
    return [n.to_json() for n in out]


@app.post("/api/notifications/{notification_id}/read")
def mark_read(notification_id: str) -> dict:
    with _lock:
        now = datetime.now(timezone.utc).isoformat()
        # 알림 id 앞 두 토큰이 paddy_id라 순회로 찾는다
        for p in PADDIES.values():
            for n in p.notifications:
                if n.id == notification_id and not n.read:
                    n.read = True
                    return {"ok": True, "read_at": now}
    return {"ok": True}


@app.post("/api/control/{paddy_id}")
def control(paddy_id: str, c: ControlIn) -> dict:
    with _lock:
        p = PADDIES.get(paddy_id)
        if p is None:
            raise HTTPException(status_code=404, detail="unknown paddy")
        p.apply_control(c)
        telemetry, twin = p.state_json()
    return {"ok": True, "telemetry": telemetry, "twin": twin}