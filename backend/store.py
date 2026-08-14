"""Smart Rice AI — 계정/기기/논 저장소 (SQLite).

테이블:
  users       사용자 (username 유니크, 비밀번호는 pbkdf2 해시)
  sessions    로그인 세션 (token -> user)
  devices     사용자가 등록한 ESP32 기기 (device_id 유니크)
  paddies     사용자의 논
  paddy_devices  논-기기 연결 (N:M, 한 논에 기기 여러 대)

스레드 안전: FastAPI의 각 요청은 스레드에서 실행되므로 락으로 보호한다.
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import sqlite3
import threading
from datetime import datetime, timezone

DB_PATH = os.getenv("DB_PATH", os.path.join(os.path.dirname(__file__), "smart_rice.db"))

_lock = threading.RLock()
_conn: sqlite3.Connection | None = None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _get_conn() -> sqlite3.Connection:
    global _conn
    if _conn is None:
        _conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        _init()
    return _conn


def _init() -> None:
    with _lock:
        c = _get_conn()
        c.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                salt TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS sessions (
                token TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS devices (
                device_id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                type TEXT NOT NULL DEFAULT 'set',
                has_gate INTEGER NOT NULL DEFAULT 0,
                has_pump INTEGER NOT NULL DEFAULT 0,
                sensors TEXT NOT NULL DEFAULT '[]',
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS paddies (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                stage TEXT NOT NULL,
                area TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS paddy_devices (
                paddy_id TEXT NOT NULL,
                device_id TEXT NOT NULL,
                PRIMARY KEY (paddy_id, device_id)
            );
            """
        )
        cols = {r[1] for r in c.execute("PRAGMA table_info(devices)")}
        for col, ddl in (
            ("has_gate", "ALTER TABLE devices ADD COLUMN has_gate INTEGER NOT NULL DEFAULT 0"),
            ("has_pump", "ALTER TABLE devices ADD COLUMN has_pump INTEGER NOT NULL DEFAULT 0"),
            ("sensors", "ALTER TABLE devices ADD COLUMN sensors TEXT NOT NULL DEFAULT '[]'"),
        ):
            if col not in cols:
                c.execute(ddl)
        c.commit()


def _hash_password(password: str, salt: str | None = None) -> tuple[str, str]:
    if salt is None:
        salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt.encode("utf-8"), 100_000
    ).hex()
    return digest, salt


# --------------------------------------------------------------------------- #
# 사용자 / 세션
# --------------------------------------------------------------------------- #

def create_user(username: str, password: str) -> dict:
    """새 사용자 생성. 아이디 중복이면 None."""
    digest, salt = _hash_password(password)
    with _lock:
        c = _get_conn()
        try:
            cur = c.execute(
                "INSERT INTO users (username, password_hash, salt, created_at)"
                " VALUES (?, ?, ?, ?)",
                (username, digest, salt, _now()),
            )
            c.commit()
        except sqlite3.IntegrityError:
            return None
        user_id = cur.lastrowid
    return {"id": user_id, "username": username}


def verify_login(username: str, password: str) -> dict | None:
    with _lock:
        row = _get_conn().execute(
            "SELECT id, username, password_hash, salt FROM users WHERE username = ?",
            (username,),
        ).fetchone()
    if row is None:
        return None
    user_id, db_username, db_hash, salt = row
    digest, _ = _hash_password(password, salt)
    if digest != db_hash:
        return None
    return {"id": user_id, "username": db_username}


def create_session(user_id: int) -> str:
    token = secrets.token_hex(24)
    with _lock:
        _get_conn().execute(
            "INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)",
            (token, user_id, _now()),
        )
        _get_conn().commit()
    return token


def get_user_by_token(token: str) -> dict | None:
    with _lock:
        row = _get_conn().execute(
            "SELECT u.id, u.username FROM sessions s JOIN users u ON u.id = s.user_id"
            " WHERE s.token = ?",
            (token,),
        ).fetchone()
    if row is None:
        return None
    return {"id": row[0], "username": row[1]}


# --------------------------------------------------------------------------- #
# 기기
# --------------------------------------------------------------------------- #

