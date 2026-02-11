# Studio 직접 통신 사용 가이드

## 📋 개요

Claude Desktop 없이 백엔드에서 **직접 Roblox Studio Plugin과 HTTP 통신**하는 방식입니다.

### 아키텍처 비교

#### 기존 방식 (Claude Desktop 필요)
```
Claude Desktop ←(stdio)→ Studio MCP ←(HTTP:44755)→ Roblox Studio Plugin
```

#### 새로운 방식 (Claude Desktop 불필요)
```
백엔드 API ←(HTTP)→ StudioTcpClient ←(HTTP:44755)→ Studio MCP (HTTP-only) ←→ Roblox Studio Plugin
```

## 🚀 설치 및 실행 방법

### 1. Roblox Studio Plugin 설치 (최초 1회)

Studio MCP Plugin을 Studio에 설치해야 합니다.

```bash
cd tools/StudioMCP
cargo build --release
```

그 다음:
```bash
./target/release/rbx-studio-mcp
```

이 명령을 실행하면 Plugin이 자동으로 Studio에 설치됩니다. 설치 후 Roblox Studio를 다시 시작하세요.

### 2. Studio MCP HTTP 서버 시작

백엔드에서 직접 통신하려면 MCP를 HTTP-only 모드로 실행해야 합니다:

```bash
cd tools/StudioMCP
./target/release/rbx-studio-mcp --http-only
```

**백그라운드 실행:**
```bash
nohup ./target/release/rbx-studio-mcp --http-only > /tmp/mcp_http.log 2>&1 &
```

### 3. 백엔드 서버 시작

```bash
cd backend
npm run dev
```

### 4. Roblox Studio 실행 및 Plugin 활성화

1. **Roblox Studio 실행**
2. **Plugins 탭** → **MCP** 플러그인 활성화

### 5. 연결 확인

```bash
curl http://localhost:3001/api/studio-mcp/status
```

**응답 (연결됨):**
```json
{
  "success": true,
  "connected": true
}
```

## 🔌 백엔드 API 엔드포인트

### 엔드포인트

| 엔드포인트 | 메서드 | 설명 |
|-----------|--------|------|
| `GET /api/studio-mcp/status` | GET | Studio 연결 상태 확인 |
| `POST /api/studio-mcp/run-code` | POST | Studio에서 Lua 코드 실행 |
| `POST /api/studio-mcp/insert-model` | POST | Studio에서 모델 삽입 |
| `POST /api/studio-mcp/import-and-setup` | POST | FBX Import + Lua 자동 설정 |
| `POST /api/studio-mcp/batch` | POST | 배치 Lua 코드 실행 |

### 1. 연결 상태 확인

```bash
curl http://localhost:3001/api/studio-mcp/status
```

### 2. Lua 코드 실행

```bash
curl -X POST http://localhost:3001/api/studio-mcp/run-code \
  -H "Content-Type: application/json" \
  -d '{
    "code": "print(\"Hello from Studio!\")"
  }'
```

**응답:**
```json
{
  "success": true,
  "output": "Hello from Studio!"
}
```

### 3. 모델 삽입

```bash
curl -X POST http://localhost:3001/api/studio-mcp/insert-model \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Sword"
  }'
```

### 4. FBX Import + 자동 설정

```bash
curl -X POST http://localhost:3001/api/studio-mcp/import-and-setup \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "화려한_황금_왕관.fbx",
    "spec": {
      "name": "화려한 황금 왕관",
      "description": "전설级的 황금 왕관",
      "rarity": "Legendary",
      "category": "Hat"
    }
  }'
```

### 5. 배치 실행

```bash
curl -X POST http://localhost:3001/api/studio-mcp/batch \
  -H "Content-Type: application/json" \
  -d '{
    "commands": [
      {"code": "print(\"First command\")"},
      {"code": "print(\"Second command\")"}
    ]
  }'
```

## 🧪 테스트 절차

### 전체 파이프라인 테스트

1. **서버 시작**
   ```bash
   cd backend && npm run dev
   ```

2. **Roblox Studio 실행** + MCP Plugin 활성화

3. **연결 확인**
   ```bash
   curl http://localhost:3001/api/studio-mcp/status
   ```

4. **FBX 생성**
   ```bash
   curl -X POST http://localhost:3001/api/modeling/generate \
     -H "Content-Type: application/json" \
     -H "X-Api-Secret: dev-secret" \
     -d '{"prompt": "테스트 아이템", "rarity": "Rare", "category": "Hat"}'
   ```

5. **Studio에서 FBX Import** (수동)
   - Avatar → Import 3D
   - 생성된 FBX 파일 선택

6. **Lua 자동 설정**
   ```bash
   curl -X POST http://localhost:3001/api/studio-mcp/run-code \
     -H "Content-Type: application/json" \
     -d '{
       "code": "local sss=game:GetService(\"ServerScriptService\"); local m=nil; for _,d in ipairs(sss:GetDescendants()) do if d:IsA(\"ModuleScript\") and d.Name==\"UGCTools\" then m=d break end end; assert(m,\"UGCTools not found under ServerScriptService\"); local UGCTools=require(m); UGCTools.SetupSelected({name=\"테스트\", description=\"테스트 아이템\", rarity=\"Rare\", category=\"Hat\"})"
     }'
   ```

