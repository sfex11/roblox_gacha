// 환경 변수 기본값
const config = {
    port: parseInt(process.env.PORT || "3001", 10),
    anthropicApiKey: process.env.ANTHROPIC_API_KEY || "",
    robloxSharedSecret: process.env.ROBLOX_SHARED_SECRET || "dev-secret",
    cacheTtl: parseInt(process.env.CACHE_TTL || "3600", 10),
    llmTimeout: parseInt(process.env.LLM_TIMEOUT || "5000", 10),

    // LLM 프롬프트 설정
    llm: {
        model: "claude-sonnet-4-5-20250929",
        maxTokens: 300,
        temperature: 0.9,
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

module.exports = config;
