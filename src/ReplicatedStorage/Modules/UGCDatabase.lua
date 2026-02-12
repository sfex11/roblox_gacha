--[[
    UGCDatabase.lua
    UGC 아이템 동적 관리 모듈
    - 백엔드에서 생성된 UGC 아이템 등록
    - 가차 풀에 UGC 아이템 추가/제거
    - UGC 아이템 메타데이터 관리
]]

local Constants = require(script.Parent.Constants)
local Rarity = Constants.Rarity
local UGCType = Constants.UGCType

local UGCDatabase = {}

-- 등록된 UGC 아이템 저장소
UGCDatabase.Items = {}

-- UGC ID 카운터
UGCDatabase._nextId = 1

-- UGC 타입별 인덱스
UGCDatabase._byType = {}

-- 희귀도별 인덱스
UGCDatabase._byRarity = {}

--[[
    UGC 아이템 등록
    @param spec {
        name: string,           -- 아이템 이름
        description: string,    -- 설명
        flavorText: string,     -- 플레이버 텍스트
        rarity: string,         -- 희귀도 (Common/Rare/Epic/Legendary/Mythic)
        ugcType: string,        -- UGC 타입 (Hat/Hair/Face/Back/...)
        assetId: string?,       -- Roblox Asset ID (업로드 후)
        fbxPath: string?,       -- 원본 FBX 경로
        visualSpec: table?,     -- 런타임 절차적(Procedural) 생성용 스펙 (shape/style/motifs/vfx 등)
        stats: table?,          -- 추가 스탯
        weight: number?,        -- 가차 풀 가중치 (기본 100)
    }
    @return string templateId
]]
function UGCDatabase.RegisterItem(spec)
    if not spec.name or not spec.rarity or not spec.ugcType then
        warn("[UGCDatabase] 필수 필드 누락: name, rarity, ugcType 필요")
        return nil
    end

    -- 템플릿 ID 생성
    local templateId = string.format("UGC_%s_%04d", spec.ugcType:upper(), UGCDatabase._nextId)
    UGCDatabase._nextId = UGCDatabase._nextId + 1

    -- 아이템 데이터 생성
    local item = {
        id = templateId,
        category = Constants.Category.UGC,
        rarity = spec.rarity,
        name = spec.name,
        description = spec.description or "AI가 생성한 특별한 아이템",
        flavorText = spec.flavorText or "이 아이템은 AI가 만들었습니다.",
        ugcType = spec.ugcType,
        assetId = spec.assetId,
        fbxPath = spec.fbxPath,
        visualSpec = spec.visualSpec,
        stats = spec.stats or {},
        weight = spec.weight or 100,
        createdAt = os.time(),
        setId = nil,  -- 추후 세트 시스템 연동
    }

    -- 저장소에 추가
    UGCDatabase.Items[templateId] = item

    -- 인덱스 업데이트
    if not UGCDatabase._byType[spec.ugcType] then
        UGCDatabase._byType[spec.ugcType] = {}
    end
    table.insert(UGCDatabase._byType[spec.ugcType], templateId)

    if not UGCDatabase._byRarity[spec.rarity] then
        UGCDatabase._byRarity[spec.rarity] = {}
    end
    table.insert(UGCDatabase._byRarity[spec.rarity], templateId)

    print(string.format("[UGCDatabase] UGC 아이템 등록: %s (%s - %s)",
        item.name, item.rarity, item.ugcType))

    return templateId
end

--[[
    백엔드 API 응답으로 UGC 등록
    @param apiResponse table - 백엔드 /api/modeling/generate 응답
    @return string templateId
]]
function UGCDatabase.RegisterFromAPI(apiResponse)
    if not apiResponse or not apiResponse.spec then
        warn("[UGCDatabase] 잘못된 API 응답")
        return nil
    end

    local spec = apiResponse.spec
    return UGCDatabase.RegisterItem({
        name = spec.name,
        description = spec.description,
        flavorText = spec.flavorText or "AI가 생성한 아이템",
        rarity = spec.rarity or Rarity.Rare,
        ugcType = spec.category or UGCType.Hat,
        fbxPath = apiResponse.fbxPath,
        visualSpec = spec,
        stats = spec.stats or {},
        weight = spec.weight or 100,
    })
end

--[[
    UGC 아이템 조회
    @param templateId string
    @return table|nil
]]
function UGCDatabase.GetItem(templateId)
    return UGCDatabase.Items[templateId]
end

--[[
    모든 UGC 아이템 조회
    @return table
]]
function UGCDatabase.GetAll()
    return UGCDatabase.Items
end

