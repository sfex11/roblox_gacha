--[[
    CurrencyService.lua
    재화 관리 — 코인/티켓 획득/소비/조회
]]

local DataManager = require(script.Parent.DataManager)
local Constants = require(game.ReplicatedStorage.Modules.Constants)

local CurrencyService = {}

-- 재화 조회
function CurrencyService.GetCurrency(userId, currencyType)
    local data = DataManager.GetData(userId)
    if not data then return 0 end
    return data.currency[currencyType] or 0
end

-- 재화 전체 조회
function CurrencyService.GetAllCurrency(userId)
    local data = DataManager.GetData(userId)
    if not data then return { Coins = 0, Tickets = 0 } end
    return {
        Coins = data.currency.Coins or 0,
        Tickets = data.currency.Tickets or 0,
    }
end

-- 재화 추가
function CurrencyService.AddCurrency(userId, currencyType, amount)
    if amount <= 0 then return false end
    local data = DataManager.GetData(userId)
    if not data then return false end

    data.currency[currencyType] = (data.currency[currencyType] or 0) + amount
    return true
end

-- 재화 차감 (부족하면 실패)
function CurrencyService.SpendCurrency(userId, currencyType, amount)
    if amount <= 0 then return false end
    local data = DataManager.GetData(userId)
    if not data then return false end

    local current = data.currency[currencyType] or 0
    if current < amount then
        return false -- 잔액 부족
    end

    data.currency[currencyType] = current - amount
    return true
end

-- 재화 충분한지 확인
function CurrencyService.CanAfford(userId, currencyType, amount)
    local data = DataManager.GetData(userId)
    if not data then return false end
    return (data.currency[currencyType] or 0) >= amount
end

return CurrencyService
