# Smart Rice AI — 백엔드 공개 배포 가이드 (HTTPS)

GitHub Pages 앱은 HTTPS 위에서 돌기 때문에, 앱의 `RealApi`가 접근할 백엔드는
**HTTPS로 공개**해야 한다. 백엔드 인증·HTTPS는 다음 중 하나로 처리한다.

> 배포된 데모 사이트는 `MockApi`(시뮬레이션)라 백엔드 없이 동작한다.
> 이 문서는 "실센서 모드"에서 앱을 실제 백엔드에 붙일 때 사용한다.

## 공통: 환경변수

| 변수 | 의미 | 예 |
|---|---|---|
| `API_TOKEN` | 설정 시 모든 API에 `Authorization: Bearer <토큰>` 필요(비밀) | `openssl rand -hex 32` |

## 옵션 A. PaaS 원클릭 (가장 빠름) — Render / Railway

둘 다 무료 티어가 있고 HTTPS·도메인을 자동 발급한다.

**Render.com — Blueprint(권장)**

저장소 루트의 `render.yaml` 을 이용하면 한 번에 서비스가 생긴다.
1. [render.com](https://render.com)에 GitHub 계정으로 가입·로그인
2. **New > Blueprint** → 이 저장소를 선택 → `render.yaml` 인식 확인 → **Apply**
3. 대시보드에 `smart-rice-backend` Web Service가 배포된다
4. 환경변수 `API_TOKEN` 이 비어 있으면 인증 없이 열린 상태(개발용). 설정하려면 서비스 콘솔에서 값을 입력 후 재배포
5. 배포 완료 후 `https://smart-rice-backend.onrender.com` URL 사용
6. 앱 빌드 시:
   ```
   flutter build web --release --base-href /smart-rice-ai/ \
     --dart-define=API_BASE_URL=https://smart-rice-backend.onrender.com \
     --dart-define=API_TOKEN=<설정했다면>
   ```

> 무료 티어는 디스크가 휘발성이라 재시작 시 SQLite 계정/논/기기 데이터가
> 지워질 수 있다. 데모·개발용으로 적합. 영구 저장이 필요하면 `DB_PATH` 를
> Render PostgreSQL 등 외부 DB로 바꾼다.

**Render.com — Web Service (수동)**
1. 저장소를 연결하고 새 **Web Service** 생성
2. 루트 디렉터리: `backend`, 환경: `Python 3`
3. 시작 명령: `uvicorn main:app --host 0.0.0.0 --port 8000`
4. 환경변수: `API_TOKEN=...`
5. 배포 → `https://smart-rice-xxxx.onrender.com` 발급
6. 앱 빌드 시:
   ```
   flutter build web --release --base-href /smart-rice-ai/ \
     --dart-define=API_BASE_URL=https://smart-rice-xxxx.onrender.com \
     --dart-define=API_TOKEN=...
   ```

**Railway.app**
- 같은 방식. 프로젝트 루트를 `backend`로, 시작 명령만 지정하면 된다.

## 옵션 B. VPS + Docker + Caddy (제어권 필요 시)

1. 서버 준비(Ubuntu 22.04+, 포트 80/443/8000 오픈)
2. 이미지 빌드·실행:
   ```bash
   docker build -t smart-rice-backend backend
   docker run -d --name smart-rice \
     -e API_TOKEN=<random> -p 8000:8000 smart-rice-backend
   ```
3. Caddy로 자동 HTTPS 리버스 프록시:
   ```
   # Caddyfile
   smart-rice.example.com {
       reverse_proxy 127.0.0.1:8000
   }
   ```
4. `API_TOKEN` 값만큼 앱 빌드 옵션에 넣어 준다.

## 검증

백엔드가 떠 있으면:
```bash
curl -s https://<you>.onrender.com/health
# → {"ok":true}

# 토큰 미전달 시 401
curl -s https://<you>.onrender.com/api/notifications
# → {"detail":"unauthorized"}

# 토큰 전달 시 200
curl -s -H "Authorization: Bearer <token>" \
  https://<you>.onrender.com/api/notifications
```

## 로컬 개발 시 (백엔드 + 하드웨어 확인)

```bash
# 터미널 1 — 백엔드(토큰 없이 오픈)
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000

# 터미널 2 — 시뮬레이터(또는 실제 ESP32가 POST)
python device_simulator.py --paddy paddy_a

# 터미널 3 — 앱을 실제 백엔드에 연결
cd ..
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

토큰을 걸고 싶다면 모든 runner에 `--dart-define=API_TOKEN=...` / `API_TOKEN=...` 환경변수를 붙인다.