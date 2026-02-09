--[[
    GachaService.lua
    가차 실행 — 확률 결정 / 아이템 선택 / 지급 (서버 SSOT)
]]

local Constants = require(game.ReplicatedStorage.Modules.Constants)
local GachaConfig = require(game.ReplicatedStorage.Modules.GachaConfig)
local ItemDatabase = require(game.ReplicatedStorage.Modules.ItemDatabase)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local DataManager = require(script.Parent.DataManager)
local LLMClient = require(script.Parent.LLMClient)

local GachaService = {}

-- 희귀도 결정 (가중치 랜덤)
function GachaService._rollRarity()
    local weights = GachaConfig.RarityWeights
    local totalWeight = 0
    for _, w in pairs(weights) do
        totalWeight = totalWeight + w
    end

    local roll = math.random(1, totalWeight)
    local cumulative = 0
    for rarity, weight in pairs(weights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            return rarity
        end
    end

    -- 폴백 (도달하면 안 됨)
    return Constants.Rarity.Common
end

-- 풀 내에서 해당 희귀도 아이템 중 랜덤 선택
function GachaService._pickItem(poolId, rarity)
    local pool = GachaConfig.Pools[poolId]
    if not pool then return nil end

    -- 해당 희귀도에 해당하는 아이템만 필터
    local candidates = {}
    local totalWeight = 0
    for _, entry in ipairs(pool.items) do
        local template = ItemDatabase.GetTemplate(entry.templateId)
        if template and template.rarity == rarity then
            table.insert(candidates, entry)
            totalWeight = totalWeight + entry.weight
        end
    end

    if #candidates == 0 then return nil end

    local roll = math.random(1, totalWeight)
    local cumulative = 0
    for _, entry in ipairs(candidates) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.templateId
        end
    end

    return candidates[1].templateId
end

-- 단일 뽑기 실행
function GachaService._executeSinglePull(userId, poolId)
    local rarity = GachaService._rollRarity()
    local templateId = GachaService._pickItem(poolId, rarity)

    if not templateId then
        -- 풀에 해당 희귀도 아이템이 없으면 Common으로 폴백
        templateId = GachaService._pickItem(poolId, Constants.Rarity.Common)
    end

    local template = ItemDatabase.GetTemplate(templateId)
    local isNew = not InventoryService.HasItem(userId, templateId)
    local isDuplicate = not isNew
    local duplicateCoins = 0

    local data = DataManager.GetData(userId)

    if isDuplicate then
        -- 중복: 코인으로 변환
        duplicateCoins = Constants.DuplicateCoinReward[rarity] or 20
        CurrencyService.AddCurrency(userId, Constants.Currency.Coins, duplicateCoins)
    else
        -- 신규: 인벤토리에 추가
        local success, result = InventoryService.AddItem(userId, templateId)
        if not success then
            -- 인벤토리 풀 — 코인으로 대체 지급
            duplicateCoins = Constants.DuplicateCoinReward[rarity] or 20
            CurrencyService.AddCurrency(userId, Constants.Currency.Coins, duplicateCoins)
            isDuplicate = true
        end
    end

    -- 도감 등록
    if data and not data.codex[templateId] then
        data.codex[templateId] = true
    end

    -- 통계 업데이트
    if data then
        data.stats.totalPulls = (data.stats.totalPulls or 0) + 1
    end

    -- LLM 텍스트 생성 (활성화 시)
    local itemName = template and template.name or "???"
    local itemDesc = template and template.description or ""
    local itemFlavor = template and template.flavorText or ""

    if LLMClient.IsEnabled() and template then
        local llmResult = LLMClient.RequestText(
            templateId,
            rarity,
            template.category,
            template.name,
            { tone = "default" }
        )
        if llmResult and llmResult.success then
            itemName = llmResult.name or itemName
            itemDesc = llmResult.description or itemDesc
            itemFlavor = llmResult.flavorText or itemFlavor
        end
    end

    return {
        templateId = templateId,
        rarity = rarity,
        name = itemName,
        description = itemDesc,
        flavorText = itemFlavor,
        isNew = isNew and not isDuplicate,
        isDuplicate = isDuplicate,
        duplicateCoins = duplicateCoins,
    }
end

-- 코인 가차 (1연)
function GachaService.PullSingleCoin(player)
    local userId = player.UserId
    local poolId = "standard_v1"

    if not CurrencyService.CanAfford(userId, Constants.Currency.Coins, Constants.GachaCost.SingleCoin) then
        return { success = false, error = "코인이 부족합니다." }
    end

    CurrencyService.SpendCurrency(userId, Constants.Currency.Coins, Constants.GachaCost.SingleCoin)

    local result = GachaService._executeSinglePull(userId, poolId)
    return {
        success = true,
        pullType = "single",
        items = { result },
        currency = CurrencyService.GetAllCurrency(userId),
    }
end

-- 코인 가차 (10연)
function GachaService.PullMultiCoin(player)
    local userId = player.UserId
    local poolId = "standard_v1"

    if not CurrencyService.CanAfford(userId, Constants.Currency.Coins, Constants.GachaCost.MultiCoin) then
        return { success = false, error = "코인이 부족합니다." }
    end

    CurrencyService.SpendCurrency(userId, Constants.Currency.Coins, Constants.GachaCost.MultiCoin)

    local items = {}
    for i = 1, 10 do
        local result = GachaService._executeSinglePull(userId, poolId)
        table.insert(items, result)
    end

    return {
        success = true,
        pullType = "multi",
        items = items,
        currency = CurrencyService.GetAllCurrency(userId),
    }
end

-- 티켓 가차 (1연)
function GachaService.PullSingleTicket(player)
    local userId = player.UserId
    local poolId = "standard_v1"

    if not CurrencyService.CanAfford(userId, Constants.Currency.Tickets, Constants.GachaCost.SingleTicket) then
        return { success = false, error = "티켓이 부족합니다." }
    end

    CurrencyService.SpendCurrency(userId, Constants.Currency.Tickets, Constants.GachaCost.SingleTicket)

    local result = GachaService._executeSinglePull(userId, poolId)
    return {
        success = true,
        pullType = "single",
        items = { result },
        currency = CurrencyService.GetAllCurrency(userId),
    }
end

-- 확률표 조회
function GachaService.GetOddsTable(poolId)
    return GachaConfig.GetOddsTable(poolId or "standard_v1")
end

return GachaService
