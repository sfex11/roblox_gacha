/**
 * 가차 LLM 백엔드 서버
 *
 * 아키텍처:
 * [Roblox Server] --(HttpService)--> [이 서버] --(SDK)--> [Claude API]
 *
 * 엔드포인트:
 * POST /api/generate     — 단일 아이템 텍스트 생성
 * POST /api/batch         — 배치 생성 (운영/선생성용)
 * GET  /api/odds/:poolId  — 확률표 (프록시/검증용)
 * GET  /api/health        — 헬스체크
 * GET  /api/cache/stats   — 캐시 통계
 */

const express = require("express");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");

const config = require("./config");
const { verifySimple } = require("./auth");
const { generateItemText, batchGenerate } = require("./llm");
const cache = require("./cache");

const app = express();

// 보안 헤더
app.use(helmet());

// JSON 파싱
app.use(express.json({ limit: "1mb" }));

// 레이트 리밋
const limiter = rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: config.rateLimit.maxRequests,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: "rate_limit_exceeded" },
});
app.use("/api/generate", limiter);
app.use("/api/batch", limiter);

// ─── 헬스체크 (인증 불필요) ───────────────────────────
app.get("/api/health", (req, res) => {
    res.json({
        status: "ok",
        uptime: process.uptime(),
        cache: cache.stats(),
    });
});

// ─── 이하 인증 필요 ──────────────────────────────────
app.use("/api/generate", verifySimple);
app.use("/api/batch", verifySimple);
app.use("/api/cache", verifySimple);

// ─── 단일 아이템 텍스트 생성 ─────────────────────────
app.post("/api/generate", async (req, res) => {
    const {
        requestId,
        templateId,
        rarity,
        category,
        baseName,
        theme,
        locale,
        keywords,
        tone,
    } = req.body;

    // 필수 파라미터 검증
    if (!templateId || !rarity || !category || !baseName) {
        return res.status(400).json({
            error: "missing_params",
            required: ["templateId", "rarity", "category", "baseName"],
        });
    }

    const result = await generateItemText({
        templateId,
        rarity,
        category,
        baseName,
        theme,
        locale,
        keywords,
        tone,
    });

    if (result.success) {
        res.json({
            requestId,
            success: true,
            source: result.source,
            text: result.data,
        });
    } else {
        // LLM 실패 시에도 200으로 응답 (Roblox 서버가 폴백 처리)
        res.json({
            requestId,
            success: false,
            error: result.error,
            text: null,
        });
    }
});

// ─── 배치 생성 (운영/선생성용) ───────────────────────
app.post("/api/batch", async (req, res) => {
    const { items, options } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
        return res.status(400).json({ error: "items_required" });
    }

    if (items.length > 50) {
        return res.status(400).json({ error: "batch_too_large", max: 50 });
    }

    const results = await batchGenerate(items, options || {});
    res.json({ success: true, results });
});

// ─── 캐시 통계 ───────────────────────────────────────
app.get("/api/cache/stats", (req, res) => {
    res.json(cache.stats());
});

// ─── 캐시 정리 ───────────────────────────────────────
app.post("/api/cache/cleanup", verifySimple, (req, res) => {
    cache.cleanup();
    res.json({ success: true, stats: cache.stats() });
});

// ─── 서버 시작 ───────────────────────────────────────
app.listen(config.port, () => {
    console.log(`[gacha-backend] 서버 시작: http://localhost:${config.port}`);
    console.log(`[gacha-backend] 모델: ${config.llm.model}`);
    console.log(
        `[gacha-backend] API 키: ${config.anthropicApiKey ? "설정됨" : "미설정"}`,
    );
});

// 캐시 자동 정리 (10분마다)
setInterval(
    () => {
        cache.cleanup();
    },
    10 * 60 * 1000,
);

module.exports = app;
