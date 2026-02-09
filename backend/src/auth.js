/**
 * 요청 인증 미들웨어 — Roblox 서버 ↔ 백엔드 공유 시크릿 검증
 */

const crypto = require("crypto");
const config = require("./config");

/**
 * HMAC-SHA256 서명 검증 미들웨어
 *
 * Roblox 서버는 요청 시 다음 헤더를 보내야 함:
 * - X-Request-Timestamp: Unix 타임스탬프
 * - X-Request-Signature: HMAC-SHA256(timestamp + ":" + body, sharedSecret)
 */
function verifySignature(req, res, next) {
    const timestamp = req.headers["x-request-timestamp"];
    const signature = req.headers["x-request-signature"];

    if (!timestamp || !signature) {
        return res.status(401).json({ error: "missing_auth_headers" });
    }

    // 타임스탬프 유효성 (5분 이내)
    const now = Math.floor(Date.now() / 1000);
    const reqTime = parseInt(timestamp, 10);
    if (Math.abs(now - reqTime) > 300) {
        return res.status(401).json({ error: "timestamp_expired" });
    }

    // 서명 검증
    const body = JSON.stringify(req.body) || "";
    const payload = `${timestamp}:${body}`;
    const expected = crypto
        .createHmac("sha256", config.robloxSharedSecret)
        .update(payload)
        .digest("hex");

    if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
        return res.status(401).json({ error: "invalid_signature" });
    }

    next();
}

/**
 * 개발 모드용 — 간단한 시크릿 헤더 검증
 */
function verifySimple(req, res, next) {
    const secret = req.headers["x-api-secret"];
    if (secret !== config.robloxSharedSecret) {
        return res.status(401).json({ error: "invalid_secret" });
    }
    next();
}

module.exports = { verifySignature, verifySimple };