def add_device(
    user_id: int,
    device_id: str,
    name: str,
    device_type: str,
    has_gate: bool = False,
    has_pump: bool = False,
    sensors: list[str] | None = None,
) -> dict | None:
    with _lock:
        c = _get_conn()
        try:
            c.execute(
                "INSERT INTO devices"
                " (device_id, user_id, name, type, has_gate, has_pump, sensors, created_at)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    device_id,
                    user_id,
                    name,
                    device_type,
                    int(has_gate),
                    int(has_pump),
                    json.dumps(sensors or [], ensure_ascii=False),
                    _now(),
                ),
            )
            c.commit()
        except sqlite3.IntegrityError:
            return None
    return {
        "device_id": device_id,
        "name": name,
        "type": device_type,
        "has_gate": has_gate,
        "has_pump": has_pump,
        "sensors": sensors or [],
    }


def list_devices(user_id: int) -> list[dict]:
    with _lock:
        rows = _get_conn().execute(
            "SELECT device_id, name, type, has_gate, has_pump, sensors"
            " FROM devices WHERE user_id = ? ORDER BY created_at",
            (user_id,),
        ).fetchall()
    return [
        {
            "device_id": r[0],
            "name": r[1],
            "type": r[2],
            "has_gate": bool(r[3]),
            "has_pump": bool(r[4]),
            "sensors": json.loads(r[5] or "[]"),
            "paddy_id": _device_paddy(r[0]),
        }
        for r in rows
    ]


def remove_device(user_id: int, device_id: str) -> bool:
    with _lock:
        c = _get_conn()
        cur = c.execute(
            "DELETE FROM devices WHERE device_id = ? AND user_id = ?",
            (device_id, user_id),
        )
        c.execute("DELETE FROM paddy_devices WHERE device_id = ?", (device_id,))
        c.commit()
    return cur.rowcount > 0


def _device_paddy(device_id: str) -> str | None:
    row = _get_conn().execute(
        "SELECT paddy_id FROM paddy_devices WHERE device_id = ?", (device_id,)
    ).fetchone()
    return row[0] if row else None


# --------------------------------------------------------------------------- #
# 논 / 논-기기 매핑
# --------------------------------------------------------------------------- #

def add_paddy(user_id: int, paddy_id: str, name: str, stage: str, area: str,
              device_ids: list[str]) -> dict:
    with _lock:
        c = _get_conn()
        c.execute(
            "INSERT INTO paddies (id, user_id, name, stage, area, created_at)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (paddy_id, user_id, name, stage, area, _now()),
        )
        for d in device_ids:
            c.execute(
                "INSERT OR IGNORE INTO paddy_devices (paddy_id, device_id) VALUES (?, ?)",
                (paddy_id, d),
            )
        c.commit()
    return {"id": paddy_id, "name": name, "stage": stage, "area": area,
            "device_ids": device_ids}


def list_paddies(user_id: int) -> list[dict]:
    with _lock:
        rows = _get_conn().execute(
            "SELECT id, name, stage, area FROM paddies WHERE user_id = ? ORDER BY created_at",
            (user_id,),
        ).fetchall()
    return [
        {
            "id": r[0],
            "name": r[1],
            "stage": r[2],
            "area": r[3],
            "device_ids": _paddy_devices(r[0]),
        }
        for r in rows
    ]


def remove_paddy(user_id: int, paddy_id: str) -> bool:
    with _lock:
        c = _get_conn()
        cur = c.execute("DELETE FROM paddies WHERE id = ? AND user_id = ?", (paddy_id, user_id))
        c.execute("DELETE FROM paddy_devices WHERE paddy_id = ?", (paddy_id,))
        c.commit()
    return cur.rowcount > 0


def set_paddy_devices(user_id: int, paddy_id: str, device_ids: list[str]) -> bool:
    with _lock:
        c = _get_conn()
        row = c.execute(
            "SELECT id FROM paddies WHERE id = ? AND user_id = ?", (paddy_id, user_id)
        ).fetchone()
        if row is None:
            return False
        c.execute("DELETE FROM paddy_devices WHERE paddy_id = ?", (paddy_id,))
        for d in device_ids:
            c.execute(
                "INSERT OR IGNORE INTO paddy_devices (paddy_id, device_id) VALUES (?, ?)",
                (paddy_id, d),
            )
        c.commit()
    return True


def _paddy_devices(paddy_id: str) -> list[str]:
    rows = _get_conn().execute(
        "SELECT device_id FROM paddy_devices WHERE paddy_id = ?", (paddy_id,)
    ).fetchall()
    return [r[0] for r in rows]
