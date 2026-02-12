--[[
    Constants.lua
    공용 상수 정의 (희귀도, 카테고리, 재화, RemoteEvent 이름 등)
]]

local Constants = {}

-- 희귀도 등급
Constants.Rarity = {
    Common = "Common",
    Rare = "Rare",
    Epic = "Epic",
    Legendary = "Legendary",
    Mythic = "Mythic",
}

-- 희귀도 표시 정보
Constants.RarityInfo = {
    [Constants.Rarity.Common] = {
        order = 1,
        displayName = "일반",
        color = Color3.fromRGB(180, 180, 180),
    },
    [Constants.Rarity.Rare] = {
        order = 2,
        displayName = "레어",
        color = Color3.fromRGB(70, 130, 255),
    },
    [Constants.Rarity.Epic] = {
        order = 3,
        displayName = "에픽",
        color = Color3.fromRGB(170, 70, 255),
    },
    [Constants.Rarity.Legendary] = {
        order = 4,
        displayName = "전설",
        color = Color3.fromRGB(255, 200, 50),
    },
    [Constants.Rarity.Mythic] = {
        order = 5,
        displayName = "신화",
        color = Color3.fromRGB(255, 80, 120),
    },
}

-- 아이템 카테고리
Constants.Category = {
    Weapon = "Weapon",
    Pet = "Pet",
    Costume = "Costume",
    UGC = "UGC",  -- 사용자 생성 콘텐츠 (액세서리)
}

Constants.CategoryInfo = {
    [Constants.Category.Weapon] = { displayName = "무기", icon = "rbxassetid://0" },
    [Constants.Category.Pet]    = { displayName = "펫",   icon = "rbxassetid://0" },
    [Constants.Category.Costume]= { displayName = "코스튬", icon = "rbxassetid://0" },
    [Constants.Category.UGC]    = { displayName = "액세서리", icon = "rbxassetid://0" },
}

-- UGC 아이템 타입 (액세서리 종류)
Constants.UGCType = {
    Hat = "Hat",
    Hair = "Hair",
    Face = "Face",
    Back = "Back",
    Front = "Front",
    Shoulder = "Shoulder",
    Waist = "Waist",
}

-- 재화 종류
Constants.Currency = {
    Coins = "Coins",
    Tickets = "Tickets",
}

-- 가차 비용
Constants.GachaCost = {
    SingleCoin = 100,
    MultiCoin = 900,       -- 10연 (10% 할인)
    SingleTicket = 1,
}

-- 인벤토리 제한
Constants.MaxInventorySlots = 50

-- 일일 무료 티켓
Constants.DailyTickets = 3

-- 중복 아이템 분해 시 코인 보상
Constants.DuplicateCoinReward = {
    [Constants.Rarity.Common] = 20,
    [Constants.Rarity.Rare] = 50,
    [Constants.Rarity.Epic] = 120,
    [Constants.Rarity.Legendary] = 300,
    [Constants.Rarity.Mythic] = 800,
}

-- RemoteEvent / RemoteFunction 이름
Constants.Remotes = {
    RequestGachaPull = "RequestGachaPull",
    GachaPullResult = "GachaPullResult",
    RequestOddsTable = "RequestOddsTable",
    RequestInventory = "RequestInventory",
    RequestEquip = "RequestEquip",
    RequestUnequip = "RequestUnequip",
    RequestCodex = "RequestCodex",
    RequestCurrency = "RequestCurrency",
    JoinMinigame = "JoinMinigame",
    MinigameStateUpdate = "MinigameStateUpdate",
    MinigameResult = "MinigameResult",
    PlayerDataLoaded = "PlayerDataLoaded",
}

-- 미니게임
Constants.Minigame = {
    MaxPlayers = 4,
    MinPlayers = 1,
    WaveCount = 3,
    QueueTimeout = 30,
}

-------------------------------------------------------
-- 관리자 설정 (서버/클라이언트 공통)
-------------------------------------------------------
Constants.Admin = {
    -- 관리자 UserId 목록 (실제 운영 시 교체 필요)
    UserIds = {
        12345678, -- 예시: 실제 관리자 UserId로 교체 필요
    },

    -- Studio에서 자동 관리자 권한 부여 여부
    studioAutoAdmin = true,
}

-- 관리자 권한 확인 함수
function Constants.IsAdmin(player, runService)
    if not player then return false end

    -- Studio에서 자동 관리자 권한
    if Constants.Admin.studioAutoAdmin and runService and runService:IsStudio() then
        return true
    end

    -- UserId 확인
    return table.find(Constants.Admin.UserIds, player.UserId) ~= nil
end

return Constants