7. **(중요) 런타임 장착용으로 Accessory 링크**
   - Accessory Fitting Tool로 생성된 `Accessory`를 선택한 뒤 Command Bar에서 실행:
   ```lua
   local sss = game:GetService("ServerScriptService")
   local UGCToolsModule = sss:FindFirstChild("GachaServer") and sss.GachaServer:FindFirstChild("UGCTools")
   if not UGCToolsModule then
       for _, d in ipairs(sss:GetDescendants()) do
           if d:IsA("ModuleScript") and d.Name == "UGCTools" then
               UGCToolsModule = d
               break
           end
       end
   end
   local UGCTools = require(UGCToolsModule)
   UGCTools.LinkSelectedAccessory("UGC_HAT_0001", { destination = "ServerStorage" })
   ```
   - 이렇게 하면 `ServerStorage.UGCAssets`에 `templateId`로 연결된 Accessory가 저장됩니다.
   - 게임 실행 중 장착 시 `UGCEquipService`가 이 Accessory를 우선 사용합니다.

8. **(선택) 업로드한 UGC는 `assetId`로 장착**
   - UGC를 Roblox에 업로드/퍼블리시해서 `assetId`를 확보했다면, 서버에서 템플릿에 `assetId`를 넣으면 됩니다.
   - Studio Command Bar 예시:
   ```lua
   local UGCDatabase = require(game.ReplicatedStorage.Modules.UGCDatabase)
   UGCDatabase.Items["UGC_HAT_0001"].assetId = "1234567890" -- 또는 1234567890
   ```
   - 이후 장착 시 `UGCEquipService`가 `InsertService` → `HumanoidDescription` 순으로 장착을 시도합니다.

---

## ⚡ FBX 없이 즉시 "멋진" UGC 생성 (추천)

Blender/FBX Import 없이도, **LLM이 만든 스펙(shape/style/motifs/vfx)** 기반으로 게임 내에서 절차적으로(Procedural) 액세서리를 생성해서 바로 장착할 수 있습니다.

### 준비

1) 백엔드 실행
```bash
cd backend
npm run dev
```

2) Studio에서 HTTP 요청 허용
- `Game Settings` → `Security` → `Allow HTTP Requests` 활성화

### 사용 (Studio 플레이 중 채팅)

`!ugc_gen [<category>] [<rarity>] <프롬프트...>`

예시:
- `!ugc_gen 귀여운 고양이 귀`
- `!ugc_gen Hat Epic cyber cat crown`
- `!ugc_gen Back Legendary 천사 날개 제트팩`

동작:
- 백엔드 `/api/modeling/guide`로 스펙 생성
- `UGCDatabase`에 등록 + 가차 풀 갱신
- (테스트 편의) **인벤토리에 즉시 지급 + 즉시 장착**

장착 확인:
- 인벤토리에서 아이템 카드 클릭으로 재장착 가능 (`RequestEquip`)

## 📁 파일 구조

```
backend/src/services/StudioTcpClient.js  # 직접 TCP 통신 클라이언트
backend/src/routes/studioMcp.js          # Studio MCP API 라우터
src/ServerScriptService/UGCTools.lua     # Studio 유틸리티 모듈
tools/StudioMCP/                         # Studio MCP 소스 (Plugin 설치용)
```

## ⚠️ 제한사항

1. **Studio MCP HTTP 서버 필요**: `--http-only` 모드로 실행해야 함
2. **Roblox Studio 필요**: Studio가 실행 중이어야 통신 가능
3. **Plugin 활성화**: MCP Plugin이 활성화되어 있어야 함
4. **동시 실행 제약**: 하나의 Studio 인스턴스만 지원

## 🔧 문제 해결

### Studio 연결 안됨

1. Studio MCP HTTP 서버가 실행 중인지 확인:
   ```bash
   lsof -i :44755
   ```
2. Roblox Studio가 실행 중인지 확인
3. Plugins 탭에서 MCP가 활성화되어 있는지 확인

### 포트 충돌

```bash
# 포트 44755 사용 중인 프로세스 확인
lsof -i :44755

# MCP 서버 종료
pkill -f rbx-studio-mcp

# 다시 시작
./target/release/rbx-studio-mcp --http-only
```

## 🔑 핵심 차이점

| 특징 | 기존 방식 | 새로운 방식 |
|------|----------|------------|
| Claude Desktop | 필수 | 불필요 |
| Studio MCP 바이너리 | stdio 모드 | HTTP-only 모드 |
| 통신 경로 | Desktop → MCP → Studio | 백엔드 → MCP HTTP → Studio |
| CLI 사용 | 불가능 | 가능 |

## 📚 참고 자료

- [Studio MCP GitHub](https://github.com/Roblox/studio-rust-mcp-server)
- [MCP 프로토콜](https://modelcontextprotocol.io/)
