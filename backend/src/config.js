// 환경 변수 기본값
const config = {
    port: parseInt(process.env.PORT || "3001", 10),
    zaiApiKey: process.env.ZAI_API_KEY || "", // GLM-4.7용 API 키
    anthropicApiKey: process.env.ANTHROPIC_API_KEY || "", // 폴백용
    robloxSharedSecret: process.env.ROBLOX_SHARED_SECRET || "dev-secret",
    authMode: process.env.ROBLOX_AUTH_MODE || "simple", // "simple" | "signature"
    cacheTtl: parseInt(process.env.CACHE_TTL || "3600", 10),
    llmTimeout: parseInt(process.env.LLM_TIMEOUT || "30000", 10),  // 30초로 증가

    // LLM 프롬프트 설정
    llm: {
        provider: "glm", // "glm" | "anthropic"
        glmBaseUrl: "https://api.z.ai/api/coding/paas/v4",
        glmModel: "glm-4.7",
        anthropicModel: "claude-sonnet-4-5-20250929",
        maxTokens: 1000,  // GLM-4.7 reasoning 모델은 더 많은 토큰 필요
        temperature: 0.7,  // 낮춰서 더 결정적인 출력
    },

    // 레이트 리밋
    rateLimit: {
        windowMs: 60 * 1000,
        maxRequests: 30,
    },

    // 텍스트 제한
    textLimits: {
        nameMaxLen: 20,
        descriptionMaxLen: 120,
        flavorMaxLen: 80,
    },

    // 금칙어 (기본)
    bannedPatterns: [
        /개인정보|주민등록|전화번호|주소/i,
        /시발|씨발|병신|지랄/i,
        /sex|porn|nude|nsfw/i,
        /자살|자해|죽이/i,
        /마약|대마|필로폰/i,
        /도박.*현금|현금.*거래|robux.*거래/i,
    ],
};

if (config.robloxSharedSecret === "dev-secret") {
    console.warn("[config] 경고: 기본 시크릿 'dev-secret' 사용 중. 프로덕션에서는 ROBLOX_SHARED_SECRET 환경변수를 설정하세요.");
}

module.exports = config;
