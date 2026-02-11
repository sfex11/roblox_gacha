/**
 * 인메모리 캐시 (TTL 지원)
 * 키: "templateId:locale:theme:tone" → 값: 생성된 텍스트 배열
 *
 * 프로덕션에서는 Redis로 교체 권장
 */

const config = require("./config");

class TextCache {
    constructor(ttlSeconds) {
        this.ttl = (ttlSeconds || config.cacheTtl) * 1000;
        this.cache = new Map();
    }

    _makeKey(templateId, locale, theme, tone) {
        return `${templateId}:${locale || "ko"}:${theme || "default"}:${tone || "default"}`;
    }

    get(templateId, locale, theme, tone) {
        const key = this._makeKey(templateId, locale, theme, tone);
        const entry = this.cache.get(key);

        if (!entry) return null;
        if (Date.now() - entry.createdAt > this.ttl) {
            this.cache.delete(key);
            return null;
        }

        // 캐시된 텍스트 중 랜덤 하나 반환
        const texts = entry.texts;
        if (texts.length === 0) return null;
        return texts[Math.floor(Math.random() * texts.length)];
    }

    set(templateId, locale, theme, tone, textData) {
        const key = this._makeKey(templateId, locale, theme, tone);
        const entry = this.cache.get(key);

        if (entry && Date.now() - entry.createdAt <= this.ttl) {
            // 기존 엔트리에 추가 (최대 10개)
            if (entry.texts.length < 10) {
                entry.texts.push(textData);
            }
        } else {
            this.cache.set(key, {
                texts: [textData],
                createdAt: Date.now(),
            });
        }
    }

    // 캐시 통계
    stats() {
        let total = 0;
        let expired = 0;
        const now = Date.now();
        for (const [, entry] of this.cache) {
            total += entry.texts.length;
            if (now - entry.createdAt > this.ttl) expired++;
        }
        return { keys: this.cache.size, totalTexts: total, expired };
    }

    // 만료된 항목 정리
    cleanup() {
        const now = Date.now();
        for (const [key, entry] of this.cache) {
            if (now - entry.createdAt > this.ttl) {
                this.cache.delete(key);
            }
        }
    }
}

module.exports = new TextCache();
