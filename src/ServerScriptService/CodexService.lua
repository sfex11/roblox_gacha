--[[
    CodexService.lua
    도감/세트 진행도 관리
]]

local DataManager = require(script.Parent.DataManager)
local ItemDatabase = require(game.ReplicatedStorage.Modules.ItemDatabase)
local SetDatabase = require(game.ReplicatedStorage.Modules.SetDatabase)
local CurrencyService = require(script.Parent.CurrencyService)
local Constants = require(game.ReplicatedStorage.Modules.Constants)

local CodexService = {}

-- 도감 전체 조회 (클라이언트 표시용)
function CodexService.GetCodex(userId)
    local data = DataManager.GetData(userId)
    if not data then return {} end

    local result = {}
    for templateId, template in pairs(ItemDatabase.GetAll()) do
        result[templateId] = {
            id = templateId,
            name = template.name,
            category = template.category,
            rarity = template.rarity,
            discovered = data.codex[templateId] == true,
            description = data.codex[templateId] and template.description or "???",
            flavorText = data.codex[templateId] and template.flavorText or nil,
        }
    end

    return result
end

-- 도감 발견 수 / 전체 수
function CodexService.GetCodexProgress(userId)
    local data = DataManager.GetData(userId)
    if not data then return 0, 0 end

    local discovered = 0
    local total = 0
    for _ in pairs(ItemDatabase.GetAll()) do
        total = total + 1
    end
    for _ in pairs(data.codex) do
        discovered = discovered + 1
    end

    return discovered, total
end

-- 세트 진행도 조회
function CodexService.GetSetProgress(userId)
    local data = DataManager.GetData(userId)
    if not data then return {} end

    local result = {}
    for setId, setData in pairs(SetDatabase.GetAllSets()) do
        local ownedCount = 0
        local items = {}
        for _, itemId in ipairs(setData.requiredItems) do
            local owned = data.codex[itemId] == true
            if owned then
                ownedCount = ownedCount + 1
            end
            table.insert(items, {
                templateId = itemId,
                owned = owned,
            })
        end

        result[setId] = {
            setId = setId,
            displayName = setData.displayName,
            description = setData.description,
            items = items,
            ownedCount = ownedCount,
            totalCount = #setData.requiredItems,
            completed = data.completedSets[setId] == true,
            rewards = setData.rewards,
        }
    end

    return result
end

-- 세트 완성 체크 및 보상 지급
function CodexService.CheckAndClaimSetRewards(userId)
    local data = DataManager.GetData(userId)
    if not data then return {} end

    local claimed = {}

    for setId, setData in pairs(SetDatabase.GetAllSets()) do
        if not data.completedSets[setId] then
            local allOwned = true
            for _, itemId in ipairs(setData.requiredItems) do
                if not data.codex[itemId] then
                    allOwned = false
                    break
                end
            end

            if allOwned then
                data.completedSets[setId] = true

                -- 보상 지급
                if setData.rewards.coins then
                    CurrencyService.AddCurrency(userId, Constants.Currency.Coins, setData.rewards.coins)
                end

                table.insert(claimed, {
                    setId = setId,
                    displayName = setData.displayName,
                    rewards = setData.rewards,
                })
            end
        end
    end

    return claimed
end

return CodexService
