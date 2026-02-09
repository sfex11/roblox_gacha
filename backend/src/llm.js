/**
 * LLM 텍스트 생성 모듈 — Anthropic Claude API
 */

const Anthropic = require("@anthropic-ai/sdk");
const config = require("./config");
const cache = require("./cache");
const { validateLlmResponse } = require("./filter");

let client = null;

function getClient() {
    if (!client) {
        client = new Anthropic({ apiKey: config.anthropicApiKey });
    }
    return client;
}

// 테마별 톤 가이드
const TONE_GUIDES = {
    default: "한국어로 게임다운 톤. 재치있고 짧게.",
    cute: "귀엽고 사랑스러운 톤. 이모티콘 쓰지 말 것.",
    dark: "어둡고 신비로운 톤. 비장하게.",
    heroic: "영웅적이고 웅장한 톤. 힘이 느껴지게.",
    comic: "유머러스하고 밈 감성. 웃기게.",
    cyber: "사이버펑크/디지털 감성. 코드/데이터 비유.",
    fairy: "동화풍. 따뜻하고 몽환적.",
    space: "우주/SF 감성. 광활하고 신비롭게.",
};

/**
 * 아이템 텍스트 생성
 * @param {object} params
 * @param {string} params.templateId - 아이템 템플릿 ID
 * @param {string} params.rarity - 희귀도
 * @param {string} params.category - 카테고리 (Weapon/Pet/Costume)
 * @param {string} params.baseName - 기본 이름 (폴백/참고용)
 * @param {string} [params.theme] - 테마 태그
 * @param {string} [params.locale] - 로캘 (기본 ko)
 * @param {string[]} [params.keywords] - 키워드
 * @param {string} [params.tone] - 톤 (cute/dark/heroic/comic 등)
 */
async function generateItemText(params) {
    const {
        templateId,
        rarity,
        category,
        baseName,
        theme = "default",
        locale = "ko",
        keywords = [],
        tone = "default",
    } = params;

    // 1. 캐시 확인
    const cached = cache.get(templateId, locale, theme);
    if (cached) {
        return { success: true, data: cached, source: "cache" };
    }

    // 2. LLM 호출
    const toneGuide = TONE_GUIDES[tone] || TONE_GUIDES.default;
    const keywordStr =
        keywords.length > 0 ? `키워드: ${keywords.join(", ")}` : "";

    const prompt = `당신은 Roblox 가차 게임의 아이템 텍스트 작가입니다.

아래 아이템에 어울리는 이름/설명/플레이버 텍스트를 한국어로 생성하세요.

## 아이템 정보
- 카테고리: ${category}
- 희귀도: ${rarity}
- 기본 이름 참고: ${baseName}
- 테마: ${theme}
${keywordStr}

## 톤 가이드
${toneGuide}

## 규칙 (반드시 준수)
- name: 최대 20자, 아이템 이름
- description: 최대 120자, 아이템 설명
- flavorText: 최대 80자, 분위기 있는 한 줄 대사
- 욕설, 선정적, 폭력 조장, 개인정보, 실존 브랜드/유명인 금지
- 도박/현금 가치 암시 금지

## 출력 형식 (JSON만 출력)
{"name": "...", "description": "...", "flavorText": "...", "tagsSuggested": ["tag1", "tag2"]}`;

    try {
        const response = await getClient().messages.create({
            model: config.llm.model,
            max_tokens: config.llm.maxTokens,
            temperature: config.llm.temperature,
            messages: [{ role: "user", content: prompt }],
        });

        const text = response.content[0]?.text || "";

        // JSON 추출 (코드블록 감싸기 대응)
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
            return {
                success: false,
                error: "json_parse_failed",
                raw: text,
            };
        }

        const parsed = JSON.parse(jsonMatch[0]);
        const validation = validateLlmResponse(parsed);

        if (!validation.valid) {
            return {
                success: false,
                error: validation.reason,
                raw: text,
            };
        }

        // 3. 캐시 저장
        cache.set(templateId, locale, theme, validation.data);

        return { success: true, data: validation.data, source: "llm" };
    } catch (err) {
        return {
            success: false,
            error: "llm_api_error",
            message: err.message,
        };
    }
}

/**
 * 배치 생성 — 여러 아이템 텍스트를 한 번에 생성 (선생성/오프라인 배치)
 */
async function batchGenerate(items, options = {}) {
    const results = [];
    for (const item of items) {
        const result = await generateItemText({ ...item, ...options });
        results.push({ templateId: item.templateId, ...result });
        // 레이트 리밋 방지 — 요청 간 딜레이
        await new Promise((resolve) => setTimeout(resolve, 500));
    }
    return results;
}

module.exports = { generateItemText, batchGenerate };
