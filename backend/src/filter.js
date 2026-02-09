/**
 * 텍스트 안전 필터
 * LLM 출력을 "신뢰 불가 입력"으로 간주하고 검증
 */

const config = require("./config");

/**
 * 금칙어/민감 패턴 검사
 * @returns {boolean} true면 안전, false면 위반
 */
function isSafe(text) {
    if (!text || typeof text !== "string") return false;

    for (const pattern of config.bannedPatterns) {
        if (pattern.test(text)) return false;
    }
    return true;
}

/**
 * 텍스트 정규화 — 길이 제한, 특수문자 제거
 */
function sanitize(text, maxLen) {
    if (!text || typeof text !== "string") return "";

    // 제어 문자 제거
    let cleaned = text.replace(/[\x00-\x1f\x7f]/g, "");
    // 연속 공백 정리
    cleaned = cleaned.replace(/\s+/g, " ").trim();
    // 길이 제한
    if (maxLen && cleaned.length > maxLen) {
        cleaned = cleaned.slice(0, maxLen);
    }
    return cleaned;
}

/**
 * LLM 응답 전체 검증 + 정규화
 * @returns {{ valid: boolean, data: object|null, reason: string|null }}
 */
function validateLlmResponse(data) {
    if (!data || typeof data !== "object") {
        return { valid: false, data: null, reason: "invalid_format" };
    }

    const name = sanitize(data.name, config.textLimits.nameMaxLen);
    const description = sanitize(
        data.description,
        config.textLimits.descriptionMaxLen,
    );
    const flavorText = sanitize(
        data.flavorText,
        config.textLimits.flavorMaxLen,
    );

    if (!name) {
        return { valid: false, data: null, reason: "empty_name" };
    }

    // 금칙어 검사
    const allText = `${name} ${description} ${flavorText}`;
    if (!isSafe(allText)) {
        return { valid: false, data: null, reason: "banned_content" };
    }

    return {
        valid: true,
        data: {
            name,
            description,
            flavorText,
            tagsSuggested: Array.isArray(data.tagsSuggested)
                ? data.tagsSuggested.slice(0, 5)
                : [],
        },
        reason: null,
    };
}

module.exports = { isSafe, sanitize, validateLlmResponse };
