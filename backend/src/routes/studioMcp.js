/**
 * Studio MCP API — Roblox Studio와의 통신 엔드포인트
 *
 * StudioTcpClient 서비스를 사용하여 직접 TCP 통신
 * Studio MCP 중계 서버(rbxBStudio-mcp) 불필요
 */

const express = require("express");
const router = express.Router();
const { getClient, connectionCheckMiddleware } = require("../services/StudioTcpClient");
const { generateStudioLuaScript } = require("../services/blenderService");

// ─── Studio MCP 상태 확인 ─────────────────────────────────────
router.get("/status", async (req, res) => {
    const client = getClient();

    try {
        const status = await client.getStatus();
        res.json({
            success: true,
            ...status,
        });
    } catch (error) {
        res.json({
            success: false,
            connected: false,
            error: error.message,
            hint: "Roblox Studio가 실행 중이지 않거나 MCP Plugin이 활성화되지 않았습니다.",
        });
    }
});

// ─── Studio에서 Lua 코드 실행 ───────────────────────────────────
router.post("/run-code", async (req, res) => {
    const { code } = req.body;

    if (!code) {
        return res.status(400).json({
            success: false,
            error: "missing_code",
        });
    }

    console.log("[studioMcp] Lua 코드 실행 요청:", code.substring(0, 100) + "...");

    const client = getClient({ debug: true });

    try {
        const output = await client.runCode(code);

        console.log("[studioMcp] Lua 실행 결과:", output);

        res.json({
            success: true,
            output,
        });

    } catch (error) {
        console.error("[studioMcp] Lua 실행 실패:", error.message);
        res.status(500).json({
            success: false,
            error: error.message,
            hint: "Studio MCP Plugin이 활성화되어 있는지 확인하세요.",
        });
    }
});

// ─── 모델 삽입 ───────────────────────────────────────────────────
router.post("/insert-model", async (req, res) => {
    const { query } = req.body;

    if (!query) {
        return res.status(400).json({
            success: false,
            error: "missing_query",
        });
    }

    console.log("[studioMcp] 모델 삽입 요청:", query);

    const client = getClient({ debug: true });

    try {
        const result = await client.insertModel(query);

        console.log("[studioMcp] 모델 삽입 결과:", result);

        res.json({
            success: true,
            result,
        });

    } catch (error) {
        console.error("[studioMcp] 모델 삽입 실패:", error.message);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ─── FBX Import + Lua 자동 실행 통합 ─────────────────────────────
router.post("/import-and-setup", async (req, res) => {
    const { filename, spec } = req.body;

    if (!filename || !spec) {
        return res.status(400).json({
            success: false,
            error: "missing_params",
            required: ["filename", "spec"],
        });
    }

    console.log("[studioMcp] Import + 자동 설정 요청:", filename);

    // 1. Lua 스크립트 생성
    const luaScript = generateStudioLuaScript(spec, filename);

    // 2. 연결 상태 확인
    const client = getClient();

    try {
        const status = await client.getStatus();

        if (!status.connected) {
            // 연결 안 됨: Lua 스크립트만 반환
            return res.json({
                success: false,
                autoExecuted: false,
                message: "Lua 스크립트 생성 완료 (Studio 연결 안됨)",
                luaScript,
                error: "Studio가 실행 중이지 않습니다.",
                errorHint: "Roblox Studio를 실행하고 MCP Plugin을 활성화하세요.",
                instructions: {
                    step1: "1. Roblox Studio에서 Avatar → Import 3D 클릭",
                    step2: `2. 파일 선택: ${filename}`,
                    step3: "3. Import된 모델 선택",
                    step4: "4. 아래 Lua 스크립트를 Command Bar에 붙여넣고 실행",
                },
            });
        }

        // 연결됨: 자동 실행
        const runResult = await client.runCode(luaScript);

        res.json({
            success: true,
            autoExecuted: true,
            message: "Studio에서 Lua 스크립트가 자동 실행되었습니다.",
            luaScript,
            studioExecution: runResult,
        });

    } catch (error) {
        // 오류 발생: Lua 스크립트만 반환
        res.json({
            success: false,
            autoExecuted: false,
            message: "Lua 스크립트 생성 완료 (Studio 연결 실패)",
            luaScript,
            error: error.message,
            errorHint: "Studio MCP가 실행 중인지 확인하세요.",
            instructions: {
                step1: "1. Roblox Studio에서 Avatar → Import 3D 클릭",
                step2: `2. 파일 선택: ${filename}`,
                step3: "3. Import된 모델 선택",
                step4: "4. 아래 Lua 스크립트를 Command Bar에 붙여넣고 실행",
            },
        });
    }
});

// ─── 배치 실행 (여러 Lua 코드 순차 실행) ───────────────────────────
router.post("/batch", async (req, res) => {
    const { commands } = req.body;

    if (!Array.isArray(commands) || commands.length === 0) {
        return res.status(400).json({
            success: false,
            error: "missing_commands",
        });
    }

    console.log("[studioMcp] 배치 실행 요청:", commands.length, "개 명령");

    const client = getClient({ debug: true });

    try {
        const results = await client.runBatch(commands);

        res.json({
            success: true,
            results,
        });

    } catch (error) {
        console.error("[studioMcp] 배치 실행 실패:", error.message);
        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// ─── 연결 상태 미들웨어 테스트 엔드포인트 ───────────────────────────
router.get("/check", connectionCheckMiddleware, (req, res) => {
    res.json({
        connected: req.studioConnected === true,
        message: req.studioConnected
            ? "Studio MCP에 연결됨"
            : "Studio MCP에 연결되지 않음",
    });
});

module.exports = router;
