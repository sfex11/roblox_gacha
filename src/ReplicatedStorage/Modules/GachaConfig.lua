--[[
    GachaConfig.lua
    가차 풀 & 확률 테이블 정의
    서버가 SSOT(Single Source of Truth)로 사용
]]

local Constants = require(script.Parent.Constants)
local Rarity = Constants.Rarity

local GachaConfig = {}

-- 희귀도별 가중치 (총합 10000 = 100.00%)
GachaConfig.RarityWeights = {
    [Rarity.Common]    = 6000,  -- 60%
    [Rarity.Rare]      = 2500,  -- 25%
    [Rarity.Epic]      = 1000,  -- 10%
    [Rarity.Legendary] = 400,   --  4%
    [Rarity.Mythic]    = 100,   --  1%
}

-- 기본 아이템 목록 (정적)
local baseItems = {
    -- 무기
    { templateId = "WPN_SWORD_01",  weight = 100 },
    { templateId = "WPN_BOW_01",    weight = 100 },
    { templateId = "WPN_WAND_01",   weight = 100 },
    { templateId = "WPN_KATANA_01", weight = 100 },
    { templateId = "WPN_STAFF_01",  weight = 100 },
    -- 펫
    { templateId = "PET_CAT_01",     weight = 100 },
    { templateId = "PET_DOG_01",     weight = 100 },
    { templateId = "PET_DRAGON_01",  weight = 100 },
    { templateId = "PET_PHOENIX_01", weight = 100 },
    { templateId = "PET_UNICORN_01", weight = 100 },
    -- 코스튬
    { templateId = "CST_HOOD_01",   weight = 100 },
    { templateId = "CST_ARMOR_01",  weight = 100 },
    { templateId = "CST_ROBE_01",   weight = 100 },
    { templateId = "CST_WING_01",   weight = 100 },
    { templateId = "CST_AURA_01",   weight = 100 },
}

-- 가차 풀 정의
GachaConfig.Pools = {
    standard_v1 = {
        poolId = "standard_v1",
        displayName = "일반 가차",
        description = "모든 아이템이 포함된 기본 가차",
        items = baseItems,  -- 초기화 시 UGC 아이템 추가됨
    },
}

-- 가차 풀에 UGC 아이템 추가
function GachaConfig.RefreshPool(poolId)
    poolId = poolId or "standard_v1"
    local pool = GachaConfig.Pools[poolId]
    if not pool then return end

    -- 기본 아이템으로 리셋
    pool.items = {}
    for _, item in ipairs(baseItems) do
        table.insert(pool.items, item)
    end

    -- UGC 아이템 추가
    local UGCDatabase = require(script.Parent.UGCDatabase)
    local ugcItems = UGCDatabase.GetGachaPoolItems()
    for _, item in ipairs(ugcItems) do
        table.insert(pool.items, item)
    end

    print(string.format("[GachaConfig] 가차 풀 갱신: %d개 아이템 (UGC: %d개)",
        #pool.items, #ugcItems))
end

-- 초기화 시 UGC 아이템 로드
GachaConfig.RefreshPool("standard_v1")

-- 확률표를 % 문자열로 변환 (클라이언트 표시용)
function GachaConfig.GetOddsTable(poolId)
    local pool = GachaConfig.Pools[poolId]
    if not pool then return nil end

    local totalWeight = 0
    for _, w in pairs(GachaConfig.RarityWeights) do
        totalWeight = totalWeight + w
    end

    local odds = {}
    for rarity, weight in pairs(GachaConfig.RarityWeights) do
        odds[rarity] = {
            percent = math.floor((weight / totalWeight) * 10000) / 100,
            displayName = Constants.RarityInfo[rarity].displayName,
        }
    end

    return {
        poolId = poolId,
        poolName = pool.displayName,
        odds = odds,
    }
end

return GachaConfig