--[[
    타입별 UGC 아이템 조회
    @param ugcType string
    @return table
]]
function UGCDatabase.GetByType(ugcType)
    return UGCDatabase._byType[ugcType] or {}
end

--[[
    희귀도별 UGC 아이템 조회
    @param rarity string
    @return table
]]
function UGCDatabase.GetByRarity(rarity)
    return UGCDatabase._byRarity[rarity] or {}
end

--[[
    가차 풀용 아이템 목록 반환
    @return table {{templateId, weight}, ...}
]]
function UGCDatabase.GetGachaPoolItems()
    local items = {}
    for templateId, item in pairs(UGCDatabase.Items) do
        table.insert(items, {
            templateId = templateId,
            weight = item.weight,
        })
    end
    return items
end

--[[
    UGC 아이템 삭제
    @param templateId string
    @return boolean
]]
function UGCDatabase.RemoveItem(templateId)
    local item = UGCDatabase.Items[templateId]
    if not item then
        return false
    end

    -- 인덱스에서 제거
    if UGCDatabase._byType[item.ugcType] then
        for i, id in ipairs(UGCDatabase._byType[item.ugcType]) do
            if id == templateId then
                table.remove(UGCDatabase._byType[item.ugcType], i)
                break
            end
        end
    end

    if UGCDatabase._byRarity[item.rarity] then
        for i, id in ipairs(UGCDatabase._byRarity[item.rarity]) do
            if id == templateId then
                table.remove(UGCDatabase._byRarity[item.rarity], i)
                break
            end
        end
    end

    -- 저장소에서 제거
    UGCDatabase.Items[templateId] = nil

    print(string.format("[UGCDatabase] UGC 아이템 삭제: %s", templateId))
    return true
end

--[[
    등록된 UGC 아이템 수
    @return number
]]
function UGCDatabase.GetCount()
    local count = 0
    for _ in pairs(UGCDatabase.Items) do
        count = count + 1
    end
    return count
end

-- 샘플 UGC 아이템 초기화 (테스트용)
local function initSampleItems()
    -- Common (일반)
    UGCDatabase.RegisterItem({
        name = "단순한 챙 모자",
        description = "AI가 디자인한 심플한 챙 모자",
        flavorText = "햇살을 가리는 최고의 선택",
        rarity = Rarity.Common,
        ugcType = UGCType.Hat,
        stats = { sunProtection = 5 },
        weight = 100,
    })

    -- Rare (레어)
    UGCDatabase.RegisterItem({
        name = "귀여운 고양이 귀",
        description = "AI가 디자인한 귀여운 고양이 귀 액세서리",
        flavorText = "냥냥냥~",
        rarity = Rarity.Rare,
        ugcType = UGCType.Hat,
        stats = { cuteness = 10 },
        weight = 100,
    })

    -- Epic (에픽)
    UGCDatabase.RegisterItem({
        name = "우주 탐험가 헬멧",
        description = "AI가 디자인한 우주 탐험용 헬멧",
        flavorText = "별을 향해!",
        rarity = Rarity.Epic,
        ugcType = UGCType.Hat,
        stats = { defense = 15 },
        weight = 80,
    })

    UGCDatabase.RegisterItem({
        name = "신비한 보석 머리띠",
        description = "AI가 생성한 반짝이는 보석 머리띠",
        flavorText = "빛이 머무는 곳",
        rarity = Rarity.Epic,
        ugcType = UGCType.Hat,
        stats = { magic = 20 },
        weight = 70,
    })

    -- Legendary (전설)
    UGCDatabase.RegisterItem({
        name = "화려한 황금 왕관",
        description = "AI가 생성한 화려한 황금 왕관",
        flavorText = "왕의 자격",
        rarity = Rarity.Legendary,
        ugcType = UGCType.Hat,
        stats = { majesty = 50 },
        weight = 50,
    })

    -- Mythic (신화)
    UGCDatabase.RegisterItem({
        name = "용의 뿔 헬멧",
        description = "AI가 창조한 고대 용의 뿔이 달린 신화의 헬멧",
        flavorText = "천년의 용의 힘이 깃들어 있다",
        rarity = Rarity.Mythic,
        ugcType = UGCType.Hat,
        stats = { dragonPower = 100 },
        weight = 20,
    })

    UGCDatabase.RegisterItem({
        name = "천사의 고리",
        description = "AI가 디자인한 빛나는 천사의 고리 헤어피스",
        flavorText = "신성한 빛이 당신을 감쌉니다",
        rarity = Rarity.Mythic,
        ugcType = UGCType.Hat,
        stats = { holiness = 80 },
        weight = 15,
    })
end

-- 초기화 시 샘플 아이템 로드
initSampleItems()

return UGCDatabase
