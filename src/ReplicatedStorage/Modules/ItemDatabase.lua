--[[
    ItemDatabase.lua
    아이템 템플릿 DB — 모든 아이템의 정적 데이터 정의
    Phase 0: 프리셋 텍스트 / Phase 1 이후: LLM 생성 텍스트 대체
]]

local Constants = require(script.Parent.Constants)
local Rarity = Constants.Rarity
local Category = Constants.Category

local ItemDatabase = {}

-- 전체 아이템 템플릿
ItemDatabase.Templates = {

    -------------------------------------------------
    -- 무기 (Weapon) 5종
    -------------------------------------------------
    WPN_SWORD_01 = {
        id = "WPN_SWORD_01",
        category = Category.Weapon,
        rarity = Rarity.Common,
        name = "나무 검",
        description = "평범하지만 믿음직한 나무 검.",
        flavorText = "모든 모험의 시작.",
        stats = { attack = 10 },
        setId = "SET_BEGINNER",
    },
    WPN_BOW_01 = {
        id = "WPN_BOW_01",
        category = Category.Weapon,
        rarity = Rarity.Rare,
        name = "사냥꾼의 활",
        description = "숲의 사냥꾼이 사용하던 정밀한 활.",
        flavorText = "바람을 읽는 자만이 쏠 수 있다.",
        stats = { attack = 18 },
        setId = nil,
    },
    WPN_WAND_01 = {
        id = "WPN_WAND_01",
        category = Category.Weapon,
        rarity = Rarity.Epic,
        name = "불꽃 완드",
        description = "끝에서 작은 불꽃이 피어오르는 마법 지팡이.",
        flavorText = "화염은 창조의 시작이다.",
        stats = { attack = 28 },
        setId = nil,
    },
    WPN_KATANA_01 = {
        id = "WPN_KATANA_01",
        category = Category.Weapon,
        rarity = Rarity.Legendary,
        name = "번개 카타나",
        description = "베는 순간 번개가 내리치는 전설의 검.",
        flavorText = "한 번의 섬광이면 충분하다.",
        stats = { attack = 40 },
        setId = nil,
    },
    WPN_STAFF_01 = {
        id = "WPN_STAFF_01",
        category = Category.Weapon,
        rarity = Rarity.Mythic,
        name = "별의 지팡이",
        description = "밤하늘의 별빛을 담은 신비로운 지팡이.",
        flavorText = "우주의 힘이 손끝에.",
        stats = { attack = 55 },
        setId = nil,
    },

    -------------------------------------------------
    -- 펫 (Pet) 5종
    -------------------------------------------------
    PET_CAT_01 = {
        id = "PET_CAT_01",
        category = Category.Pet,
        rarity = Rarity.Common,
        name = "아기 고양이",
        description = "작고 귀여운 고양이. 가끔 코인을 물어온다.",
        flavorText = "냥~",
        stats = { coinBoost = 5 },
        setId = "SET_BEGINNER",
    },
    PET_DOG_01 = {
        id = "PET_DOG_01",
        category = Category.Pet,
        rarity = Rarity.Rare,
        name = "골든 퍼피",
        description = "황금빛 털을 가진 충실한 강아지.",
        flavorText = "꼬리를 흔들면 행운이 온다.",
        stats = { coinBoost = 10 },
        setId = nil,
    },
    PET_DRAGON_01 = {
        id = "PET_DRAGON_01",
        category = Category.Pet,
        rarity = Rarity.Epic,
        name = "꼬마 드래곤",
        description = "아직 어리지만 불을 뿜을 줄 안다.",
        flavorText = "크면 세상을 태울지도?",
        stats = { coinBoost = 18 },
        setId = nil,
    },
    PET_PHOENIX_01 = {
        id = "PET_PHOENIX_01",
        category = Category.Pet,
        rarity = Rarity.Legendary,
        name = "불사조",
        description = "재에서 다시 태어나는 전설의 새.",
        flavorText = "끝은 곧 새로운 시작.",
        stats = { coinBoost = 28 },
        setId = nil,
    },
    PET_UNICORN_01 = {
        id = "PET_UNICORN_01",
        category = Category.Pet,
        rarity = Rarity.Mythic,
        name = "무지개 유니콘",
        description = "달리면 무지개가 펼쳐지는 신화 속 존재.",
        flavorText = "꿈이 현실이 되는 순간.",
        stats = { coinBoost = 40 },
        setId = nil,
    },

    -------------------------------------------------
    -- 코스튬 (Costume) 5종
    -------------------------------------------------
    CST_HOOD_01 = {
        id = "CST_HOOD_01",
        category = Category.Costume,
        rarity = Rarity.Common,
        name = "모험가 후드",
        description = "어디서나 볼 수 있는 평범한 후드.",
        flavorText = "이게 시작이지.",
        stats = { trail = "none" },
        setId = "SET_BEGINNER",
    },
    CST_ARMOR_01 = {
        id = "CST_ARMOR_01",
        category = Category.Costume,
        rarity = Rarity.Rare,
        name = "기사 갑옷",
        description = "은빛으로 빛나는 견고한 갑옷.",
        flavorText = "명예를 지키는 자의 갑옷.",
        stats = { trail = "silver" },
        setId = nil,
    },
    CST_ROBE_01 = {
        id = "CST_ROBE_01",
        category = Category.Costume,
        rarity = Rarity.Epic,
        name = "마법사 로브",
        description = "보라색 오라가 감도는 마법사의 예복.",
        flavorText = "지혜는 옷에서 시작된다.",
        stats = { aura = "purple" },
        setId = nil,
    },
    CST_WING_01 = {
        id = "CST_WING_01",
        category = Category.Costume,
        rarity = Rarity.Legendary,
        name = "천사 날개",
        description = "등 뒤에서 금빛이 퍼져나오는 날개.",
        flavorText = "하늘에 닿고 싶은 자를 위해.",
        stats = { aura = "gold" },
        setId = nil,
    },
    CST_AURA_01 = {
        id = "CST_AURA_01",
        category = Category.Costume,
        rarity = Rarity.Mythic,
        name = "우주 아우라",
        description = "온몸에서 은하수가 흐르는 전설의 코스튬.",
        flavorText = "별들 사이를 걷는 자.",
        stats = { aura = "rainbow" },
        setId = nil,
    },
}

