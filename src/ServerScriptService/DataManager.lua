--[[
    DataManager.lua
    DataStore 래핑 — 플레이어 데이터 저장/로드/자동저장
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Constants = require(game.ReplicatedStorage.Modules.Constants)

local DataManager = {}

local DATASTORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 120 -- 2분마다 자동저장

local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local playerDataCache = {} -- [userId] = data

-- 기본 플레이어 데이터 템플릿
local function getDefaultData()
    return {
        inventory = {},          -- { {templateId, obtainedAt, slotIndex} ... }
        equipped = {             -- 카테고리당 1개
            Weapon = nil,        -- inventory slot index
            Pet = nil,
            Costume = nil,
        },
        codex = {},              -- { [templateId] = true }
        completedSets = {},      -- { [setId] = true }
        currency = {
            Coins = 500,         -- 시작 시 500코인 (바로 5회 뽑기 가능)
            Tickets = 5,         -- 시작 시 5장
        },
        stats = {
            totalPulls = 0,
            lastDailyReset = 0,  -- os.time() 기준
        },
    }
end

-- 데이터 로드
function DataManager.LoadData(player)
    local userId = player.UserId
    local key = "player_" .. tostring(userId)

    local success, data = pcall(function()
        return dataStore:GetAsync(key)
    end)

    if success and data then
        -- 기본값 병합 (새 필드 추가 대응)
        local default = getDefaultData()
        for k, v in pairs(default) do
            if data[k] == nil then
                data[k] = v
            end
        end
        if data.currency then
            for ck, cv in pairs(default.currency) do
                if data.currency[ck] == nil then
                    data.currency[ck] = cv
                end
            end
        end
        playerDataCache[userId] = data
    else
        playerDataCache[userId] = getDefaultData()
    end

    -- 일일 티켓 리셋 확인
    DataManager._checkDailyReset(userId)

    return playerDataCache[userId]
end

-- 데이터 저장
function DataManager.SaveData(player)
    local userId = player.UserId
    local data = playerDataCache[userId]
    if not data then return false end

    local key = "player_" .. tostring(userId)
    local success, err = pcall(function()
        dataStore:SetAsync(key, data)
    end)

    if not success then
        warn("[DataManager] Save failed for " .. tostring(userId) .. ": " .. tostring(err))
    end
    return success
end

-- 캐시된 데이터 가져오기
function DataManager.GetData(userId)
    return playerDataCache[userId]
end

-- 일일 리셋 체크 (티켓 지급)
function DataManager._checkDailyReset(userId)
    local data = playerDataCache[userId]
    if not data then return end

    local now = os.time()
    local lastReset = data.stats.lastDailyReset or 0

    -- UTC 기준 자정을 넘었으면 리셋
    local lastDay = math.floor(lastReset / 86400)
    local today = math.floor(now / 86400)

    if today > lastDay then
        data.currency.Tickets = data.currency.Tickets + Constants.DailyTickets
        data.stats.lastDailyReset = now
    end
end

-- 플레이어 떠날 때 저장
function DataManager.OnPlayerRemoving(player)
    DataManager.SaveData(player)
    playerDataCache[player.UserId] = nil
end

-- 자동저장 루프
function DataManager.StartAutosave()
    task.spawn(function()
        while true do
            task.wait(AUTOSAVE_INTERVAL)
            for _, player in ipairs(Players:GetPlayers()) do
                DataManager.SaveData(player)
            end
        end
    end)
end

-- 서버 종료 시 전체 저장
function DataManager.OnServerShutdown()
    for _, player in ipairs(Players:GetPlayers()) do
        DataManager.SaveData(player)
    end
end

return DataManager
