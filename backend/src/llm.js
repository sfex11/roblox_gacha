/**
 * LLM 텍스트 생성 모듈 — GLM-4.7 (Z.ai) API
 * OpenAI 호환 API 사용
 */

const OpenAI = require("openai");
const config = require("./config");
const cache = require("./cache");
const { validateLlmResponse } = require("./filter");

let glmClient = null;

function getGlmClient() {
    if (!glmClient) {
        glmClient = new OpenAI({
            apiKey: config.zaiApiKey,
            baseURL: config.llm.glmBaseUrl,
            timeout: 15000, // 15초 타임아웃
        });
    }
    return glmClient;
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
    const cached = cache.get(templateId, locale, theme, tone);
    if (cached) {
        return { success: true, data: cached, source: "cache" };
    }

    // 2. LLM 호출
    const toneGuide = TONE_GUIDES[tone] || TONE_GUIDES.default;
    const keywordStr =
        keywords.length > 0 ? `키워드: ${keywords.join(", ")}` : "";

    const systemPrompt = `너는 가차 게임의 아이템 텍스트 작성자다. ${toneGuide}
반드시 JSON 형식으로만 출력하라. 다른 텍스트 없이 JSON만.
출력 형식: {"name":"string","description":"string","flavorText":"string","tagsSuggested":["string"]}`;

    const userPrompt = `카테고리: ${category}
희귀도: ${rarity}
기본 이름: ${baseName}
${keywordStr}
위 아이템의 고유한 이름, 설명(1~2문장), 대사(캐릭터가 말하는 것처럼)를 생성하라.
tagsSuggested에는 관련 태그 2~3개를 넣어라.`;

    try {
        console.log("[llm.js] GLM 클라이언트 가져오는 중...");
        const client = getGlmClient();

        console.log("[llm.js] GLM API 호출 시작 - model:", config.llm.glmModel);
        const response = await client.chat.completions.create({
            model: config.llm.glmModel,
            messages: [
                { role: "system", content: systemPrompt },
                { role: "user", content: userPrompt },
            ],
            max_completion_tokens: config.llm.maxTokens,  // GLM-4.7용 파라미터
            temperature: config.llm.temperature,
        });

        console.log("[llm.js] GLM API 응답 수신 - choices 수:", response.choices?.length);

        // GLM-4.7은 reasoning_content에 응답이 담겨 있음
        const message = response.choices[0]?.message || {};
        const text = message.reasoning_content || message.content || "";
        console.log("[llm.js] 생성된 텍스트 길이:", text.length);

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
        cache.set(templateId, locale, theme, tone, validation.data);

        return { success: true, data: validation.data, source: "llm" };
    } catch (err) {
        console.error("[llm.js] LLM API 호출 실패:", err.message);
        console.error("[llm.js] 에러 스택:", err.stack);
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

module.exports = { generateItemText, batchGenerate, getGlmClient };