-- 카테고리별 아이템 인덱스 (빠른 조회용)
ItemDatabase._byCategory = {}
ItemDatabase._byRarity = {}

function ItemDatabase.Init()
    for id, template in pairs(ItemDatabase.Templates) do
        -- 카테고리별
        if not ItemDatabase._byCategory[template.category] then
            ItemDatabase._byCategory[template.category] = {}
        end
        table.insert(ItemDatabase._byCategory[template.category], id)

        -- 희귀도별
        if not ItemDatabase._byRarity[template.rarity] then
            ItemDatabase._byRarity[template.rarity] = {}
        end
        table.insert(ItemDatabase._byRarity[template.rarity], id)
    end

    -- UGC 아이템도 인덱스에 추가
    local UGCDatabase = require(script.Parent.UGCDatabase)
    for templateId, item in pairs(UGCDatabase.GetAll()) do
        -- 카테고리별 (UGC)
        if not ItemDatabase._byCategory[Constants.Category.UGC] then
            ItemDatabase._byCategory[Constants.Category.UGC] = {}
        end
        table.insert(ItemDatabase._byCategory[Constants.Category.UGC], templateId)

        -- 희귀도별
        if not ItemDatabase._byRarity[item.rarity] then
            ItemDatabase._byRarity[item.rarity] = {}
        end
        table.insert(ItemDatabase._byRarity[item.rarity], templateId)
    end
end

function ItemDatabase.GetTemplate(templateId)
    -- 먼저 정적 템플릿에서 검색
    local template = ItemDatabase.Templates[templateId]
    if template then
        return template
    end

    -- UGC 데이터베이스에서 검색
    local UGCDatabase = require(script.Parent.UGCDatabase)
    return UGCDatabase.GetItem(templateId)
end

function ItemDatabase.GetByCategory(category)
    return ItemDatabase._byCategory[category] or {}
end

function ItemDatabase.GetByRarity(rarity)
    return ItemDatabase._byRarity[rarity] or {}
end

function ItemDatabase.GetAll()
    return ItemDatabase.Templates
end

-- 초기화
ItemDatabase.Init()

return ItemDatabase
