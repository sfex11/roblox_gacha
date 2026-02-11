# roblox_gacha

Roblox 가차형 컬렉션 게임(MVP) + LLM 텍스트 생성 백엔드(옵션).

## 구조

- Rojo 매핑: `default.project.json`
  - 서버: `src/ServerScriptService/init.server.lua`
  - 클라이언트: `src/StarterPlayer/StarterPlayerScripts/GachaClient/init.client.lua`
  - 공용 모듈: `src/ReplicatedStorage/Modules/*.lua`
- LLM 백엔드(노드): `backend/src/server.js`

## 빠른 실행 (로블록스)

1) Rojo 설치/실행
- `rokit install`
- `rojo serve`

2) Roblox Studio에서 Rojo 플러그인으로 연결

## LLM 백엔드 실행 (선택)

```bash
cd backend
npm install
npm run dev
```

환경 변수 예시:

- `ZAI_API_KEY` (GLM-4.7, 권장)
- `ANTHROPIC_API_KEY` (옵션: provider를 claude로 바꾸는 경우)
- `ROBLOX_SHARED_SECRET` (기본값: `dev-secret`)
- `ROBLOX_AUTH_MODE` (`simple` | `signature`, 기본값: `simple`)

Roblox 서버 설정은 `src/ServerScriptService/LLMClient.lua`의 `LLMClient.Config`에서 맞춥니다.

## UGC (AI 스펙 → Procedural 액세서리)

FBX Import 없이도, 백엔드가 생성한 스펙(shape/style/motifs/vfx)으로 **게임 내에서 즉시 착용 가능한 UGC 액세서리**를 만들 수 있습니다.

1) 백엔드 실행: `cd backend && npm run dev`
2) Studio에서 `Allow HTTP Requests` 켜기
3) Studio 플레이 중 채팅:
   - `!ugc_gen 귀여운 고양이 귀`
   - `!ugc_gen Hat Epic cyber cat crown`

## 데이터 저장 설정

`src/ServerScriptService/GameConfig.lua`에서 조정:

- `forceFreshData`: true면 매 서버 시작마다 새 데이터(테스트용)
- `enableDataStore`: DataStore 저장/로드 활성화
- `dataStoreName`: 저장소 이름(버전 업 시 변경 권장)

## 구현된 기능 (MVP)

- 가차: 확률/풀/중복 처리/재화 차감/결과 반환
- 인벤토리: 아이템 목록 + 장착/해제(클릭)
- 도감: 탭(전체/무기/펫/코스튬) + 세트 탭(진행도 표시)
- 미니게임: 큐 → 세션 → 웨이브 진행(현재는 서버 시뮬레이션) → 보상/결과 표시
- LLM: 서버 결과(아이템 이름/설명/플레이버) 생성 실패 시 폴백
